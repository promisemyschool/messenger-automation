# VPS deployment

## Requirements

- VPS with **8 GB RAM** minimum (`qwen3:8b`) or **16 GB** (`qwen3:14b`)
- Ubuntu 22.04+ or similar
- Docker Engine + Docker Compose plugin
- DNS A record: `automation.promiseschool.com` → VPS IP

## Quick start

```bash
# On the VPS
git clone <your-repo> && cd PS-SCHL/messenger-automation
cp .env.example .env
# Edit .env — set DOMAIN, secrets, Meta tokens

chmod +x scripts/*.sh
./scripts/deploy.sh
```

## What gets deployed

| Service | Role |
|---------|------|
| **Caddy** | HTTPS (Let's Encrypt) → reverse proxy to n8n |
| **n8n** | Webhook + workflow engine |
| **Ollama** | Local LLM (`qwen3:8b` by default) |

Knowledge files are mounted read-only at `/knowledge` inside the n8n container.

## Import the n8n workflow

1. Open `https://<your-domain>` and log in with basic auth from `.env`.
2. **Workflows → Import from File** → select `n8n/messenger-auto-reply.workflow.json`.
3. Open the workflow and confirm environment variables are visible to n8n (set in `docker-compose.yml`).
4. Toggle **Active**.

Production webhook URL (use in Meta):

```
https://<your-domain>/webhook/messenger
```

## Sync FAQ knowledge after landing site changes

From repo root on your dev machine:

```bash
node messenger-automation/scripts/export-faq.mjs
# Copy knowledge/faq.json to VPS, or git pull + restart n8n:
docker compose restart n8n
```

## Firewall

Allow only:

- `80/tcp`, `443/tcp` (public)
- `22/tcp` (SSH, restrict by IP if possible)

Do **not** expose Ollama (`11434`) or n8n directly without auth.

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Meta webhook verification fails | Workflow must be **Active**; webhook uses **Respond to Webhook** node; verify token must match |
| No replies in Development mode | Sender must be app admin/tester or Page role |
| Ollama timeout | Use `qwen3:8b`; increase VPS RAM; check `docker compose logs ollama` |
| 502 from Caddy | `docker compose ps` — wait for n8n to start |

## Operations

```bash
docker compose logs -f n8n
docker compose logs -f ollama
docker compose restart n8n
./scripts/pull-models.sh   # re-pull Ollama model
```
