#!/usr/bin/env bash

set -Eeuo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

"$repo_dir/tests/bootstrap-latest.sh"
"$repo_dir/tests/wsl-clipboard.sh"
"$repo_dir/tests/compatibility.sh"
"$repo_dir/tests/nix-evaluation.sh"
