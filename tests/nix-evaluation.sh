#!/usr/bin/env bash

set -Eeuo pipefail

if ! command -v nix >/dev/null 2>&1; then
  printf 'Nix evaluation skipped because nix is unavailable\n'
  exit 0
fi

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export DOTFILES_USER=dotfiles-ci
export DOTFILES_HOME=/home/dotfiles-ci
export DOTFILES_WSL=0

nix_options=(--extra-experimental-features "nix-command flakes")
flake_ref="path:$repo_dir"

for profile in linux-aarch64 linux-x86_64; do
  nix "${nix_options[@]}" eval --raw \
    "$flake_ref#homeConfigurations.$profile.activationPackage.drvPath" \
    --impure >/dev/null
done

for profile in macos-aarch64 macos-x86_64; do
  nix "${nix_options[@]}" eval --raw \
    "$flake_ref#darwinConfigurations.$profile.system.drvPath" \
    --impure >/dev/null
done

export DOTFILES_WSL=1
nix "${nix_options[@]}" eval --raw \
  "$flake_ref#homeConfigurations.linux-x86_64.activationPackage.drvPath" \
  --impure >/dev/null

printf 'All native and WSL Nix profiles evaluated successfully\n'
