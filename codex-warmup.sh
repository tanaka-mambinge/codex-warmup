#!/usr/bin/env bash
set -euo pipefail

echo "[codex-warmup] $(date -Is) starting"

mkdir -p "$HOME/.codex" /tmp/codex-work
cd /tmp/codex-work

if [ -z "${CODEX_AUTH_JSON:-}" ]; then
  echo "[codex-warmup] ERROR: CODEX_AUTH_JSON env var is missing"
  exit 1
fi

printf '%s' "$CODEX_AUTH_JSON" > "$HOME/.codex/auth.json"
chmod 600 "$HOME/.codex/auth.json"

cat > "$HOME/.codex/config.toml" <<'CONFIG'
model = "gpt-5.4-mini"
model_reasoning_effort = "none"
approval_policy = "never"
sandbox_mode = "read-only"

[mcp_servers]
CONFIG

codex exec --skip-git-repo-check "hi"

echo "[codex-warmup] $(date -Is) done"