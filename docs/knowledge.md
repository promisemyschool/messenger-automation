# Knowledge base (FAQ) for Messenger bot

The bot answers from files in [`knowledge/`](../knowledge/), mounted at `/knowledge` inside the n8n container.

## Files

| File | Purpose |
|------|---------|
| [`knowledge/faq.json`](../knowledge/faq.json) | Canonical doc: `organization`, `faqs`, `customFaqs`, escalation metadata |
| [`knowledge/faq-items.json`](../knowledge/faq-items.json) | **Runtime file** — JSON array of `{ question, answer }` read by the workflow |

The workflow reads **`faq-items.json` only**. After any edit to `faq.json`, regenerate `faq-items.json` (sync script does this automatically).

## Sync from promiseschool.app (recommended)

Pulls general FAQs (JSON-LD) and HobbyCamp course prices from the live site:

```bash
cd messenger-automation
node scripts/sync-knowledge-from-site.mjs
```

Optional env overrides:

```bash
SITE_URL=https://www.promiseschool.app \
HOBBYCAMP_URL=https://www.promiseschool.app/hobbycamp \
node scripts/sync-knowledge-from-site.mjs
```

The script:

1. Fetches the homepage FAQ (`FAQPage` schema)
2. Fetches `/hobbycamp` for course cards (title, price, start date, instructor)
3. Generates course list + per-course pricing Q&As (English + Bangla where applicable)
4. Merges **`customFaqs`** from `faq.json` (never overwritten)
5. Writes `faq.json` and `faq-items.json`

## Manual Q&As (never overwritten by sync)

Add entries to **`customFaqs`** in `faq.json`:

```json
"customFaqs": [
  {
    "question": "What is your refund policy for Hobbycamp?",
    "answer": "Email support@promiseschool.com with your payment details and our team will review within 2 business days."
  }
]
```

Re-run `node scripts/sync-knowledge-from-site.mjs` to merge them into `faqs` / `faq-items.json`.

## Quick manual edit (one-off)

1. Add to the `faqs` array in `faq.json`
2. Copy the full `faqs` array into `faq-items.json` (must be a **root array**, not an object)
3. Deploy to VPS (below)

## Sync from landing site repo (general FAQs only)

If you maintain [`promise-school-landing/src/data/faq.ts`](../promise-school-landing/promise-school-landing/src/data/faq.ts):

```bash
node scripts/export-faq.mjs
```

Then run `sync-knowledge-from-site.mjs` to add HobbyCamp course Q&As.

## Deploy to VPS

Knowledge is bind-mounted read-only — **no n8n restart** required:

```bash
cd /var/messenger-automation
git pull
docker compose exec n8n wc -l /knowledge/faq-items.json
docker compose exec n8n cat /knowledge/faq-items.json | head -20
```

Send a test Messenger message; check **Prepare Prompt** in n8n Executions — the system prompt should include new Q&As.

## Writing good Q&As

- **Short answers** (2–4 sentences) with real numbers (BDT prices, dates)
- **Duplicate phrasing** as separate entries: “Python course price” / “পাইথন কোর্সের দাম”
- **Do not invent** prices or features — sync from the site or paste verified copy
- **Hobbycamp** answers should end with the hobbycamp URL
- **Refunds / billing** → add keywords to escalation (handled in workflow) or use `customFaqs` pointing to support email

## Verify

```bash
./scripts/verify-knowledge.sh
```

On VPS after `git pull`:

```bash
cd /var/messenger-automation
./scripts/verify-knowledge.sh
docker compose exec n8n wc -l /knowledge/faq-items.json   # expect >34 lines
```

Webhook smoke test (needs `.env`):

```bash
SIMULATE_MESSAGE_TEXT="What is the price of Python Beginner?" ./scripts/simulate-messenger-webhook.sh
```

Messenger tests ([`docs/testing.md`](testing.md)):

| Message | Expected |
|---------|----------|
| `What is the price of Python Beginner?` | ৳1,500 (discounted from ৳2,500) |
| `হবিক্যাম্পে কি কোর্স আছে?` | Lists current Hobbycamp courses |
| `What Hobbycamp courses are available right now?` | Bullet list with prices |
