#!/usr/bin/env bash

set -Eeuo pipefail

usage() {
  cat <<'EOF'
Usage: ./bootstrap.sh [--check | --update]

  --check  Evaluate and build the pinned configuration without updating or activating it.
  --update Update, check, and activate the configuration (the default behavior).
EOF
}

check_only=false
case "${1:-}" in
  "") ;;
  --check) check_only=true ;;
  --update) ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

unset CDPATH
repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
if [[ ! -f "$repo_dir/flake.nix" ]]; then
  printf 'bootstrap: flake.nix was not found next to this script\n' >&2
  exit 1
fi

if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
  printf 'bootstrap: run this script as your normal user, not root\n' >&2
  exit 1
fi

os=$(uname -s)
architecture=$(uname -m)
case "$architecture" in
  arm64|aarch64) nix_architecture=aarch64 ;;
  x86_64|amd64) nix_architecture=x86_64 ;;
  *)
    printf 'bootstrap: unsupported architecture: %s\n' "$architecture" >&2
    exit 1
    ;;
esac

case "$os" in
  Darwin) profile="macos-$nix_architecture" ;;
  Linux) profile="linux-$nix_architecture" ;;
  *)
    printf 'bootstrap: supported operating systems are Linux and macOS\n' >&2
    exit 1
    ;;
esac

export DOTFILES_USER=${USER:-$(id -un)}
export DOTFILES_HOME=$HOME
export DOTFILES_WSL=0
if [[ "$os" == Linux ]] && grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; then
  export DOTFILES_WSL=1
fi

load_nix() {
  if command -v nix >/dev/null 2>&1; then
    return
  fi

  local profile_script
  for profile_script in \
    /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh \
    "$HOME/.nix-profile/etc/profile.d/nix.sh"
  do
    if [[ -r "$profile_script" ]]; then
      # shellcheck disable=SC1090
      source "$profile_script"
    fi
  done
}

install_nix() {
  load_nix
  if command -v nix >/dev/null 2>&1; then
    return
  fi

  if ! command -v curl >/dev/null 2>&1 && command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl
  fi
  if ! command -v curl >/dev/null 2>&1; then
    printf 'bootstrap: curl is required to install Nix\n' >&2
    exit 1
  fi

  local installer
  installer=$(mktemp "${TMPDIR:-/tmp}/nix-install.XXXXXX")
  curl --proto '=https' --tlsv1.2 -fsSL https://nixos.org/nix/install -o "$installer"

  if [[ "$os" == Darwin ]]; then
    sh "$installer" --daemon
  elif [[ $(ps -p 1 -o comm= 2>/dev/null) == systemd ]]; then
    sh "$installer" --daemon
  else
    sh "$installer" --no-daemon
  fi
  rm -f "$installer"

  load_nix
  if ! command -v nix >/dev/null 2>&1; then
    printf 'bootstrap: Nix installed but is not available in this shell; open a new shell and rerun this script\n' >&2
    exit 1
  fi
}

install_homebrew() {
  [[ "$os" == Darwin ]] || return 0
  if command -v brew >/dev/null 2>&1; then
    return
  fi

  local installer
  installer=$(mktemp "${TMPDIR:-/tmp}/homebrew-install.XXXXXX")
  curl --proto '=https' --tlsv1.2 -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$installer"
  NONINTERACTIVE=1 /bin/bash "$installer"
  rm -f "$installer"

  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

backup_managed_files() {
  local stamp target link_target
  stamp=$(date +%Y%m%d%H%M%S)

  while IFS= read -r target; do
    [[ -e "$target" || -L "$target" ]] || continue

    if [[ -L "$target" ]]; then
      link_target=$(readlink "$target" 2>/dev/null || true)
      case "$link_target" in
        "$repo_dir"/*|/nix/store/*) continue ;;
      esac
    fi

    mv "$target" "$target.backup.$stamp"
    printf 'Backed up %s\n' "$target"
  done <<EOF
$HOME/.zshrc
$HOME/.zshenv
$HOME/.tmux.conf
$HOME/.wezterm.lua
$HOME/.config/herdr/config.toml
$HOME/.config/nvim
$HOME/.config/starship.toml
$HOME/.codex/AGENTS.md
$HOME/.claude/CLAUDE.md
$HOME/.config/opencode/AGENTS.md
$HOME/.pi/agent/AGENTS.md
$HOME/.agents/skills
$HOME/.pi/agent/extensions
$HOME/.pi/agent/prompts
$HOME/.pi/agent/themes
$HOME/.tmux/plugins/tpm
$HOME/.tmux/plugins/tmux-yank
$HOME/.tmux/plugins/tmux-resurrect
$HOME/.tmux/plugins/tmux-continuum
$HOME/.tmux/plugins/tmux-assistant-resurrect
$HOME/.local/bin/win-copy
$HOME/.local/bin/win-paste
EOF
}

install_windows_fonts() {
  [[ "$DOTFILES_WSL" == 1 ]] || return 0
  command -v powershell.exe >/dev/null 2>&1 || return 0
  command -v wslpath >/dev/null 2>&1 || return 0

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
  if ! command -v powershell.exe >/dev/null 2>&1 || ! command -v wslpath >/dev/null 2>&1; then
    printf 'bootstrap: WSL interoperability is required to configure Windows WezTerm\n' >&2
    return 1
  fi

  local config_source script_source
  config_source=$(wslpath -w "$repo_dir/wezterm/.wezterm.lua")
  script_source=$(wslpath -w "$repo_dir/scripts/install-windows-wezterm.ps1")
  powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass \
    -File "$script_source" -Source "$config_source"
}

configure_linux_shell() {
  [[ "$os" == Linux ]] || return 0
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

verify_installation() {
  local command_name missing=0
  local expected_commands=(claude codex git herdr kubectl nvim node pi pre-commit rg starship terraform tmux uv zsh)
  export PATH="$HOME/.nix-profile/bin:/etc/profiles/per-user/$DOTFILES_USER/bin:/run/current-system/sw/bin:$PATH"

  if [[ "$profile" != macos-x86_64 ]]; then
    expected_commands+=(opencode)
  fi

  for command_name in "${expected_commands[@]}"; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
      printf 'bootstrap: expected command is missing: %s\n' "$command_name" >&2
      missing=1
    fi
  done

  if (( missing )); then
    return 1
  fi
}

install_nix
nix_options=(--extra-experimental-features "nix-command flakes")
flake_ref="path:$repo_dir"

if ! $check_only; then
  printf 'Updating Nix packages and plugin inputs to their latest declared versions...\n'
  nix "${nix_options[@]}" flake update --flake "$flake_ref"
fi

printf 'Checking %s configuration...\n' "$profile"
nix "${nix_options[@]}" flake check "$flake_ref" --impure

if $check_only; then
  if [[ "$os" == Darwin ]]; then
    nix "${nix_options[@]}" build \
      "$flake_ref#darwinConfigurations.$profile.system" \
      --impure \
      --no-link
  else
    nix "${nix_options[@]}" build \
      "$flake_ref#homeConfigurations.$profile.activationPackage" \
      --impure \
      --no-link
  fi
  printf 'Configuration check passed for %s.\n' "$profile"
  exit 0
fi

backup_managed_files

if [[ "$os" == Darwin ]]; then
  install_homebrew
  sudo env \
    "DOTFILES_USER=$DOTFILES_USER" \
    "DOTFILES_HOME=$DOTFILES_HOME" \
    "DOTFILES_WSL=$DOTFILES_WSL" \
    "PATH=$PATH" \
    nix "${nix_options[@]}" run "$flake_ref#darwin-rebuild" -- \
      switch --flake "$flake_ref#$profile" --impure
else
  generation=$(nix "${nix_options[@]}" build \
    "$flake_ref#homeConfigurations.$profile.activationPackage" \
    --impure \
    --no-link \
    --print-out-paths)
  "$generation/activate"
  configure_linux_shell
  install_windows_fonts
  install_windows_wezterm
fi

verify_installation
printf 'Bootstrap complete. Open a new terminal to use the configured environment.\n'
