#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# shellcheck disable=SC1091
[[ -f .env ]] && set -a && source .env && set +a

MODEL="${OLLAMA_MODEL:-qwen3:8b}"

echo "Pulling Ollama model: ${MODEL}"
docker compose exec -T ollama ollama pull "${MODEL}"

echo ""
echo "Installed models:"
docker compose exec -T ollama ollama list

if ! docker compose exec -T ollama ollama list | awk 'NR>1 {print $1}' | grep -Fxq "${MODEL}"; then
  echo "FAIL: ${MODEL} not found after pull — check the name on https://ollama.com/library/qwen2.5"
  exit 1
fi

echo ""
echo "Recreating n8n so OLLAMA_MODEL=${MODEL} is loaded into the container..."
docker compose up -d --force-recreate n8n

echo ""
echo "n8n OLLAMA_MODEL=$(docker compose exec -T n8n printenv OLLAMA_MODEL 2>/dev/null || echo '<unset>')"
echo "Model ${MODEL} ready. Run ./scripts/test-ollama.sh"
