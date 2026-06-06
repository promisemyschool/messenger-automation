#!/usr/bin/env bash
# Quick diagnostics when Messenger messages don't get replies.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# shellcheck disable=SC1091
[[ -f .env ]] && set -a && source .env && set +a

echo "== 1. Webhook registration =="
./scripts/verify-webhook.sh || true

echo ""
echo "== 2. Simulate Meta message POST (should create n8n execution) =="
./scripts/simulate-messenger-webhook.sh || true

echo ""
echo "== 3. n8n container env =="
docker compose exec -T n8n printenv META_PAGE_ID 2>/dev/null || echo "n8n not running locally (OK if diagnosing remote VPS only)"
docker compose exec -T n8n printenv N8N_BLOCK_ENV_ACCESS_IN_NODE 2>/dev/null || true
TOKEN_LEN="$(docker compose exec -T n8n printenv META_PAGE_ACCESS_TOKEN 2>/dev/null | wc -c | tr -d ' ')"
echo "META_PAGE_ACCESS_TOKEN length in container: ${TOKEN_LEN} chars (expect > 100)"

echo ""
echo "== 4. Ollama model =="
docker compose exec -T ollama ollama list 2>/dev/null || echo "ollama not running"
echo "Expected model from .env: ${OLLAMA_MODEL:-qwen3:8b}"

echo ""
echo "== 5. Page token (Graph API /me) =="
if [[ -n "${META_PAGE_ACCESS_TOKEN:-}" ]]; then
  ME="$(curl -sS "https://graph.facebook.com/${META_GRAPH_API_VERSION:-v22.0}/me?fields=id,name&access_token=${META_PAGE_ACCESS_TOKEN}")"
  echo "${ME}"
  if echo "${ME}" | grep -q '"error"'; then
    echo "FAIL: Page token invalid or expired — regenerate in Meta → Messenger → Generate token"
  fi
else
  echo "SKIP: META_PAGE_ACCESS_TOKEN not set in .env"
fi

echo ""
echo "== 6. n8n UI =="
echo "  - Only ONE published workflow with path messenger (deactivate UUID-path copies)"
echo "  - Executions tab on 'Promise School Messenger Auto-Reply'"
echo "  - simulate script above should add a run; if yes but Facebook DMs do not → Meta delivery issue"

echo ""
echo "== 7. Meta console (most common: no executions on real DMs) =="
echo "  A. developers.facebook.com → your app → Webhooks"
echo "     - Callback URL: https://${N8N_HOST:-$DOMAIN}/webhook/messenger"
echo "     - Object: Page → Subscribe → check messages + messaging_postbacks"
echo "     - Click Test next to messages — n8n should get a new execution"
echo "  B. Messenger → Settings → connect Promise School Page"
echo "  C. ./scripts/setup-meta.sh (needs META_APP_ID + META_APP_SECRET for app-level fields)"
echo "  D. Message the Page from your personal Facebook (not 'reply as Page')"
echo "  E. Development mode: App Roles → add your account as Tester"
echo "  F. NPM: turn OFF 'Block Common Exploits' if Meta Test fails with 403"

echo ""
echo "== 8. Development mode =="
echo "  Meta app in Development → only admins/developers/testers get bot replies."
echo "  Webhooks still fire for testers; add your Facebook account under App Roles → Tester."
