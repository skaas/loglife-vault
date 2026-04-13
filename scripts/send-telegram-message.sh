#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: scripts/send-telegram-message.sh [message]" >&2
  echo "reads stdin when message is omitted" >&2
}

if [[ "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck disable=SC1091
source "${repo_root}/scripts/load-local-env.sh"

: "${TELEGRAM_BOT_TOKEN:?set TELEGRAM_BOT_TOKEN first}"
: "${TELEGRAM_CHAT_ID:?set TELEGRAM_CHAT_ID first}"

if [[ $# -gt 0 ]]; then
  message="$*"
else
  message="$(cat)"
fi

[[ -n "${message}" ]] || {
  echo "telegram send: empty message" >&2
  exit 1
}

curl -fsS --retry 3 --retry-delay 1 \
  "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
  --data-urlencode "text=${message}" \
  --data "disable_web_page_preview=true" \
  >/dev/null

echo "telegram send: delivered" >&2
