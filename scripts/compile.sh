#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: scripts/compile.sh [--stdout-today] [--today-file PATH] [--todo-file PATH] [--skip-todo-writing-topic] [--skip-pull] [--dry-run] [--skip-telegram] [--skip-calendar] [--daily-file PATH] [--calendar-report PATH]" >&2
}

repo_root="$(git rev-parse --show-toplevel)"
today_args=()
pull_enabled=1
dry_run=0
skip_telegram=0
skip_calendar=0
daily_file=""
calendar_report=""
todo_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stdout-today)
      today_args+=(--stdout)
      shift
      ;;
    --today-file)
      [[ $# -ge 2 ]] || {
        usage
        exit 2
      }
      today_args+=("$1" "$2")
      shift 2
      ;;
    --todo-file)
      [[ $# -ge 2 ]] || {
        usage
        exit 2
      }
      todo_file="$2"
      today_args+=("$1" "$2")
      shift 2
      ;;
    --skip-todo-writing-topic)
      today_args+=("$1")
      shift
      ;;
    --skip-pull)
      pull_enabled=0
      shift
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    --skip-telegram)
      skip_telegram=1
      shift
      ;;
    --skip-calendar)
      skip_calendar=1
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

if [[ -z "$todo_file" ]]; then
  todo_file="${repo_root}/Wiki/Self/TODO.md"
fi

pull_latest() {
  local upstream=""
  local current_branch=""

  upstream="$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || true)"
  current_branch="$(git branch --show-current)"

  if [[ -n "$upstream" ]]; then
    git pull --rebase --autostash
    return
  fi

  if [[ -n "$current_branch" ]]; then
    git pull --rebase --autostash origin "$current_branch"
    return
  fi

  echo "compile: unable to determine branch/upstream for pull" >&2
  exit 1
}

run_today_compile() {
  if [[ ${#today_args[@]} -gt 0 ]]; then
    "${repo_root}/scripts/compile-today-focus.sh" "${today_args[@]}"
  else
    "${repo_root}/scripts/compile-today-focus.sh"
  fi
}

run_calendar_compile() {
  local calendar_args=()
  if [[ -n "$daily_file" ]]; then
    calendar_args+=(--daily-file "$daily_file")
  fi
  if [[ -n "$calendar_report" ]]; then
    calendar_args+=(--report-file "$calendar_report")
  fi

  if [[ ${#calendar_args[@]} -gt 0 ]]; then
    "${repo_root}/scripts/build-calendar-candidates.sh" "${calendar_args[@]}" "$@"
  else
    "${repo_root}/scripts/build-calendar-candidates.sh" "$@"
  fi
}

if [[ "$pull_enabled" -eq 1 ]]; then
  pull_latest
fi

"${repo_root}/scripts/compile-wiki-state.sh"
"${repo_root}/scripts/compile-todo-state.sh" --todo-file "$todo_file"
run_today_compile

if [[ "$skip_calendar" -ne 1 ]]; then
  run_calendar_compile
  if [[ "$dry_run" -eq 1 ]]; then
    printf '\n[compile] calendar candidates\n'
    run_calendar_compile --stdout
  fi
fi

"${repo_root}/scripts/build-review-state.sh"

if [[ "$skip_telegram" -ne 1 ]]; then
  if [[ "$dry_run" -eq 1 ]]; then
    "${repo_root}/scripts/send-post-compile-todo.sh" --dry-run --todo-file "$todo_file"
    printf '\n[compile] next review\n'
    "${repo_root}/scripts/send-next-review.sh" --stdout
  else
    "${repo_root}/scripts/send-post-compile-todo.sh" --todo-file "$todo_file"
    "${repo_root}/scripts/send-next-review.sh"
    "${repo_root}/scripts/build-review-state.sh"
  fi
fi
