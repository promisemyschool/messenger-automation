#!/usr/bin/env bash
# POST a fake Meta "messages" payload to production webhook.
# If n8n is wired correctly, a new execution should appear within seconds.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ ! -f .env ]]; then
  echo "Missing .env"
  exit 1
fi

# shellcheck disable=SC1091
set -a
source .env
set +a

HOST="${N8N_HOST:-${DOMAIN:-}}"
PAGE_ID="${META_PAGE_ID:-105701222491238}"
SENDER_ID="${SIMULATE_SENDER_PSID:-999000111222333}"
TEXT="${SIMULATE_MESSAGE_TEXT:-hello from simulate-messenger-webhook.sh}"

if [[ -z "$HOST" ]]; then
  echo "Set N8N_HOST or DOMAIN in .env"
  exit 1
fi

URL="https://${HOST}/webhook/messenger"
MID="mid.simulate.$(date +%s)"

PAYLOAD="$(cat <<EOF
{
  "object": "page",
  "entry": [{
    "id": "${PAGE_ID}",
    "time": $(date +%s),
    "messaging": [{
      "sender": { "id": "${SENDER_ID}" },
      "recipient": { "id": "${PAGE_ID}" },
      "timestamp": $(date +%s)000,
      "message": {
        "mid": "${MID}",
        "text": "${TEXT}"
      }
    }]
  }]
}
EOF
)"

echo "POST ${URL}"
HTTP_CODE="$(curl -sS -o /tmp/simulate-webhook.out -w "%{http_code}" \
  -X POST "$URL" \
  -H "Content-Type: application/json" \
  -H "User-Agent: facebookexternalua" \
  -d "$PAYLOAD")"
BODY="$(cat /tmp/simulate-webhook.out 2>/dev/null || true)"

if echo "$BODY" | grep -q 'not registered'; then
  echo "FAIL: webhook not registered — import workflow, path=messenger, Publish"
  exit 1
fi

if [[ "$HTTP_CODE" != "200" ]]; then
  echo "FAIL: HTTP ${HTTP_CODE}"
  echo "${BODY}"
  exit 1
fi

echo "OK: HTTP 200 (empty body is normal — Ack Webhook responded)"
echo ""
echo "Now open n8n → Workflows → Promise School Messenger Auto-Reply → Executions."
echo "You should see a new run triggered by Messenger Webhook POST within ~30s."
echo "If you see an execution here but NOT when you DM the Page on Facebook,"
echo "Meta is not delivering webhooks — see docs/meta-setup.md § 'messages field'."
