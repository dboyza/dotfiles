#!/usr/bin/env bash

set -Eeuo pipefail

if ! command -v nix >/dev/null 2>&1; then
  printf 'Live configuration test skipped because nix is unavailable\n'
  exit 0
fi

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-live-config.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT

# Exercise a real Home Manager out-of-store link with a checkout path containing spaces.
export DOTFILES_REPO="$test_dir/live checkout"
export DOTFILES_USER=dotfiles-ci
export DOTFILES_HOME="$test_dir/home"
export DOTFILES_WSL=0
mkdir -p "$DOTFILES_REPO/zsh" "$DOTFILES_HOME"
printf 'print first\n' >"$DOTFILES_REPO/zsh/.zshrc"

case $(uname -m) in
  arm64 | aarch64) architecture=aarch64 ;;
  *) architecture=x86_64 ;;
esac
case $(uname -s) in
  Darwin) attribute="darwinConfigurations.macos-$architecture.config.home-manager.users.$DOTFILES_USER" ;;
  *) attribute="homeConfigurations.linux-$architecture.config" ;;
esac

source_link=$(nix --extra-experimental-features 'nix-command flakes' build \
  "path:$repo_dir#$attribute.home.file.\".zshrc\".source" \
  --impure --no-link --print-out-paths)
ln -s "$source_link" "$DOTFILES_HOME/.zshrc"
test "$(zsh -f "$DOTFILES_HOME/.zshrc")" = first

# Save by replacement, as editors do. The already-built link must see the new file.
printf 'print second\n' >"$DOTFILES_REPO/zsh/.zshrc.new"
mv "$DOTFILES_REPO/zsh/.zshrc.new" "$DOTFILES_REPO/zsh/.zshrc"
test "$(zsh -f "$DOTFILES_HOME/.zshrc")" = second
printf 'Live configuration edits work without rebuilding or relinking\n'
