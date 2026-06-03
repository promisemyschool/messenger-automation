# n8n webhook setup (Messenger / Meta)

Use this after deploy when Meta **Verify and save** fails or curl returns 404 / empty body.

## Import the canonical workflow

1. Open n8n → **Workflows**.
2. **Deactivate / unpublish** any copy using a UUID webhook path (e.g. `2d6ff4b5-...`).
3. **Import from file** → [`n8n/messenger-auto-reply.workflow.json`](../n8n/messenger-auto-reply.workflow.json).
4. Confirm two webhook triggers (same path, different methods):

| Node | Path | Method |
|------|------|--------|
| **Messenger Webhook GET** | `messenger` | GET (Meta verify) |
| **Messenger Webhook POST** | `messenger` | POST (incoming messages) |

Both: **Authentication** None, **Respond** Using **Respond to Webhook** node.  
Production URL for both: `https://<your-domain>/webhook/messenger`

5. **Save** → **Publish**.

## VPS environment

In `.env` on the server:

```bash
META_VERIFY_TOKEN=<same as Meta console>
N8N_BLOCK_ENV_ACCESS_IN_NODE=false
```

Recreate n8n after changes:

```bash
cd /var/messenger-automation
docker compose up -d --force-recreate n8n
```

## Verify before Meta

From the project directory (local or VPS):

```bash
chmod +x scripts/verify-webhook.sh
./scripts/verify-webhook.sh
```

Success means:

- GET with `hub.challenge` returns that string as plain text
- `/webhook/messenger` is registered (not 404)
- POST is accepted (not “not registered for POST”)

## Meta Developer Console

- **Callback URL:** `https://<your-domain>/webhook/messenger`
- **Verify token:** same as `META_VERIFY_TOKEN`
- **Verify and save**
- Subscribe: `messages`, `messaging_postbacks`

During verify, n8n **Executions** should run **Normalize Meta Query** → **Meta Verification?** (true) → **Return hub.challenge**, not only **Ack Skipped Event**.

If `./scripts/verify-webhook.sh` returns HTTP 200 with an empty body:

```bash
docker compose exec n8n printenv META_VERIFY_TOKEN
docker compose exec n8n printenv N8N_BLOCK_ENV_ACCESS_IN_NODE   # expect false
docker compose up -d --force-recreate n8n
```

Then re-import the workflow and **Publish** again.
