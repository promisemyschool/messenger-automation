#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

MODEL="${OLLAMA_MODEL:-qwen3:8b}"
docker compose exec -T ollama ollama pull "${MODEL}"
echo "Model ${MODEL} ready."
