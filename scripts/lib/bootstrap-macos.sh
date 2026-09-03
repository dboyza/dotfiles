#!/usr/bin/env bash

# shellcheck disable=SC2154
# macOS bootstrap functions. This file is sourced by bootstrap.sh.

preflight_platform_installation() {
  local xcode_select=${BOOTSTRAP_XCODE_SELECT:-xcode-select}
  if ! command -v "$xcode_select" >/dev/null 2>&1 || ! "$xcode_select" -p >/dev/null 2>&1; then
    printf 'bootstrap: Apple Command Line Tools are required before macOS activation\n' >&2
    printf 'bootstrap: run xcode-select --install, finish the Apple installer, then rerun ./bootstrap.sh\n' >&2
    return 1
  fi
  printf '  Apple Command Line Tools: installed\n'

  if command -v brew >/dev/null 2>&1; then
    printf '  Homebrew: installed; configured packages will be updated\n'
  else
    printf '  Homebrew: will be installed\n'
  fi
}

install_homebrew() {
  if command -v brew >/dev/null 2>&1; then
    return
  fi

  local installer
  installer=$(mktemp "${TMPDIR:-/tmp}/homebrew-install.XXXXXX")
  curl --proto '=https' --tlsv1.2 -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$installer"
  env -u NONINTERACTIVE /bin/bash "$installer"
  rm -f "$installer"

  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

backup_darwin_shell_files() {
  local backup counter link_target name stamp target
  local etc_dir=${BOOTSTRAP_DARWIN_ETC_DIR:-/etc}
  stamp=$(date +%Y%m%d%H%M%S)

  for name in bashrc zshrc; do
    target="$etc_dir/$name"
    [[ -e "$target" || -L "$target" ]] || continue

    link_target=
    if [[ -L "$target" ]]; then
      link_target=$(readlink "$target" 2>/dev/null || true)
    fi
    if [[ "$link_target" == "$etc_dir/static/$name" ]]; then
      continue
    fi

    backup="$target.before-nix-darwin"
    if [[ -e "$backup" || -L "$backup" ]]; then
      backup="$backup.$stamp"
      counter=1
      while [[ -e "$backup" || -L "$backup" ]]; do
        backup="$target.before-nix-darwin.$stamp.$counter"
        ((counter += 1))
      done
    fi

    sudo mv "$target" "$backup"
    printf 'Backed up %s to %s\n' "$target" "$backup"
  done
}

verify_platform() {
  local enabled plist plistbuddy shortcut
  plist="$HOME/Library/Preferences/com.apple.symbolichotkeys.plist"
  plistbuddy=${BOOTSTRAP_PLISTBUDDY:-/usr/libexec/PlistBuddy}
  for shortcut in 32 33 79 80 81 82; do
    enabled=$("$plistbuddy" -c "Print :AppleSymbolicHotKeys:${shortcut}:enabled" "$plist" 2>/dev/null || true)
    if [[ "$enabled" != false ]]; then
      printf 'bootstrap: macOS symbolic hotkey %s is not disabled\n' "$shortcut" >&2
      return 1
    fi
  done
}

activate_platform() {
  install_homebrew
  backup_darwin_shell_files
  sudo env \
    "DOTFILES_USER=$DOTFILES_USER" \
    "DOTFILES_HOME=$DOTFILES_HOME" \
    "DOTFILES_WSL=$DOTFILES_WSL" \
    "PATH=$PATH" \
    nix "${nix_options[@]}" run "$flake_ref#darwin-rebuild" -- \
    switch --flake "$flake_ref#$profile" --impure
}
