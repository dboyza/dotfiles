#!/usr/bin/env bash

set -Eeuo pipefail

if ! command -v nix >/dev/null 2>&1; then
  printf 'Nix evaluation skipped because nix is unavailable\n'
  exit 0
fi

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export DOTFILES_REPO="$repo_dir"
export DOTFILES_USER=dotfiles-ci
export DOTFILES_HOME=/home/dotfiles-ci
export DOTFILES_WSL=0

nix_options=(--extra-experimental-features "nix-command flakes")
flake_ref="path:$repo_dir"
# shellcheck source=scripts/lib/bootstrap-common.sh
source "$repo_dir/scripts/lib/bootstrap-common.sh"

verify_tool_targets() {
  local tool
  for tool in codex pi opencode herdr dotfiles-tool.mjs; do
    managed_targets | grep -Fx "$HOME/.local/bin/$tool" >/dev/null
  done
}

os=Linux
for profile in linux-aarch64 linux-x86_64; do
  nix "${nix_options[@]}" eval --raw \
    "$flake_ref#homeConfigurations.$profile.activationPackage.drvPath" \
    --impure >/dev/null
  load_managed_targets
  verify_tool_targets
  managed_targets | grep -Fx "$HOME/.local/bin/dotfiles-clipboard" >/dev/null
done

os=Darwin
for profile in macos-aarch64 macos-x86_64; do
  nix "${nix_options[@]}" eval --raw \
    "$flake_ref#darwinConfigurations.$profile.system.drvPath" \
    --impure >/dev/null
  load_managed_targets
  for tool in codex pi opencode herdr dotfiles-tool.mjs; do
    if managed_targets | grep -Fx "$HOME/.local/bin/$tool" >/dev/null; then
      printf 'macOS must use Homebrew instead of the %s launcher\n' "$tool" >&2
      exit 1
    fi
  done
  brew_config=$(nix "${nix_options[@]}" eval --json \
    "$flake_ref#darwinConfigurations.$profile.config.homebrew" --impure \
    --apply 'h: { inherit (h) brews casks onActivation taps; }')
  printf '%s' "$brew_config" | python3 -c '
import json, sys
config = json.load(sys.stdin)
assert {"codex", "claude-code", "font-hack-nerd-font"} <= {x["name"] for x in config["casks"]}
assert {"pi-coding-agent", "herdr", "opencode", "mas", "neovim", "node"} <= {x["name"] for x in config["brews"]}
assert not config["onActivation"]["upgrade"]
assert any(t["name"] == "hashicorp/tap" and t["trusted"] for t in config["taps"])
'
  managed_targets | grep -Fx "$HOME/.config/nvim" >/dev/null
done

export DOTFILES_WSL=1
os=Linux
profile=linux-x86_64
nix "${nix_options[@]}" eval --raw \
  "$flake_ref#homeConfigurations.linux-x86_64.activationPackage.drvPath" \
  --impure >/dev/null
load_managed_targets
verify_tool_targets
managed_targets | grep -Fx "$HOME/.local/bin/win-copy" >/dev/null
managed_targets | grep -Fx "$HOME/.local/bin/win-paste" >/dev/null

printf 'All native and WSL Nix profiles evaluated successfully\n'
