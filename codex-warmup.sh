#!/usr/bin/env bash
set -euo pipefail

echo "[codex-warmup] $(date -Is) starting"

TMP_HOME="$(mktemp -d /tmp/codex-fake-home.XXXXXX)"
TMP_WORKDIR="$(mktemp -d /tmp/codex-work.XXXXXX)"

cleanup() {
  rm -rf "$TMP_HOME" "$TMP_WORKDIR"
}
trap cleanup EXIT

mkdir -p "$TMP_HOME/.codex"

if [ -z "${CODEX_AUTH_JSON:-}" ]; then
  echo "[codex-warmup] ERROR: CODEX_AUTH_JSON env var is missing"
  exit 1
fi

printf '%s' "$CODEX_AUTH_JSON" > "$TMP_HOME/.codex/auth.json"
chmod 600 "$TMP_HOME/.codex/auth.json"

cat > "$TMP_HOME/.codex/config.toml" <<'CONFIG'
model = "gpt-5.4-mini"
model_reasoning_effort = "none"
approval_policy = "never"
sandbox_mode = "read-only"

[mcp_servers]
CONFIG

cd "$TMP_WORKDIR"

HOME="$TMP_HOME" codex exec --skip-git-repo-check "hi"

echo "[codex-warmup] $(date -Is) done"