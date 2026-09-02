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
