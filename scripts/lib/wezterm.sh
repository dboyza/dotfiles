#!/usr/bin/env bash

find_wezterm() {
  if command -v wezterm >/dev/null 2>&1; then
    command -v wezterm
  elif [[ -x /Applications/WezTerm.app/Contents/MacOS/wezterm ]]; then
    printf '%s\n' /Applications/WezTerm.app/Contents/MacOS/wezterm
  else
    return 1
  fi
}

# macOS's CLI delegates GUI/configuration commands without waiting for them.
# Tests need the foreground executable so assertions finish before cleanup.
find_wezterm_gui() {
  if command -v wezterm-gui >/dev/null 2>&1; then
    command -v wezterm-gui
  elif [[ -x /Applications/WezTerm.app/Contents/MacOS/wezterm-gui ]]; then
    printf '%s\n' /Applications/WezTerm.app/Contents/MacOS/wezterm-gui
  else
    return 1
  fi
}

# Run the foreground executable and require an explicit Lua completion verdict.
# stdout remains available for callers that inspect the effective key table.
check_wezterm_config() (
  local source=$1 executable check_dir library_dir
  library_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  executable=$(find_wezterm_gui) || return 1
  check_dir=$(mktemp -d "${TMPDIR:-/tmp}/wezterm-check.XXXXXX")
  trap 'rm -rf "$check_dir"' EXIT
  DOTFILES_WEZTERM_CHECK_SOURCE="$source" DOTFILES_WEZTERM_CHECK_RESULT="$check_dir/result" \
    "$executable" --config-file "$library_dir/check-wezterm.lua" show-keys || return 1
  if [[ ! -f "$check_dir/result" ]]; then
    printf 'WezTerm did not finish loading %s\n' "$source" >&2
    return 1
  fi
  if [[ $(cat "$check_dir/result") != passed ]]; then
    cat "$check_dir/result" >&2
    return 1
  fi
)
