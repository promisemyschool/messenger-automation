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

API_VERSION="${META_GRAPH_API_VERSION:-v22.0}"
CALLBACK_URL="https://${N8N_HOST:-$DOMAIN}/webhook/messenger"

# Step 1: App-level webhook field subscription (messages must be enabled on the app).
# Page subscribed_apps alone is NOT enough — Meta will not POST message events otherwise.
if [[ -n "${META_APP_ID:-}" && -n "${META_APP_SECRET:-}" && -n "${META_VERIFY_TOKEN:-}" ]]; then
  echo "Subscribing app ${META_APP_ID} to page webhook fields (messages)..."
  APP_TOKEN="${META_APP_ID}|${META_APP_SECRET}"
  APP_SUB="$(curl -sS -X POST \
    "https://graph.facebook.com/${API_VERSION}/${META_APP_ID}/subscriptions" \
    -d "object=page" \
    -d "callback_url=${CALLBACK_URL}" \
    -d "verify_token=${META_VERIFY_TOKEN}" \
    -d "fields=messages,messaging_postbacks" \
    -d "access_token=${APP_TOKEN}")"
  echo "${APP_SUB}"
  if echo "${APP_SUB}" | grep -q '"error"'; then
    echo "WARN: App subscription API failed — subscribe manually in Meta → Webhooks → Page → messages"
  fi
else
  echo "SKIP: App webhook fields — set META_APP_ID + META_APP_SECRET in .env for automation,"
  echo "      or subscribe manually: Meta Developer → Webhooks → Page → check messages → Subscribe"
fi

echo ""
echo "Subscribing Page ${META_PAGE_ID} to Messenger webhooks..."
SUBSCRIBE_RESPONSE="$(curl -fsS -X POST \
  "https://graph.facebook.com/${API_VERSION}/${META_PAGE_ID}/subscribed_apps?subscribed_fields=messages,messaging_postbacks&access_token=${META_PAGE_ACCESS_TOKEN}")"
echo "${SUBSCRIBE_RESPONSE}"

if ! echo "${SUBSCRIBE_RESPONSE}" | grep -q '"success":true'; then
  echo "FAIL: Page subscription did not return success:true"
  exit 1
fi

echo
echo "Current subscriptions (optional check):"
LIST_RESPONSE="$(curl -sS -w "\n%{http_code}" \
  "https://graph.facebook.com/${API_VERSION}/${META_PAGE_ID}/subscribed_apps?access_token=${META_PAGE_ACCESS_TOKEN}")"
LIST_HTTP="$(echo "${LIST_RESPONSE}" | tail -n1)"
LIST_BODY="$(echo "${LIST_RESPONSE}" | sed '$d')"
if [[ "${LIST_HTTP}" == "200" ]]; then
  echo "${LIST_BODY}"
else
  echo "WARN: Could not list subscriptions (HTTP ${LIST_HTTP}). Subscription still succeeded."
  echo "      Confirm in Meta → Webhooks → Page that messages is subscribed (not only Verify and save)."
  if [[ -n "${LIST_BODY}" ]]; then
    echo "${LIST_BODY}"
  fi
fi

echo
echo "Done."
echo "  1. ./scripts/verify-webhook.sh"
echo "  2. ./scripts/simulate-messenger-webhook.sh   # should create an n8n execution"
echo "  3. Meta → Webhooks → Page → messages → Test   # should also hit n8n"
echo
echo "Meta Developer Console:"
echo "  Callback URL: ${CALLBACK_URL}"
echo "  Verify token: ${META_VERIFY_TOKEN}"
echo "  Required fields: messages, messaging_postbacks"
