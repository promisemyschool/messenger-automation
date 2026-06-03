#!/usr/bin/env bash
# Verify Meta webhook registration and challenge echo before Meta "Verify and save".
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ ! -f .env ]]; then
  echo "Missing .env — copy from .env.example and set DOMAIN, META_VERIFY_TOKEN."
  exit 1
fi

# shellcheck disable=SC1091
set -a
source .env
set +a

HOST="${N8N_HOST:-${DOMAIN:-}}"
VERIFY_TOKEN="${META_VERIFY_TOKEN:-}"
CHALLENGE="${WEBHOOK_VERIFY_CHALLENGE:-hello_meta_test}"

if [[ -z "$HOST" || -z "$VERIFY_TOKEN" ]]; then
  echo "Set N8N_HOST (or DOMAIN) and META_VERIFY_TOKEN in .env"
  exit 1
fi

if command -v docker >/dev/null 2>&1 && docker compose ps n8n >/dev/null 2>&1; then
  BLOCK_ENV="$(docker compose exec -T n8n printenv N8N_BLOCK_ENV_ACCESS_IN_NODE 2>/dev/null || true)"
  if [[ "$BLOCK_ENV" != "false" ]]; then
    echo "WARN: n8n container N8N_BLOCK_ENV_ACCESS_IN_NODE is not 'false' (got '${BLOCK_ENV:-<unset>}')."
    echo "      Add N8N_BLOCK_ENV_ACCESS_IN_NODE=false to .env, update docker-compose.yml, then:"
    echo "      docker compose up -d --force-recreate n8n"
  fi
fi

BASE="https://${HOST}/webhook/messenger"
VERIFY_URL="${BASE}?hub.mode=subscribe&hub.verify_token=${VERIFY_TOKEN}&hub.challenge=${CHALLENGE}"

echo "== GET verify (expect body: ${CHALLENGE}) =="
HTTP_CODE="$(curl -sS -o /tmp/verify-webhook-body.out -w "%{http_code}" "$VERIFY_URL" || true)"
BODY="$(cat /tmp/verify-webhook-body.out 2>/dev/null || true)"
if echo "$BODY" | grep -q 'not registered'; then
  echo "FAIL: webhook /webhook/messenger not registered (HTTP ${HTTP_CODE})"
  echo "Import n8n/messenger-auto-reply.workflow.json, path=messenger, publish. See docs/n8n-webhook-setup.md"
  exit 1
fi
if [[ "$BODY" == "$CHALLENGE" && "$HTTP_CODE" == "200" ]]; then
  echo "OK: challenge echoed"
else
  echo "FAIL: HTTP ${HTTP_CODE}, body '${BODY:-<empty>}' (expected '${CHALLENGE}')"
  echo "URL: ${VERIFY_URL}"
  echo "If HTTP 200 but empty: Meta Verification? failed (token/env) or old workflow still published."
  echo "On the VPS, check:"
  echo "  docker compose exec n8n printenv META_VERIFY_TOKEN"
  echo "  docker compose exec n8n printenv N8N_BLOCK_ENV_ACCESS_IN_NODE   # must be false"
  echo "  docker compose up -d --force-recreate n8n"
  echo "Re-import n8n/messenger-auto-reply.workflow.json, publish, then run this script again."
  exit 1
fi

echo ""
echo "== GET bare path (must not be 404 not registered) =="
BARE_CODE="$(curl -sS -o /tmp/webhook-bare.out -w "%{http_code}" "$BASE" || true)"
BARE_BODY="$(cat /tmp/webhook-bare.out 2>/dev/null || true)"
if echo "$BARE_BODY" | grep -q 'not registered'; then
  echo "FAIL: webhook path not registered — import workflow, path=messenger, publish"
  exit 1
fi
echo "OK: registered (HTTP ${BARE_CODE})"

echo ""
echo "== POST (must not be 'not registered for POST') =="
POST_BODY="$(curl -sS -X POST "$BASE" -H "Content-Type: application/json" -d '{"object":"page","entry":[]}' || true)"
if echo "$POST_BODY" | grep -q 'not registered for POST'; then
  echo "FAIL: POST not allowed — enable GET and POST on Messenger Webhook node"
  exit 1
fi
echo "OK: POST accepted"

echo ""
echo "Meta Callback URL: ${BASE}"
echo "Meta Verify token: ${VERIFY_TOKEN}"
