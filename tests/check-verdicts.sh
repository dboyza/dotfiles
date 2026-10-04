#!/usr/bin/env bash
# Prove Lua failures fail verification and both old and new configuration loaders resolve correctly.
set -Eeuo pipefail
repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/lib/wezterm.sh
source "$repo_dir/scripts/lib/wezterm.sh"
# Section: Invalid and valid configuration fixtures
fixture=$(mktemp -d "${TMPDIR:-/tmp}/check-verdicts.XXXXXX")
trap 'rm -rf "$fixture"' EXIT
printf "error('intentional runtime failure')\n" >"$fixture/fail.lua"
printf 'this is not Lua\n' >"$fixture/syntax.lua"
printf 'return {}\n' >"$fixture/pass.lua"
printf "return {font_size = 'invalid'}\n" >"$fixture/option.lua"
printf 'return {unknown_option = true}\n' >"$fixture/unknown.lua"
# Section: Neovim process verdicts
if command -v nvim >/dev/null 2>&1; then
  for test in fail syntax; do
    if NVIM_LOG_FILE="$fixture/nvim.log" nvim --headless -u NONE -i NONE -l "$repo_dir/tests/run-lua.lua" "$fixture/$test.lua" >"$fixture/output" 2>&1; then
      printf 'Neovim reported success for %s\n' "$test" >&2
      exit 1
    fi
  done
  NVIM_LOG_FILE="$fixture/nvim.log" nvim --headless -u NONE -i NONE -l "$repo_dir/tests/run-lua.lua" "$fixture/pass.lua"
else
  printf 'UNAVAILABLE: Neovim verdict checks require nvim\n'
fi
# Section: WezTerm options and loader compatibility
if find_wezterm_gui >/dev/null; then
  for test in fail syntax option unknown; do
    if check_wezterm_config "$fixture/$test.lua" >"$fixture/output" 2>&1; then
      printf 'WezTerm reported success for %s\n' "$test" >&2
      exit 1
    fi
  done
  check_wezterm_config "$fixture/pass.lua" >/dev/null
  cp -R "$repo_dir/wezterm" "$fixture/checkout with spaces"
  mkdir -p "$fixture/home" "$fixture/links"
  ln -s "../checkout with spaces/.wezterm.lua" "$fixture/links/config.lua"
  ln -s "../links/config.lua" "$fixture/home/.wezterm.lua"
  DOTFILES_LOADER_FIXTURE="$fixture" check_wezterm_config "$repo_dir/tests/wezterm-loader.lua" >/dev/null
else
  printf 'UNAVAILABLE: WezTerm verdict checks require wezterm-gui\n'
fi
