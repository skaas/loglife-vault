#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"

if [[ -f "${repo_root}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${repo_root}/.env"
  set +a
fi

if [[ -f "${repo_root}/.env.local" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${repo_root}/.env.local"
  set +a
fi
