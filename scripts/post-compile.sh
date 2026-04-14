#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: scripts/post-compile.sh [--dry-run] [--skip-telegram] [--daily-file PATH] [--calendar-report PATH]" >&2
}

repo_root="$(git rev-parse --show-toplevel)"
daily_file=""
calendar_report=""
dry_run=0
skip_telegram=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      dry_run=1
      shift
      ;;
    --skip-telegram)
      skip_telegram=1
      shift
      ;;
    --daily-file)
      [[ $# -ge 2 ]] || {
        usage
        exit 2
      }
      daily_file="$2"
      shift 2
      ;;
    --calendar-report)
      [[ $# -ge 2 ]] || {
        usage
        exit 2
      }
      calendar_report="$2"
      shift 2
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

"${repo_root}/scripts/compile.sh"

if [[ "$skip_telegram" -ne 1 ]]; then
  if [[ "$dry_run" -eq 1 ]]; then
    "${repo_root}/scripts/send-post-compile-todo.sh" --dry-run
  else
    "${repo_root}/scripts/send-post-compile-todo.sh"
  fi
fi

calendar_args=()
if [[ -n "$daily_file" ]]; then
  calendar_args+=(--daily-file "$daily_file")
fi
if [[ -n "$calendar_report" ]]; then
  calendar_args+=(--report-file "$calendar_report")
fi

run_calendar_builder() {
  if [[ ${#calendar_args[@]} -gt 0 ]]; then
    "${repo_root}/scripts/build-calendar-candidates.sh" "${calendar_args[@]}" "$@"
  else
    "${repo_root}/scripts/build-calendar-candidates.sh" "$@"
  fi
}

run_calendar_builder

if [[ "$dry_run" -eq 1 ]]; then
  printf '\n[post-compile] calendar candidates\n'
  run_calendar_builder --stdout
fi
