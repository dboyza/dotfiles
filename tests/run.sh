#!/usr/bin/env bash

set -Eeuo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

node --test "$repo_dir/tests/tool-updates.test.mjs"
"$repo_dir/tests/bootstrap-latest.sh"
"$repo_dir/tests/wsl-clipboard.sh"
"$repo_dir/tests/clipboard.sh"
"$repo_dir/tests/tmux-plugins.sh"
"$repo_dir/tests/compatibility.sh"
"$repo_dir/tests/nix-evaluation.sh"
"$repo_dir/tests/live-config.sh"
