# Nginx Proxy Manager deployment

Use this when **NPM** (OpenResty) on the VPS terminates HTTPS instead of the built-in Caddy service.

## Stack

| Service | Role |
|---------|------|
| **n8n** | Webhook + workflow (port 5678, HTTP only inside Docker) |
| **Ollama** | Local LLM |
| **NPM** | Public HTTPS → proxy to n8n |

Do **not** run Caddy and NPM on the same host (both bind 80/443). Deploy with:

```bash
docker compose up -d   # starts n8n + ollama only (no Caddy profile)
```

## NPM proxy host settings

| Setting | Value |
|---------|--------|
| Domain | Your `DOMAIN` / `N8N_HOST` from `.env` |
| Scheme | **`http`** (not https) |
| Forward hostname | `n8n` or `messenger-automation-n8n-1` |
| Forward port | `5678` |
| Websockets | **On** |
| Block Common Exploits | Off if webhooks fail |

n8n listens on plain HTTP inside the container. If Scheme is `https`, NPM returns **502 Bad Gateway** even when n8n is healthy.

## Connect NPM to the Compose network

NPM must share Docker network `messenger-automation_default` with n8n:

```bash
docker network connect messenger-automation_default nginxproxymanager
```

Persist this in NPM’s `docker-compose.yml`:

```yaml
services:
  app:
    networks:
      - default
      - messenger

networks:
  messenger:
    external: true
    name: messenger-automation_default
```

(Adjust service name `app` to match your NPM compose file.)

## Verify

```bash
docker exec nginxproxymanager curl -s http://n8n:5678/healthz
# {"status":"ok"}

curl -sI https://<your-domain>/
# HTTP/2 200
```

## Webhook URL

```
https://<your-domain>/webhook/messenger
```

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| 502, n8n healthz OK from NPM | NPM Scheme must be **http** |
| 502, curl from NPM fails | `docker network connect messenger-automation_default nginxproxymanager` |
| n8n Restarting | `N8N_ENCRYPTION_KEY` must match the key in volume `n8n_data` (see n8n docs) |
| Wrong editor URL | `docker compose up -d --force-recreate n8n` after fixing `N8N_HOST` in `.env` |
