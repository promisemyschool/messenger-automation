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
2. **[VPS deploy](docs/vps-deploy.md)** — Docker Compose (n8n + Ollama; Caddy or [NPM](docs/nginx-proxy-manager.md))
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
- Escalation for refunds, account issues, bugs → support email in chat

## Knowledge base (FAQ)

The bot loads Q&As from [`knowledge/faq-items.json`](knowledge/faq-items.json). See **[`docs/knowledge.md`](docs/knowledge.md)** for full guide.

**Sync from live site** (FAQs + HobbyCamp courses):

```bash
cd messenger-automation
node scripts/sync-knowledge-from-site.mjs
```

**Sync general FAQs from landing repo** (optional):

```bash
node scripts/export-faq.mjs
```

Source: [`promise-school-landing/src/data/faq.ts`](../promise-school-landing/promise-school-landing/src/data/faq.ts)

## Environment variables

See [`.env.example`](.env.example). Required:

| Variable | Purpose |
|----------|---------|
| `DOMAIN` | Public hostname for HTTPS |
| `META_VERIFY_TOKEN` | Must match Meta webhook config |
| `N8N_BLOCK_ENV_ACCESS_IN_NODE` | Set `false` (in `.env` + `docker-compose.yml`) for `$env` in workflow |
| `META_PAGE_ACCESS_TOKEN` | Long-lived Page token |
| `META_PAGE_ID` | Promise School Page ID |
| `OLLAMA_MODEL` | Default `qwen3:8b` |

## Files

| Path | Purpose |
|------|---------|
| `docker-compose.yml` | Caddy, n8n, Ollama |
| `n8n/messenger-auto-reply.workflow.json` | Importable workflow |
| `knowledge/faq.json` | Bot knowledge base (canonical) |
| `knowledge/faq-items.json` | Runtime FAQ array for n8n |
| `docs/knowledge.md` | How to add/sync Q&As |
| `scripts/sync-knowledge-from-site.mjs` | Sync from promiseschool.app |
| `docs/meta-setup.md` | Meta Developer Console steps |
| `docs/n8n-webhook-setup.md` | Webhook path, publish, curl gate |
| `scripts/verify-webhook.sh` | Pre-flight Meta webhook test |
| `docs/vps-deploy.md` | VPS + Docker instructions |
| `docs/nginx-proxy-manager.md` | NPM reverse proxy setup |
| `docs/app-review.md` | Go Live checklist |

## Cost

Software is free. You pay only for VPS hosting (~$5–12/mo) and domain DNS.
