#!/usr/bin/env bash
set -Eeuo pipefail
repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
exec python3 -B "$repo_dir/tests/run.py" "$@"
