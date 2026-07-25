#!/usr/bin/env node
/**
 * Sync FAQ knowledge from https://www.promiseschool.app into messenger-automation.
 * Pulls homepage FAQs + full Hobbycamp course details (per course page JSON-LD).
 * Run from messenger-automation/: node scripts/sync-knowledge-from-site.mjs
 */
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const knowledgeDir = join(__dirname, "..", "knowledge");
const faqPath = join(knowledgeDir, "faq.json");
const itemsPath = join(knowledgeDir, "faq-items.json");

const SITE_URL = process.env.SITE_URL || "https://www.promiseschool.app";
const HOBBYCAMP_URL = process.env.HOBBYCAMP_URL || `${SITE_URL}/hobbycamp`;
const SUPPORT_PHONE = process.env.SUPPORT_PHONE || "+8801814266295";

const FEATURE_HEADINGS = new Set([
  "Interactive Subjects",
  "Quick Revisions",
  "Gamified Learning",
  "Board & School Exams",
]);

function stripHtml(html) {
  return html
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&nbsp;/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function absoluteUrl(url) {
  if (!url) return url;
  return url
    .replace("https://promiseschool.app", SITE_URL)
    .replace("http://promiseschool.app", SITE_URL);
}

async function fetchHtml(url) {
  const res = await fetch(url, {
    headers: { "User-Agent": "PromiseSchool-Messenger-KB-Sync/1.0" },
    signal: AbortSignal.timeout(60_000),
    redirect: "follow",
  });
  if (!res.ok) {
    throw new Error(`HTTP ${res.status} fetching ${url}`);
  }
  return res.text();
}

function parseJsonLd(html, type) {
  const found = [];
  const re = /<script type="application\/ld\+json">([\s\S]*?)<\/script>/gi;
  let match;
  while ((match = re.exec(html)) !== null) {
    try {
      const data = JSON.parse(match[1]);
      const items = Array.isArray(data) ? data : [data];
      for (const item of items) {
        if (item["@type"] === type) found.push(item);
      }
    } catch {
      // ignore invalid JSON-LD blocks
    }
  }
  return found;
}

function parseSiteFaqs(html) {
  const faqPages = parseJsonLd(html, "FAQPage");
  if (faqPages.length > 0) {
    return faqPages
      .flatMap((page) =>
        (page.mainEntity || []).map((q) => ({
          question: q.name?.trim(),
          answer: q.acceptedAnswer?.text?.trim(),
        }))
      )
      .filter((f) => f.question && f.answer);
  }

  const start = html.search(/Frequently asked questions/i);
  if (start < 0) return [];

  const section = html.slice(start);
  const faqs = [];
  const re = /<h3[^>]*>([^<]+)<\/h3>[\s\S]*?<p[^>]*>([\s\S]*?)<\/p>/gi;
  let match;
  while ((match = re.exec(section)) !== null) {
    const question = stripHtml(match[1]);
    const answer = stripHtml(match[2]);
    if (!question || !answer || FEATURE_HEADINGS.has(question)) continue;
    faqs.push({ question, answer });
  }
  return faqs;
}

function parseCourseList(html) {
  const lists = parseJsonLd(html, "ItemList");
  const courses = [];
  for (const list of lists) {
    for (const item of list.itemListElement || []) {
      const name = item.name?.trim();
      const url = absoluteUrl(item.url || item.item);
      if (!name || !url) continue;
      if (courses.some((c) => c.url === url)) continue;
      courses.push({ name, url, position: item.position });
    }
  }
  return courses;
}

function formatBdt(price) {
  if (price == null || price === "") return null;
  const num = Number(String(price).replace(/,/g, ""));
  if (!Number.isFinite(num)) return `৳${price}`;
  return `৳${num.toLocaleString("en-BD")}`;
}

function formatStartDate(iso) {
  if (!iso) return null;
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return iso;
  return d.toLocaleDateString("en-GB", {
    day: "numeric",
    month: "short",
    year: "numeric",
  });
}

function scrapeClassesCount(html) {
  const text = stripHtml(html);
  const m = text.match(/(\d+)\s+Classes?\b/i);
  return m ? m[1] : null;
}

function scrapePricesFromHtml(html) {
  const text = stripHtml(html);
  const prices = [...text.matchAll(/৳\s*([\d,]+)/g)].map((m) => m[1]);
  return {
    price: prices[0] || null,
    originalPrice: prices[1] || null,
  };
}

async function enrichCourse(listItem) {
  const html = await fetchHtml(listItem.url);
  const courseLd = parseJsonLd(html, "Course")[0];
  if (!courseLd) {
    console.warn(`WARN: no Course JSON-LD for ${listItem.url}`);
    return null;
  }

  const instance = courseLd.hasCourseInstance || {};
  const offer = courseLd.offers || {};
  const scraped = scrapePricesFromHtml(html);
  const classes = scrapeClassesCount(html);

  let instructor = null;
  const instr = instance.instructor;
  if (typeof instr === "string") instructor = instr;
  else if (Array.isArray(instr)) {
    instructor = instr.map((p) => p?.name || p).filter(Boolean).join(", ");
  } else if (instr?.name) instructor = instr.name;

  const modeRaw = instance.courseMode || "";
  let mode = String(modeRaw || "").toLowerCase();
  if (/offline|onsite|in[\s-]?person/i.test(modeRaw) || /offline/i.test(courseLd.name || "")) {
    mode = "offline";
  } else if (/online/i.test(modeRaw) || /online/i.test(courseLd.name || "")) {
    mode = "online";
  } else if (!mode) {
    mode = "live";
  }

  const price =
    offer.price != null
      ? String(Math.round(Number(offer.price))).replace(/\B(?=(\d{3})+(?!\d))/g, ",")
      : scraped.price;
  const originalPrice = scraped.originalPrice;

  return {
    title: courseLd.name || listItem.name,
    url: absoluteUrl(courseLd.url || listItem.url),
    description: (courseLd.description || "").trim(),
    mode,
    price,
    originalPrice:
      originalPrice && originalPrice !== price ? originalPrice : null,
    currency: offer.priceCurrency || "BDT",
    classes,
    workload: instance.courseWorkload || null,
    starts: formatStartDate(instance.startDate),
    startDateIso: instance.startDate || null,
    instructor,
    languages: courseLd.inLanguage || instance.inLanguage || [],
    free: Boolean(courseLd.isAccessibleForFree),
  };
}

function formatCourseLine(course) {
  const parts = [course.title];
  if (course.mode) parts.push(`(${course.mode})`);
  if (course.price) {
    parts.push(
      course.originalPrice
        ? `${formatBdt(course.price)} (was ${formatBdt(course.originalPrice)})`
        : formatBdt(course.price)
    );
  }
  if (course.classes) parts.push(`${course.classes} classes`);
  if (course.workload) parts.push(course.workload);
  if (course.starts) parts.push(`starts ${course.starts}`);
  if (course.instructor) parts.push(`instructor: ${course.instructor}`);
  return parts.join(" — ");
}

function courseDetailsEn(course) {
  const bits = [];
  if (course.description) bits.push(course.description);
  if (course.price) {
    bits.push(
      course.originalPrice
        ? `Price: ${formatBdt(course.price)} (was ${formatBdt(course.originalPrice)}).`
        : `Price: ${formatBdt(course.price)}.`
    );
  }
  if (course.mode) bits.push(`Mode: ${course.mode}.`);
  if (course.classes) bits.push(`Classes: ${course.classes}.`);
  if (course.workload) bits.push(`Duration/workload: ${course.workload}.`);
  if (course.starts) bits.push(`Starts: ${course.starts}.`);
  if (course.instructor) bits.push(`Instructor(s): ${course.instructor}.`);
  bits.push(`Book at ${course.url || HOBBYCAMP_URL}`);
  bits.push(`For help call ${SUPPORT_PHONE}.`);
  return bits.join(" ");
}

function hasBangla(text) {
  return /[\u0980-\u09FF]/.test(text || "");
}

function courseDetailsBn(course) {
  const bits = [];
  bits.push(`Hobbycamp কোর্স: ${course.title}।`);
  // Prefer Bangla description from the site; skip English-only blurbs for BN answers
  if (course.description && hasBangla(course.description)) {
    bits.push(course.description);
  }
  if (course.price) {
    bits.push(
      course.originalPrice
        ? `মূল্য: ${formatBdt(course.price)} (আগে ${formatBdt(course.originalPrice)})।`
        : `মূল্য: ${formatBdt(course.price)}।`
    );
  }
  if (course.mode) {
    bits.push(
      /offline/i.test(course.mode)
        ? "মাধ্যম: অফলাইন।"
        : /online/i.test(course.mode)
          ? "মাধ্যম: অনলাইন।"
          : `মাধ্যম: ${course.mode}।`
    );
  }
  if (course.classes) bits.push(`ক্লাস সংখ্যা: ${course.classes}টি।`);
  if (course.workload) bits.push(`সময়কাল: ${course.workload}।`);
  if (course.starts) bits.push(`শুরুর তারিখ: ${course.starts}।`);
  if (course.instructor) bits.push(`ইনস্ট্রাক্টর: ${course.instructor}।`);
  bits.push(`বুকিং লিংক: ${course.url || HOBBYCAMP_URL}`);
  bits.push(`সাহায্যের জন্য কল করুন ${SUPPORT_PHONE}।`);
  return bits.join(" ");
}

function buildCourseFaqs(courses) {
  const faqs = [];

  if (courses.length > 0) {
    const list = courses.map((c) => `- ${formatCourseLine(c)}`).join("\n");
    faqs.push({
      question: "What Hobbycamp courses are available right now?",
      answer: `Current Hobbycamp programs on Promise School:\n${list}\n\nBrowse and book at ${HOBBYCAMP_URL}. For help call ${SUPPORT_PHONE}.`,
    });
    faqs.push({
      question: "হবিক্যাম্পে এখন কোন কোর্স আছে?",
      answer: `Promise School Hobbycamp-এ বর্তমানে এই কোর্সগুলো চলছে:\n${list}\n\nবুকিং: ${HOBBYCAMP_URL}। সাহায্যের জন্য কল করুন ${SUPPORT_PHONE}।`,
    });
    faqs.push({
      question: "হবিক্যাম্পে কি কোর্স আছে?",
      answer: `Promise School Hobbycamp-এ বর্তমানে এই কোর্সগুলো চলছে:\n${list}\n\nবুকিং: ${HOBBYCAMP_URL}। সাহায্যের জন্য কল করুন ${SUPPORT_PHONE}।`,
    });
    faqs.push({
      question: "List all Hobbycamp courses with prices and start dates",
      answer: `Here are all current Hobbycamp courses:\n${list}\n\nDetails and booking: ${HOBBYCAMP_URL}`,
    });
  }

  for (const course of courses) {
    const en = courseDetailsEn(course);
    const bn = courseDetailsBn(course);

    faqs.push({
      question: `Tell me about the Hobbycamp course: ${course.title}`,
      answer: en,
    });
    faqs.push({
      question: `How much is the ${course.title} Hobbycamp course?`,
      answer: en,
    });
    faqs.push({
      question: `What is the price of ${course.title}?`,
      answer: en,
    });
    faqs.push({
      question: `When does ${course.title} start?`,
      answer: en,
    });
    faqs.push({
      question: `Who teaches ${course.title}?`,
      answer: en,
    });
    faqs.push({
      question: `How many classes are in ${course.title}?`,
      answer: en,
    });

    faqs.push({
      question: `${course.title} কোর্স সম্পর্কে বলো`,
      answer: bn,
    });
    faqs.push({
      question: `${course.title} কোর্সের দাম কত?`,
      answer: bn,
    });
    faqs.push({
      question: `${course.title} কবে শুরু?`,
      answer: bn,
    });
    faqs.push({
      question: `${course.title} এর ইনস্ট্রাক্টর কে?`,
      answer: bn,
    });
    faqs.push({
      question: `${course.title} এ কতগুলো ক্লাস?`,
      answer: bn,
    });
  }

  faqs.push({
    question: "How do I enroll in a Hobbycamp course?",
    answer: `Visit ${HOBBYCAMP_URL}, choose a course, and book a seat. You can pick online or offline batches where available. For payment issues call ${SUPPORT_PHONE}.`,
  });

  faqs.push({
    question: "হবিক্যাম্প কোর্সে ভর্তি কিভাবে করব?",
    answer: `${HOBBYCAMP_URL} এ গিয়ে কোর্স বেছে নিয়ে সিট বুক করুন। অনলাইন বা অফলাইন ব্যাচ থাকলে সেখান থেকে বেছে নিন। পেমেন্ট সমস্যা হলে ${SUPPORT_PHONE} নম্বরে কল করুন।`,
  });

  return faqs;
}

function dedupeFaqs(faqs) {
  const seen = new Set();
  return faqs.filter((entry) => {
    const key = entry.question.trim().toLowerCase();
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

function mergeFaqs(siteFaqs, courseFaqs, customFaqs, fallbackFaqs) {
  const base = siteFaqs.length > 0 ? siteFaqs : fallbackFaqs;
  return dedupeFaqs([...base, ...courseFaqs, ...customFaqs]);
}

async function main() {
  console.log(`Fetching ${SITE_URL} ...`);
  const homeHtml = await fetchHtml(SITE_URL);

  console.log(`Fetching ${HOBBYCAMP_URL} ...`);
  let hobbyHtml = "";
  try {
    hobbyHtml = await fetchHtml(HOBBYCAMP_URL);
  } catch (err) {
    console.warn(`WARN: could not fetch hobbycamp page: ${err.message}`);
  }

  const existing = JSON.parse(readFileSync(faqPath, "utf8"));
  const customFaqs = existing.customFaqs || [];
  const fallbackFaqs = (existing.faqs || []).filter(
    (f) =>
      !/hobbycamp|হবিক্যাম্প|কোর্সের দাম|কোর্স সম্পর্কে|ইনস্ট্রাক্টর|কতগুলো ক্লাস|কবে শুরু/i.test(
        f.question
      )
  );

  const siteFaqs = parseSiteFaqs(homeHtml);
  const listed = parseCourseList(hobbyHtml || homeHtml);
  console.log(`Found ${listed.length} courses in ItemList`);

  const courses = [];
  for (const item of listed) {
    try {
      console.log(`  Fetching ${item.url}`);
      const enriched = await enrichCourse(item);
      if (enriched) courses.push(enriched);
    } catch (err) {
      console.warn(`WARN: failed ${item.url}: ${err.message}`);
    }
  }

  const courseFaqs = buildCourseFaqs(courses);
  const faqs = mergeFaqs(siteFaqs, courseFaqs, customFaqs, fallbackFaqs);

  const output = {
    organization: {
      ...existing.organization,
      website: SITE_URL,
      hobbycampUrl: HOBBYCAMP_URL,
      supportPhone: SUPPORT_PHONE,
      privacyPolicyUrl: `${SITE_URL}/privacy-policy`,
    },
    customFaqs,
    faqs,
    courses,
    escalationTopics: existing.escalationTopics,
    escalationReply: existing.escalationReply,
    syncedAt: new Date().toISOString(),
    syncedFrom: SITE_URL,
  };

  writeFileSync(faqPath, `${JSON.stringify(output, null, 2)}\n`);
  writeFileSync(itemsPath, `${JSON.stringify(output.faqs, null, 2)}\n`);

  console.log(`Synced ${siteFaqs.length} site FAQs, ${courses.length} courses`);
  console.log(`Generated ${courseFaqs.length} course-related FAQ entries`);
  console.log(`Total FAQ entries: ${output.faqs.length}`);
  console.log(`Wrote ${faqPath}`);
  console.log(`Wrote ${itemsPath}`);
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
