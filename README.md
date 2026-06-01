# Promise School Facebook Messenger Auto-Reply

Self-hosted **n8n + Ollama** stack for intelligent, FAQ-grounded Messenger replies on the Promise School Facebook Page.

## Architecture

```
Messenger user → Meta Graph API → n8n webhook → Ollama (qwen3:8b) → Meta send API → user
                                      ↓
                              /knowledge/faq.json
```

## Quick start

1. **[Meta setup](docs/meta-setup.md)** — create app, Page token, verify token
2. **[VPS deploy](docs/vps-deploy.md)** — Docker Compose (Caddy + n8n + Ollama)
3. Import **`n8n/messenger-auto-reply.workflow.json`** and activate
4. Run **`./scripts/setup-meta.sh`** to subscribe the Page
5. **[Development testing](docs/testing.md)** — verify FAQ, Bangla, escalation
6. **[App Review](docs/app-review.md)** — go Live for all users

```bash
cd messenger-automation
cp .env.example .env   # fill in secrets
chmod +x scripts/*.sh
./scripts/deploy.sh
```

## Features

- Meta webhook verification (GET `hub.challenge`)
- FAQ-grounded replies from [`knowledge/faq.json`](knowledge/faq.json)
- Bangla / English language mirroring via Qwen
- Conversation memory (last 10 turns per user)
- Typing indicator + 1s human delay
- Escalation for refunds, account issues, bugs → support email
- Optional SMTP alert on escalation (`ESCALATION_NOTIFY_EMAIL`)

## Sync FAQ from landing site

```bash
node messenger-automation/scripts/export-faq.mjs
```

Source of truth: [`promise-school-landing/src/data/faq.ts`](../promise-school-landing/promise-school-landing/src/data/faq.ts)

## Environment variables

See [`.env.example`](.env.example). Required:

| Variable | Purpose |
|----------|---------|
| `DOMAIN` | Public hostname for HTTPS |
| `META_VERIFY_TOKEN` | Must match Meta webhook config |
| `META_PAGE_ACCESS_TOKEN` | Long-lived Page token |
| `META_PAGE_ID` | Promise School Page ID |
| `OLLAMA_MODEL` | Default `qwen3:8b` |

## Files

| Path | Purpose |
|------|---------|
| `docker-compose.yml` | Caddy, n8n, Ollama |
| `n8n/messenger-auto-reply.workflow.json` | Importable workflow |
| `knowledge/faq.json` | Bot knowledge base |
| `docs/meta-setup.md` | Meta Developer Console steps |
| `docs/vps-deploy.md` | VPS + Docker instructions |
| `docs/app-review.md` | Go Live checklist |

## Cost

Software is free. You pay only for VPS hosting (~$5–12/mo) and domain DNS.
