#!/usr/bin/env bash
# Verify n8n can reach Ollama and the configured model responds.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# shellcheck disable=SC1091
[[ -f .env ]] && set -a && source .env && set +a

MODEL="${OLLAMA_MODEL:-qwen3:8b}"

echo "== 1. Ollama container =="
docker compose ps ollama

echo ""
echo "== 2. Models pulled =="
docker compose exec -T ollama ollama list

echo ""
echo "== 3. Ping from n8n container =="
if docker compose exec -T n8n wget -qO- --timeout=5 http://ollama:11434/ 2>/dev/null; then
  echo "OK: n8n can reach ollama:11434"
else
  echo "FAIL: n8n cannot reach http://ollama:11434 — check docker compose network"
  exit 1
fi

echo ""
echo "== 4. Chat test (may take 1-3 min on CPU VPS) =="
PAYLOAD="$(cat <<EOF
{
  "model": "${MODEL}",
  "messages": [{"role": "user", "content": "Reply with one word: hello"}],
  "stream": false,
  "options": {"num_predict": 16}
}
EOF
)"

RESPONSE="$(docker compose exec -T n8n curl -sS -m 180 \
  -X POST http://ollama:11434/api/chat \
  -H "Content-Type: application/json" \
  -d "${PAYLOAD}")"

echo "${RESPONSE}" | head -c 500
echo ""

if echo "${RESPONSE}" | grep -q '"message"'; then
  echo "OK: Ollama chat works with model ${MODEL}"
else
  echo "FAIL: Ollama did not return a message — run ./scripts/pull-models.sh"
  echo "      If VPS has <8GB RAM, try OLLAMA_MODEL=qwen2.5:3b in .env"
  exit 1
fi
