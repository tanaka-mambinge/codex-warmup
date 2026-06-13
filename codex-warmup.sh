#!/usr/bin/env bash
set -euo pipefail

notify() {
  local subject="$1"
  local message="$2"

  if [ -z "${RESEND_API_KEY:-}" ] || [ -z "${NOTIFY_EMAIL:-}" ] || [ -z "${FROM_NAME:-}" ] || [ -z "${FROM_EMAIL_ADDRESS:-}" ]; then
    echo "[codex-warmup] notification skipped: missing RESEND_API_KEY, NOTIFY_EMAIL, FROM_NAME, or FROM_EMAIL_ADDRESS"
    return 0
  fi

  local from
  from="${FROM_NAME} <${FROM_EMAIL_ADDRESS}>"

  local payload
  payload="$(jq -n \
    --arg from "$from" \
    --arg to "$NOTIFY_EMAIL" \
    --arg subject "$subject" \
    --arg text "$message" \
    '{from: $from, to: [$to], subject: $subject, text: $text}')"

  local response
  local http_code
  local body

  response="$(curl -sS -w '\n%{http_code}' -X POST "https://api.resend.com/emails" \
    -H "Authorization: Bearer ${RESEND_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "$payload")"

  http_code="$(echo "$response" | tail -n1)"
  body="$(echo "$response" | sed '$d')"

  echo "[codex-warmup] resend http status: $http_code"
  echo "[codex-warmup] resend response: $body"

  if [ "$http_code" -lt 200 ] || [ "$http_code" -ge 300 ]; then
    echo "[codex-warmup] notification failed"
    return 1
  fi
}

echo "[codex-warmup] $(date -Is) starting"

SUBJECT_TIME="$(TZ=Africa/Harare date '+%a %d %b, %H:%M')"

mkdir -p "$HOME/.codex" /tmp/codex-work
cd /tmp/codex-work

if [ -z "${CODEX_AUTH_JSON:-}" ]; then
  NOW="$(TZ=Africa/Harare date '+%a %d %b %Y, %H:%M %Z')"

  echo "[codex-warmup] ERROR: CODEX_AUTH_JSON env var is missing"

  notify "Codex Warmup — FAILED — ${SUBJECT_TIME}" "Codex warmup failed.

Time: ${NOW}
Reason: CODEX_AUTH_JSON environment variable is missing.

Action needed: check the Dokploy environment variables."

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

set +e
OUTPUT="$(codex exec --skip-git-repo-check "hi" 2>&1)"
EXIT_CODE=$?
set -e

echo "$OUTPUT"

HARARE_TIME="$(TZ=Africa/Harare date '+%H:%M')"
HARARE_DATE="$(TZ=Africa/Harare date '+%a %d %b %Y')"
UTC_TIME="$(TZ=UTC date '+%H:%M UTC')"

if [ "$EXIT_CODE" -eq 0 ] && echo "$OUTPUT" | grep -qi "codex"; then
  notify "Codex Warmup — OK — ${SUBJECT_TIME}" "Your Codex warmup completed successfully.

Session: active
Model: gpt-5.4-mini
Date: ${HARARE_DATE}
Time: ${HARARE_TIME} Harare time
UTC: ${UTC_TIME}

No action needed."

  echo "[codex-warmup] $(date -Is) done"
else
  notify "Codex Warmup — FAILED — ${SUBJECT_TIME}" "Codex warmup failed.

Date: ${HARARE_DATE}
Time: ${HARARE_TIME} Harare time
UTC: ${UTC_TIME}
Exit code: ${EXIT_CODE}

Output:
${OUTPUT}"

  exit "$EXIT_CODE"
fi