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
| **Caddy** (optional profile) | HTTPS → n8n — run with `docker compose --profile caddy up -d` |
| **n8n** | Webhook + workflow engine |
| **Ollama** | Local LLM (`qwen3:8b` by default) |

Using **Nginx Proxy Manager** instead? See [`nginx-proxy-manager.md`](nginx-proxy-manager.md).

Knowledge files are mounted read-only at `/knowledge` inside the n8n container.

## Import the n8n workflow

See [`n8n-webhook-setup.md`](n8n-webhook-setup.md) for full steps.

1. Open `https://<your-domain>` and log in with basic auth from `.env`.
2. **Workflows → Import from File** → select `n8n/messenger-auto-reply.workflow.json`.
3. Confirm **Messenger Webhook** path is `messenger`, methods **GET + POST**, auth **None**.
4. **Publish** the workflow.

Production webhook URL (use in Meta):

```
https://<your-domain>/webhook/messenger
```

Verify before Meta:

```bash
./scripts/verify-webhook.sh
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
| Meta webhook verification fails | Run `./scripts/verify-webhook.sh`; path `messenger`; `N8N_BLOCK_ENV_ACCESS_IN_NODE=false`; republish workflow |
| `Module 'fs' is disallowed` in Prepare Prompt | Re-import workflow (uses **Read FAQ** + **Extract FAQ**, not `fs`). Set `N8N_RESTRICT_FILE_ACCESS_TO=/knowledge`, recreate n8n |
| No replies in Development mode | Sender must be app admin/tester or Page role |
| Ollama timeout | Use `qwen3:8b`; increase VPS RAM; check `docker compose logs ollama` |
| 502 from Caddy | `docker compose ps` — wait for n8n to start |
| 502 from NPM, n8n healthy | NPM forward **Scheme** must be `http`, not `https` |
| 502 from NPM, curl to n8n fails | Connect NPM to `messenger-automation_default` network |

## Operations

```bash
docker compose logs -f n8n
docker compose logs -f ollama
docker compose restart n8n
./scripts/pull-models.sh   # re-pull Ollama model
```
