#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: scripts/compile.sh [--stdout-today] [--today-file PATH] [--todo-file PATH] [--skip-todo-writing-topic]" >&2
}

repo_root="$(git rev-parse --show-toplevel)"
today_args=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stdout-today)
      today_args+=(--stdout)
      shift
      ;;
    --today-file|--todo-file)
      [[ $# -ge 2 ]] || {
        usage
        exit 2
      }
      today_args+=("$1" "$2")
      shift 2
      ;;
    --skip-todo-writing-topic)
      today_args+=("$1")
      shift
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

if [[ ${#today_args[@]} -gt 0 ]]; then
  "${repo_root}/scripts/compile-today-focus.sh" "${today_args[@]}"
else
  "${repo_root}/scripts/compile-today-focus.sh"
fi
