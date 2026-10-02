#!/usr/bin/env bash
set -Eeuo pipefail
repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
if [[ $(uname -s) != Darwin ]]; then
  if command -v powershell.exe >/dev/null 2>&1 && command -v wslpath >/dev/null 2>&1; then
    powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass \
      -File "$(wslpath -w "$repo_dir/tests/wezterm-floating-tabs.ps1")"
  fi
  exit 0
fi
# shellcheck source=scripts/lib/wezterm.sh
source "$repo_dir/scripts/lib/wezterm.sh"
wezterm_command=$(find_wezterm || true)
[[ -n "$wezterm_command" ]] || exit 0
fixture=$(mktemp -d "${TMPDIR:-/tmp}/floating-tabs-test.XXXXXX")
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/home/Applications/WezTerm Floating Tabs.app/Contents/MacOS" \
  "$fixture/home/.local/state/dotfiles/wezterm-floating-tabs"
touch "$fixture/home/Applications/WezTerm Floating Tabs.app/Contents/MacOS/wezterm-floating-tabs"
DOTFILES_FLOATING_TEST_HOME="$fixture/home" "$wezterm_command" \
  --config-file "$repo_dir/tests/wezterm-floating-tabs.lua" show-keys >/dev/null
xcrun swiftc -module-cache-path "$fixture/modules" "$repo_dir/wezterm/floating-tabs/main.swift" -o "$fixture/helper"
"$fixture/helper" --test
printf 'Floating tab bridge passed\n'
