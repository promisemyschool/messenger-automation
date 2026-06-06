#!/usr/bin/env node
/**
 * Sync FAQ knowledge from https://www.promiseschool.app into messenger-automation.
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

async function fetchHtml(url) {
  const res = await fetch(url, {
    headers: { "User-Agent": "PromiseSchool-Messenger-KB-Sync/1.0" },
    signal: AbortSignal.timeout(60_000),
  });
  if (!res.ok) {
    throw new Error(`HTTP ${res.status} fetching ${url}`);
  }
  return res.text();
}

function parseSiteFaqs(html) {
  const start = html.search(/Frequently asked questions/i);
  if (start < 0) return [];

  const section = html.slice(start);
  const faqs = [];
  const re = /<h3[^>]*>([^<]+)<\/h3>\s*<p[^>]*>([\s\S]*?)<\/p>/gi;
  let match;
  while ((match = re.exec(section)) !== null) {
    const question = stripHtml(match[1]);
    const answer = stripHtml(match[2]);
    if (!question || !answer || FEATURE_HEADINGS.has(question)) continue;
    faqs.push({ question, answer });
  }
  return faqs;
}

function parseCourses(html) {
  const start = html.search(/Explore HobbyCamp/i);
  const end = html.search(/\bFeatures\b/);
  if (start < 0 || end < 0 || end <= start) return [];

  const section = html.slice(start, end);
  const chunks = section.split(/<h3[^>]*>/i).slice(1);
  const courses = [];

  for (const chunk of chunks) {
    const titleMatch = chunk.match(/^([^<]+)<\/h3>/i);
    if (!titleMatch) continue;

    const title = stripHtml(titleMatch[1]);
    if (!title || FEATURE_HEADINGS.has(title)) continue;

    const text = stripHtml(chunk.slice(titleMatch[0].length));
    const prices = [...text.matchAll(/৳\s*([\d,]+)/g)].map((m) => m[1]);
    const batch = text.match(/Batch\s+(\S+)/i)?.[1];
    const classes = text.match(/(\d+)\s+Classes/i)?.[1];
    const starts = text.match(/Starts\s+(.+?)\s+(?:Md\.|Joynal|Subarna|H M|[A-Z])/i)?.[1]
      || text.match(/Starts\s+(\d{1,2}\s+\w{3}\s+\d{4})/i)?.[1];
    const instructor = text.match(
      /Starts\s+\d{1,2}\s+\w{3}\s+\d{4}\s+(.+?)\s+৳/i
    )?.[1]?.trim();

    let mode = "online";
    if (/offline/i.test(title)) mode = "offline";
    else if (/online/i.test(title)) mode = "online";

    const price = prices[0] || null;
    const originalPrice = prices[1] || null;

    const key = `${title}|${price}|${starts}|${mode}`;
    if (courses.some((c) => c.key === key)) continue;

    courses.push({
      key,
      title,
      mode,
      price,
      originalPrice,
      batch,
      classes,
      starts,
      instructor,
    });
  }

  return courses;
}

function formatCourseLine(course) {
  const parts = [course.title];
  if (course.mode) parts.push(`(${course.mode})`);
  if (course.price) {
    parts.push(
      course.originalPrice
        ? `৳${course.price} (was ৳${course.originalPrice})`
        : `৳${course.price}`
    );
  }
  if (course.classes) parts.push(`${course.classes} classes`);
  if (course.starts) parts.push(`starts ${course.starts}`);
  if (course.instructor) parts.push(`with ${course.instructor}`);
  return parts.join(", ");
}

function buildCourseFaqs(courses) {
  const faqs = [];

  if (courses.length > 0) {
    const list = courses.map((c) => `- ${formatCourseLine(c)}`).join("\n");
    faqs.push({
      question: "What Hobbycamp courses are available right now?",
      answer: `Current Hobbycamp programs on Promise School:\n${list}\n\nBrowse and book at ${HOBBYCAMP_URL}`,
    });
    faqs.push({
      question: "হবিক্যাম্পে এখন কোন কোর্স আছে?",
      answer: `Promise School Hobbycamp-এ বর্তমানে এই কোর্সগুলো চলছে:\n${list}\n\nবুকিং: ${HOBBYCAMP_URL}`,
    });
  }

  for (const course of courses) {
    const pricePart = course.price
      ? course.originalPrice
        ? `৳${course.price} (discounted from ৳${course.originalPrice})`
        : `৳${course.price}`
      : "see the course page for current price";

    const details = [
      pricePart,
      course.classes ? `${course.classes} classes` : null,
      course.mode ? `${course.mode}` : null,
      course.starts ? `starts ${course.starts}` : null,
      course.instructor ? `instructor: ${course.instructor}` : null,
    ]
      .filter(Boolean)
      .join(", ");

    faqs.push({
      question: `How much is the ${course.title} Hobbycamp course?`,
      answer: `${course.title} on Hobbycamp is ${details}. Book at ${HOBBYCAMP_URL}`,
    });

    if (/[\u0980-\u09FF]/.test(course.title)) {
      faqs.push({
        question: `${course.title} কোর্সের দাম কত?`,
        answer: `Hobbycamp-এ ${course.title} — ${details}। বুকিং: ${HOBBYCAMP_URL}`,
      });
    }
  }

  faqs.push({
    question: "How do I enroll in a Hobbycamp course?",
    answer: `Visit ${HOBBYCAMP_URL}, choose a course, and book a seat. You can pick online or offline batches where available. For payment issues email support@promiseschool.com.`,
  });

  faqs.push({
    question: "হবিক্যাম্প কোর্সে ভর্তি কিভাবে করব?",
    answer: `${HOBBYCAMP_URL} এ গিয়ে কোর্স বেছে নিয়ে সিট বুক করুন। পেমেন্ট সমস্যা হলে support@promiseschool.com এ লিখুন।`,
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

function mergeFaqs(siteFaqs, courseFaqs, customFaqs) {
  return dedupeFaqs([...siteFaqs, ...courseFaqs, ...customFaqs]);
}

async function main() {
  console.log(`Fetching ${SITE_URL} ...`);
  const html = await fetchHtml(SITE_URL);

  const existing = JSON.parse(readFileSync(faqPath, "utf8"));
  const customFaqs = existing.customFaqs || [];

  const siteFaqs = parseSiteFaqs(html);
  const courses = parseCourses(html);
  const courseFaqs = buildCourseFaqs(courses);
  const faqs = mergeFaqs(siteFaqs, courseFaqs, customFaqs);

  if (siteFaqs.length === 0) {
    console.warn("WARN: no FAQs parsed from site — keeping existing site FAQs in merge");
    faqs.unshift(...(existing.faqs || []).filter((f) => !f.question.includes("Hobbycamp course")));
  }

  const output = {
    organization: {
      ...existing.organization,
      website: SITE_URL,
      hobbycampUrl: HOBBYCAMP_URL,
      privacyPolicyUrl: `${SITE_URL}/privacy-policy`,
    },
    customFaqs,
    faqs: dedupeFaqs(faqs),
    escalationTopics: existing.escalationTopics,
    escalationReply: existing.escalationReply,
    syncedAt: new Date().toISOString(),
    syncedFrom: SITE_URL,
  };

  writeFileSync(faqPath, `${JSON.stringify(output, null, 2)}\n`);
  writeFileSync(itemsPath, `${JSON.stringify(output.faqs, null, 2)}\n`);

  console.log(`Synced ${siteFaqs.length} site FAQs, ${courses.length} courses, ${courseFaqs.length} course FAQs`);
  console.log(`Total FAQ entries: ${output.faqs.length}`);
  console.log(`Wrote ${faqPath}`);
  console.log(`Wrote ${itemsPath}`);
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
