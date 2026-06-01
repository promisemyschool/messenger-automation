# Development mode testing checklist

Run these tests **before** App Review. The Meta app must stay in **Development** until tests pass.

## Prerequisites

- [ ] `./scripts/deploy.sh` completed on VPS
- [ ] n8n workflow imported and **Active**
- [ ] Meta webhook verified (`docs/meta-setup.md`)
- [ ] `./scripts/setup-meta.sh` succeeded
- [ ] Your Facebook account is an app admin/tester or has Page messaging role

## Webhook verification

1. In Meta Developer Console → Webhooks → click **Test** on `messages`.
2. In n8n → **Executions**, confirm a run hits **Return hub.challenge** or completes without error.

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
| No execution in n8n | Workflow inactive or wrong webhook URL |
| Verification fails | Verify token mismatch or workflow inactive |
| Execution but no reply | Invalid Page token; sender not in dev mode roles |
| Empty reply | Ollama model not pulled — run `./scripts/pull-models.sh` |

## Sign-off

When all rows pass, proceed to [`app-review.md`](app-review.md).
