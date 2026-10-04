#!/usr/bin/env bash
set -Eeuo pipefail
repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
if [[ $(uname -s) != Darwin ]]; then
  if command -v powershell.exe >/dev/null 2>&1 && command -v wslpath >/dev/null 2>&1; then
    powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass \
      -File "$(wslpath -w "$repo_dir/tests/wezterm-floating-tabs.ps1")"
    exit 0
  fi
  printf 'SKIPPED: native floating tabs require macOS or a Windows host\n'
  exit 77
fi
# shellcheck source=scripts/lib/wezterm.sh
source "$repo_dir/scripts/lib/wezterm.sh"
wezterm_command=$(find_wezterm_gui || true)
[[ -n "$wezterm_command" ]] || {
  printf 'UNAVAILABLE: wezterm-gui is missing\n'
  exit 78
}
fixture=$(mktemp -d "${TMPDIR:-/tmp}/floating-tabs-test.XXXXXX")
trap 'rm -rf "$fixture"' EXIT
for target in native windows windows-wsl; do
  fixture_home="$fixture/$target"
  mkdir -p "$fixture_home/Applications/WezTerm Floating Tabs.app/Contents/MacOS" \
    "$fixture_home/.local/share/dotfiles/wezterm-floating-tabs" \
    "$fixture_home/.local/state/dotfiles/wezterm-floating-tabs"
  touch "$fixture_home/Applications/WezTerm Floating Tabs.app/Contents/MacOS/wezterm-floating-tabs" \
    "$fixture_home/.local/share/dotfiles/wezterm-floating-tabs/wezterm-floating-tabs.exe"
  DOTFILES_FLOATING_TEST_HOME="$fixture_home" DOTFILES_FLOATING_TEST_TARGET="$target" "$wezterm_command" \
    --config-file "$repo_dir/tests/wezterm-floating-tabs-check.lua" show-keys >/dev/null
  if [[ ! -f "$fixture_home/bridge-result.txt" ]]; then
    printf 'WezTerm did not finish the %s bridge assertions\n' "$target" >&2
    exit 1
  fi
  if [[ $(cat "$fixture_home/bridge-result.txt") != passed ]]; then
    cat "$fixture_home/bridge-result.txt" >&2
    exit 1
  fi
done
xcrun swiftc -module-cache-path "$fixture/modules" "$repo_dir/wezterm/floating-tabs/main.swift" -o "$fixture/helper"
"$fixture/helper" --test "$repo_dir/tests/fixtures/floating-tabs.json"
printf 'Floating tab bridge passed\n'
if [[ ${1:-} == --e2e ]]; then
  python3 -B "$repo_dir/tests/wezterm-floating-tabs-e2e.py" --wezterm "$wezterm_command"
fi
