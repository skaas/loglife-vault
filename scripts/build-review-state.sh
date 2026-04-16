#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck disable=SC1091
source "${repo_root}/scripts/script-lib.sh"

run_python "${repo_root}/scripts/review_queue.py" build "$@"
