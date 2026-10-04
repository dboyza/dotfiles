#!/usr/bin/env bash
# Run local verification from any directory, forwarding selection and strictness options.
set -Eeuo pipefail
repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
exec python3 -B "$repo_dir/tests/run.py" "$@"
