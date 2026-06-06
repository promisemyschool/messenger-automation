# Development mode testing checklist

Run these tests **before** App Review. The Meta app must stay in **Development** until tests pass.

## Prerequisites

- [ ] `./scripts/deploy.sh` completed on VPS
- [ ] n8n workflow imported and **Active**
- [ ] Meta webhook verified (`docs/meta-setup.md`)
- [ ] `./scripts/setup-meta.sh` succeeded
- [ ] Your Facebook account is an app admin/tester or has Page messaging role

## Webhook verification

1. Run `./scripts/verify-webhook.sh` — must print `OK: challenge echoed` (body exactly `hello_meta_test`).
2. Confirm POST is registered: script prints `OK: POST accepted` (not “not registered for POST”).
3. In Meta Developer Console → **Verify and save** (Callback URL `https://<domain>/webhook/messenger`).
4. In Meta → Webhooks → click **Test** on `messages`.
5. In n8n → **Executions**, confirm verify runs **Check Meta Verify** → **Return hub.challenge**.

## Manual message tests

Message the Promise School Page from your personal account:

| # | Send | Expected |
|---|------|----------|
| 1 | `Is Promise School free?` | Confirms free app; mentions Hobbycamp is paid |
| 2 | `হবিক্যাম্প কি?` | Bangla reply about Hobbycamp + link |
| 3 | `Which classes do you cover?` | NCTB Class 6-12, SSC/HSC subjects |
| 4 | `I need a refund` | Escalation to support@promiseschool.com |
| 5 | `What is the price of Physics course in Hobbycamp?` | Does not invent price; points to hobbycamp page or support |

## Human-like behavior

- [ ] Typing indicator appears before reply (LLM path)
- [ ] Follow-up question remembers prior turn (e.g. ask about app, then "what about iOS?")

## n8n execution checks

For each test message, open **Executions** and verify:

- **Ack Webhook** runs before Ollama
- **Ollama Chat** returns within 60s
- **Send Messenger Reply** HTTP status 200

## Common failures

| Symptom | Likely cause |
|---------|----------------|
| No execution in n8n | Workflow not published, or Meta not subscribed to **messages** field (see [`meta-setup.md`](meta-setup.md)) |
| simulate script runs, real DMs do not | Meta Webhooks → Page → **messages** not subscribed; or messaging as Page admin (echo) |
| Verification fails | Run `./scripts/verify-webhook.sh`; see [`n8n-webhook-setup.md`](n8n-webhook-setup.md) |
| curl 200 but empty body | Token mismatch or wrong webhook path; republish workflow |
| 404 on `/webhook/messenger` | Path must be `messenger`; workflow published |
| Execution but no reply | Invalid Page token; sender not in dev mode roles |
| Empty reply | Ollama model not pulled — run `./scripts/pull-models.sh` |
| Error: `Module 'fs' is disallowed` on Prepare Prompt | Re-import published workflow; ensure `N8N_RESTRICT_FILE_ACCESS_TO=/knowledge` and **Read FAQ** node exists |
| `Bad request` on **Mark Seen** / **Typing On** | Re-import workflow (JSON body must be `={{ { recipient: … } }}`, not `JSON.stringify`). Confirm `META_PAGE_ACCESS_TOKEN` is a **Page** token with `pages_messaging` |

## Sign-off

When all rows pass, proceed to [`app-review.md`](app-review.md).
