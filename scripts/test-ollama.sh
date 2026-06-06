#!/usr/bin/env bash
# Verify Ollama is healthy and the configured model can generate a reply.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# shellcheck disable=SC1091
[[ -f .env ]] && set -a && source .env && set +a

MODEL="${OLLAMA_MODEL:-qwen3:8b}"
CHAT_TIMEOUT="${OLLAMA_TEST_TIMEOUT:-600}"

echo "== 1. Ollama container =="
docker compose ps ollama

echo ""
echo "== 2. Models pulled =="
docker compose exec -T ollama ollama list

if ! docker compose exec -T ollama ollama list | awk 'NR>1 {print $1}' | grep -Fxq "${MODEL}"; then
  echo ""
  echo "FAIL: ${MODEL} is not installed in Ollama."
  echo "      Run: ./scripts/pull-models.sh"
  echo "      (Changing .env alone is not enough — you must pull the model.)"
  exit 1
fi

echo ""
echo "== 2b. n8n env =="
N8N_MODEL="$(docker compose exec -T n8n printenv OLLAMA_MODEL 2>/dev/null || true)"
echo "OLLAMA_MODEL in n8n container: ${N8N_MODEL:-<unset>}"
if [[ "${N8N_MODEL}" != "${MODEL}" ]]; then
  echo "WARN: mismatch — run: docker compose up -d --force-recreate n8n"
fi

echo ""
echo "== 3. Host memory (larger models need more free RAM) =="
free -h | head -2 || true

echo ""
echo "== 4. Ping from n8n container =="
if docker compose exec -T n8n wget -qO- --timeout=5 http://ollama:11434/ 2>/dev/null | grep -qi ollama; then
  echo "OK: n8n can reach ollama:11434"
else
  echo "FAIL: n8n cannot reach http://ollama:11434 — check docker compose network"
  exit 1
fi

echo ""
echo "== 5. Generate test inside Ollama container (first run can take 5-10 min on CPU) =="
echo "    Model: ${MODEL} | timeout: ${CHAT_TIMEOUT}s"
echo "    Tip: in another SSH tab run: docker compose logs -f ollama"
echo ""

PAYLOAD="$(cat <<EOF
{
  "model": "${MODEL}",
  "prompt": "Reply with exactly one word: hello",
  "stream": false,
  "options": {"num_predict": 8, "temperature": 0}
}
EOF
)"

START=$(date +%s)
set +e
RESPONSE="$(timeout "${CHAT_TIMEOUT}" docker compose exec -T ollama \
  curl -sS -X POST http://127.0.0.1:11434/api/generate \
  -H "Content-Type: application/json" \
  -d "${PAYLOAD}" 2>&1)"
EXIT=$?
set -e
ELAPSED=$(( $(date +%s) - START ))

if [[ ${EXIT} -eq 124 ]]; then
  echo "FAIL: timed out after ${ELAPSED}s"
  echo "      qwen3:8b is often too slow on CPU VPS. In .env set:"
  echo "        OLLAMA_MODEL=qwen2.5:3b"
  echo "      Then: ./scripts/pull-models.sh && docker compose up -d --force-recreate ollama n8n"
  exit 1
fi

echo "${RESPONSE}" | head -c 600
echo ""
echo "(elapsed: ${ELAPSED}s)"

if echo "${RESPONSE}" | grep -q '"response"'; then
  echo "OK: Ollama generate works with ${MODEL}"
else
  echo "FAIL: no response field — check: docker compose logs ollama --tail 50"
  exit 1
fi

echo ""
echo "== 6. Chat API from n8n container (same URL as workflow) =="
CHAT_PAYLOAD="$(cat <<EOF
{
  "model": "${MODEL}",
  "messages": [{"role": "user", "content": "Say hello in one word"}],
  "stream": false,
  "options": {"num_predict": 8}
}
EOF
)"

N8N_RESPONSE="$(docker compose exec -T n8n wget -qO- --timeout="${CHAT_TIMEOUT}" \
  --header="Content-Type: application/json" \
  --post-data="${CHAT_PAYLOAD}" \
  http://ollama:11434/api/chat 2>&1 || true)"

echo "${N8N_RESPONSE}" | head -c 600
echo ""

if echo "${N8N_RESPONSE}" | grep -q '"message"'; then
  echo "OK: n8n → Ollama /api/chat works (workflow path is good)"
else
  echo "WARN: generate worked but n8n chat test unclear — re-import workflow and Publish"
fi
