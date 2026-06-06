#!/usr/bin/env bash
# Validate enriched FAQ knowledge (local files or mounted path on VPS).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ITEMS="${KNOWLEDGE_ITEMS:-$ROOT/knowledge/faq-items.json}"

if [[ ! -f "$ITEMS" ]]; then
  echo "FAIL: missing $ITEMS"
  exit 1
fi

node -e "
const items = require(process.argv[1]);
if (!Array.isArray(items)) {
  console.error('FAIL: faq-items.json must be a root JSON array');
  process.exit(1);
}
const py = items.find((x) => x.question === 'What is the price of Python Beginner?');
const bn = items.find((x) => x.question === 'হবিক্যাম্পে কি কোর্স আছে?');
const list = items.find((x) => x.question === 'What Hobbycamp courses are available right now?');
let ok = true;
function check(label, cond, detail) {
  if (!cond) { console.error('FAIL:', label, detail || ''); ok = false; }
  else console.log('OK:', label);
}
check('entry count >= 22', items.length >= 22, 'got ' + items.length);
check('Python Beginner price Q&A', py && /৳1,500/.test(py.answer));
check('Hobbycamp course list (EN)', list && (list.answer.match(/^-/gm) || []).length >= 1);
check('Hobbycamp course list (BN)', bn && (bn.answer.match(/^-/gm) || []).length >= 1);
if (!ok) process.exit(1);
console.log('All knowledge checks passed (' + items.length + ' entries).');
" "$ITEMS"
