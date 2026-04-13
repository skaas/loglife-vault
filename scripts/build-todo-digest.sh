#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: scripts/build-todo-digest.sh [--todo-file PATH]" >&2
}

repo_root="$(git rev-parse --show-toplevel)"
todo_file="${repo_root}/Wiki/Self/TODO.md"
timezone="${LOGLIFE_NOTIFY_TZ:-Asia/Seoul}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --todo-file)
      [[ $# -ge 2 ]] || {
        usage
        exit 2
      }
      todo_file="$2"
      shift 2
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

[[ -f "$todo_file" ]] || {
  echo "todo digest: missing file: ${todo_file}" >&2
  exit 1
}

items="$(
  awk '
    /^## 현재 할 일/ { in_section = 1; next }
    /^## / && in_section { exit }
    in_section && /^- / {
      sub(/^- /, "", $0)
      print
    }
  ' "$todo_file"
)"

normalize_line() {
  printf '%s' "$1" |
    sed -E 's/\[([^]]+)\]\(<[^>]+>\)/\1/g; s/`//g'
}

today="$(TZ="$timezone" date +%F)"

count=0
if [[ -n "${items}" ]]; then
  count="$(printf '%s\n' "$items" | sed '/^[[:space:]]*$/d' | wc -l | tr -d ' ')"
fi

if [[ "${count}" == "0" ]]; then
  printf '[loglife] %s compile 후 TODO\n현재 할 일 없음\n' "$today"
  exit 0
fi

printf '[loglife] %s compile 후 TODO (%s건)\n' "$today" "$count"

index=1
while IFS= read -r raw_line; do
  [[ -n "$raw_line" ]] || continue
  line="$(normalize_line "$raw_line")"
  printf '%s. %s\n' "$index" "$line"
  index=$((index + 1))
done <<<"$items"
