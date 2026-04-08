#!/usr/bin/env bash
set -euo pipefail
set -f

usage() {
  echo "usage: scripts/check-windows-paths.sh [--tracked|--staged]" >&2
}

mode="${1:---tracked}"

case "$mode" in
  --tracked|--staged)
    ;;
  *)
    usage
    exit 2
    ;;
esac

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

has_error=0

report() {
  local kind="$1"
  local path="$2"
  local segment="$3"
  echo "windows-path-check: ${kind} -> ${path} (segment: ${segment})" >&2
  has_error=1
}

check_segment() {
  local path="$1"
  local segment="$2"
  local stem upper_stem

  if printf '%s' "$segment" | grep -Eq '[<>:"\\|?*]'; then
    report "invalid character" "$path" "$segment"
  fi

  if printf '%s' "$segment" | grep -Eq '[. ]$'; then
    report "trailing dot or space" "$path" "$segment"
  fi

  stem="${segment%%.*}"
  upper_stem="$(printf '%s' "$stem" | tr '[:lower:]' '[:upper:]')"

  case "$upper_stem" in
    CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])
      report "reserved Windows name" "$path" "$segment"
      ;;
  esac
}

run_check() {
  local path old_ifs segment

  while IFS= read -r -d '' path; do
    [[ -n "$path" ]] || continue

    old_ifs="$IFS"
    IFS='/'
    set -- $path
    IFS="$old_ifs"

    for segment in "$@"; do
      check_segment "$path" "$segment"
    done
  done
}

if [[ "$mode" == "--tracked" ]]; then
  run_check < <(git ls-files -z)
else
  run_check < <(git diff --cached --name-only --diff-filter=ACMR -z)
fi

if [[ "$has_error" -ne 0 ]]; then
  echo "windows-path-check: commit blocked. rename the path and update references first." >&2
  exit 1
fi
