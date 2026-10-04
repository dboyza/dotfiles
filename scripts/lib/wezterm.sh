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
