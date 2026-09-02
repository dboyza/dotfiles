#!/usr/bin/env bash

# shellcheck disable=SC2154
# Linux and WSL bootstrap functions. This file is sourced by bootstrap.sh.

preflight_platform_installation() {
  if [[ "$DOTFILES_WSL" != 1 ]]; then
    printf '  Platform integration: native Linux\n'
    return
  fi

  if ! command -v powershell.exe >/dev/null 2>&1 || ! command -v wslpath >/dev/null 2>&1; then
    printf 'bootstrap: WSL interoperability is required to configure Windows WezTerm and fonts\n' >&2
    return 1
  fi
  printf '  Platform integration: Windows interoperability available\n'
}

install_windows_fonts() {
  [[ "$DOTFILES_WSL" == 1 ]] || return 0

  local font_store font_source script_source
  font_store=$(nix "${nix_options[@]}" build \
    "$flake_ref#hack-font" \
    --impure \
    --no-link \
    --print-out-paths)
  font_source=$(wslpath -w "$font_store/share/fonts")
  script_source=$(wslpath -w "$repo_dir/scripts/install-windows-fonts.ps1")
  powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass \
    -File "$script_source" -Source "$font_source"
}

install_windows_wezterm() {
  [[ "$DOTFILES_WSL" == 1 ]] || return 0

  local config_source script_source
  config_source=$(wslpath -w "$repo_dir/wezterm/.wezterm.lua")
  script_source=$(wslpath -w "$repo_dir/scripts/install-windows-wezterm.ps1")
  powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass \
    -File "$script_source" -Source "$config_source"
}

configure_linux_shell() {
  command -v apt-get >/dev/null 2>&1 || return 0

  if [[ ! -x /usr/bin/zsh ]]; then
    sudo apt-get update
    sudo apt-get install -y zsh
  fi

  local current_shell
  current_shell=$(getent passwd "$DOTFILES_USER" | cut -d: -f7)
  if [[ "$current_shell" != /usr/bin/zsh ]]; then
    sudo usermod --shell /usr/bin/zsh "$DOTFILES_USER"
  fi
}

verify_platform() {
  return 0
}

activate_platform() {
  local generation
  generation=$(nix "${nix_options[@]}" build \
    "$flake_ref#homeConfigurations.$profile.activationPackage" \
    --impure \
    --no-link \
    --print-out-paths)
  "$generation/activate"
  configure_linux_shell
  install_windows_fonts
  install_windows_wezterm
}
