#!/usr/bin/env node
/**
 * Sync FAQ knowledge from the landing site source of truth into messenger-automation.
 * Run from repo root: node messenger-automation/scripts/export-faq.mjs
 */
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(__dirname, "..", "..");
const faqSource = join(
  repoRoot,
  "promise-school-landing",
  "promise-school-landing",
  "src",
  "data",
  "faq.ts"
);
const outputPath = join(__dirname, "..", "knowledge", "faq.json");
const itemsOutputPath = join(__dirname, "..", "knowledge", "faq-items.json");

const source = readFileSync(faqSource, "utf8");
const faqMatches = [...source.matchAll(/question:\s*"([^"]+)"[\s\S]*?answer:\s*\n\s*"([^"]+)"/g)];

if (faqMatches.length === 0) {
  console.error("No FAQ entries found in", faqSource);
  process.exit(1);
}

const existing = JSON.parse(readFileSync(outputPath, "utf8"));
existing.faqs = faqMatches.map((match) => ({
  question: match[1],
  answer: match[2],
}));

writeFileSync(outputPath, `${JSON.stringify(existing, null, 2)}\n`);
writeFileSync(itemsOutputPath, `${JSON.stringify(existing.faqs, null, 2)}\n`);
console.log(`Exported ${existing.faqs.length} FAQs to ${outputPath} and ${itemsOutputPath}`);
