#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "Created .env from .env.example — edit it before continuing."
  exit 1
fi

docker compose pull
docker compose up -d

echo "Waiting for Ollama..."
until docker compose exec -T ollama ollama list >/dev/null 2>&1; do
  sleep 3
done

MODEL="${OLLAMA_MODEL:-qwen3:8b}"
echo "Pulling model ${MODEL}..."
docker compose exec -T ollama ollama pull "${MODEL}"

echo
echo "Stack is up."
echo "  n8n UI: https://${N8N_HOST:-${DOMAIN:-automation.promiseschool.com}}"
echo "  Import + publish: docs/n8n-webhook-setup.md"
echo "  Verify webhook: ./scripts/verify-webhook.sh"
echo "  Then Meta: ./scripts/setup-meta.sh"
