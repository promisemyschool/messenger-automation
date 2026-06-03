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
curl -fsS -X POST \
  "https://graph.facebook.com/${META_GRAPH_API_VERSION:-v22.0}/${META_PAGE_ID}/subscribed_apps?subscribed_fields=messages,messaging_postbacks&access_token=${META_PAGE_ACCESS_TOKEN}"

echo
echo "Current subscriptions:"
curl -fsS \
  "https://graph.facebook.com/${META_GRAPH_API_VERSION:-v22.0}/${META_PAGE_ID}/subscribed_apps?access_token=${META_PAGE_ACCESS_TOKEN}"

echo
echo "Done. Before Meta 'Verify and save', run: ./scripts/verify-webhook.sh"
echo "Meta Developer Console:"
echo "  Callback URL: https://${N8N_HOST:-$DOMAIN}/webhook/messenger"
echo "  Verify token: ${META_VERIFY_TOKEN}"
echo "  Subscribe fields: messages, messaging_postbacks"
