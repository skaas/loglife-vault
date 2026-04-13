#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: scripts/send-post-compile-todo.sh [--dry-run] [--todo-file PATH]" >&2
}

repo_root="$(git rev-parse --show-toplevel)"
todo_file="${repo_root}/Wiki/Self/TODO.md"
dry_run=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      dry_run=1
      shift
      ;;
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

digest="$("${repo_root}/scripts/build-todo-digest.sh" --todo-file "$todo_file")"

if [[ "$dry_run" -eq 1 ]]; then
  printf '%s\n' "$digest"
  exit 0
fi

printf '%s' "$digest" | "${repo_root}/scripts/send-telegram-message.sh"
