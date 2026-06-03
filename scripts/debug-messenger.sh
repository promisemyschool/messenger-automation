#!/usr/bin/env bash
# Quick diagnostics when Messenger messages don't get replies.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# shellcheck disable=SC1091
[[ -f .env ]] && set -a && source .env && set +a

echo "== 1. Webhook (local) =="
./scripts/verify-webhook.sh || true

echo ""
echo "== 2. n8n container env =="
docker compose exec -T n8n printenv META_PAGE_ID 2>/dev/null || echo "n8n not running"
docker compose exec -T n8n printenv N8N_BLOCK_ENV_ACCESS_IN_NODE 2>/dev/null || true
TOKEN_LEN="$(docker compose exec -T n8n printenv META_PAGE_ACCESS_TOKEN 2>/dev/null | wc -c | tr -d ' ')"
echo "META_PAGE_ACCESS_TOKEN length in container: ${TOKEN_LEN} chars (expect > 100)"

echo ""
echo "== 3. Ollama model =="
docker compose exec -T ollama ollama list 2>/dev/null || echo "ollama not running"
echo "Expected model from .env: ${OLLAMA_MODEL:-qwen3:8b}"

echo ""
echo "== 4. Page token (Graph API /me) =="
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
echo "== 5. What to check in n8n UI =="
echo "  - Workflow is Published (not only saved)"
echo "  - After you DM the Page: Executions → latest run"
echo "  - If no execution: Meta webhook not delivering (check Meta → Show Recent Errors)"
echo "  - If execution errors on Ollama Chat: run ./scripts/pull-models.sh"
echo "  - If Send Messenger Reply fails: token or Development mode (sender must be app tester)"
echo ""
echo "== 6. Development mode =="
echo "  Meta app in Development → only admins/developers/testers get bot replies."
echo "  Add your Facebook account under App Roles → Roles → Tester."
