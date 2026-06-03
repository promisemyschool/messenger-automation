#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ ! -f .env ]]; then
  echo "Copy .env.example to .env and fill in values first."
  exit 1
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

: "${META_PAGE_ID:?Set META_PAGE_ID in .env}"
: "${META_PAGE_ACCESS_TOKEN:?Set META_PAGE_ACCESS_TOKEN in .env}"

echo "Subscribing Page ${META_PAGE_ID} to Messenger webhooks..."
SUBSCRIBE_RESPONSE="$(curl -fsS -X POST \
  "https://graph.facebook.com/${META_GRAPH_API_VERSION:-v22.0}/${META_PAGE_ID}/subscribed_apps?subscribed_fields=messages,messaging_postbacks&access_token=${META_PAGE_ACCESS_TOKEN}")"
echo "${SUBSCRIBE_RESPONSE}"

if ! echo "${SUBSCRIBE_RESPONSE}" | grep -q '"success":true'; then
  echo "FAIL: Page subscription did not return success:true"
  exit 1
fi

echo
echo "Current subscriptions (optional check):"
LIST_RESPONSE="$(curl -sS -w "\n%{http_code}" \
  "https://graph.facebook.com/${META_GRAPH_API_VERSION:-v22.0}/${META_PAGE_ID}/subscribed_apps?access_token=${META_PAGE_ACCESS_TOKEN}")"
LIST_HTTP="$(echo "${LIST_RESPONSE}" | tail -n1)"
LIST_BODY="$(echo "${LIST_RESPONSE}" | sed '$d')"
if [[ "${LIST_HTTP}" == "200" ]]; then
  echo "${LIST_BODY}"
else
  echo "WARN: Could not list subscriptions (HTTP ${LIST_HTTP}). Subscription still succeeded."
  echo "      Confirm in Meta → Messenger → Webhooks that the Page is connected."
  if [[ -n "${LIST_BODY}" ]]; then
    echo "${LIST_BODY}"
  fi
fi

echo
echo "Done. Page subscribed. Next: ./scripts/verify-webhook.sh"
echo "Meta Developer Console:"
echo "  Callback URL: https://${N8N_HOST:-$DOMAIN}/webhook/messenger"
echo "  Verify token: ${META_VERIFY_TOKEN}"
echo "  Subscribe fields: messages, messaging_postbacks"
