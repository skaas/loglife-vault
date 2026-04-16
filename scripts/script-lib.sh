#!/usr/bin/env bash

run_python() {
  if command -v python3 >/dev/null 2>&1; then
    python3 "$@"
    return
  fi

  if command -v python >/dev/null 2>&1; then
    python "$@"
    return
  fi

  if command -v py >/dev/null 2>&1; then
    py -3 "$@"
    return
  fi

  echo "python runtime not found. Install Python 3 and expose python3, python, or py in PATH." >&2
  return 127
}
