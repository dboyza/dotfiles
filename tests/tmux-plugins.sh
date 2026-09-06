#!/usr/bin/env bash

set -Eeuo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
if ! command -v tmux >/dev/null 2>&1; then
  printf 'tmux plugin test skipped: tmux is not installed\n'
  exit 0
fi

plugins=(tmux-resurrect tmux-assistant-resurrect tmux-continuum)
for plugin in "${plugins[@]}"; do
  if [[ ! -d "$HOME/.tmux/plugins/$plugin" ]]; then
    printf 'tmux plugin test skipped: %s is not installed\n' "$plugin"
    exit 0
  fi
done

test_dir=$(mktemp -d /tmp/dotfiles-tmux-plugins.XXXXXX)
test_home="$test_dir/home"
socket_name=dotfiles-plugins
cleanup() {
  TMUX_TMPDIR="$test_dir" tmux -L "$socket_name" kill-server >/dev/null 2>&1 || true
  rm -rf "$test_dir"
}
trap cleanup EXIT
mkdir -p "$test_home/.tmux/plugins"
for plugin in "${plugins[@]}"; do
  ln -s "$HOME/.tmux/plugins/$plugin" "$test_home/.tmux/plugins/$plugin"
done

# The plugins install assistant hooks and maintain restoration state in HOME.
# Keep all of that isolated from the user's settings and running tmux server.
startup_output=$(HOME="$test_home" TMUX_TMPDIR="$test_dir" tmux -L "$socket_name" \
  -f "$repo_dir/tmux/.tmux.conf" new-session -d -s plugin-test 2>&1)
if [[ -n "$startup_output" ]]; then
  printf 'tmux startup produced errors: %s\n' "$startup_output" >&2
  exit 1
fi
test_tmux() {
  TMUX_TMPDIR="$test_dir" tmux -L "$socket_name" "$@"
}

# source-file waits for the synchronous run-shell commands, including on reload.
test_tmux bind-key I run-shell "$test_home/.tmux/plugins/tpm/bindings/install_plugins"
test_tmux bind-key U run-shell "$test_home/.tmux/plugins/tpm/bindings/update_plugins"
test_tmux bind-key M-u run-shell "$test_home/.tmux/plugins/tpm/bindings/clean_plugins"
reload_output=$(test_tmux source-file "$repo_dir/tmux/.tmux.conf" 2>&1)
if [[ -n "$reload_output" ]]; then
  printf 'tmux reload produced errors: %s\n' "$reload_output" >&2
  exit 1
fi
[[ $(test_tmux show-options -gv prefix) == C-g ]]
[[ $(test_tmux show-options -gv @continuum-restore) == on ]]
[[ $(test_tmux show-options -gv @continuum-save-interval) == 5 ]]
[[ $(test_tmux show-options -gv @resurrect-hook-post-save-all) == *save-assistant-sessions.sh* ]]
[[ $(test_tmux show-options -gv @resurrect-hook-post-restore-all) == *restore-assistant-sessions.sh* ]]
test_tmux list-keys -T prefix C-s | grep -F '/tmux-resurrect/scripts/save.sh' >/dev/null
test_tmux list-keys -T prefix C-r | grep -F '/tmux-resurrect/scripts/restore.sh' >/dev/null
if test_tmux list-keys -T prefix | grep -F '/tpm/' >/dev/null; then
  printf 'tmux plugin test: TPM bindings remain\n' >&2
  exit 1
fi
# Keep user replacements of the former TPM shortcuts when reloading.
test_tmux bind-key I display-message 'custom install shortcut'
test_tmux bind-key U display-message 'custom update shortcut'
test_tmux bind-key M-u display-message 'custom cleanup shortcut'
test_tmux source-file "$repo_dir/tmux/.tmux.conf"
for key in I U M-u; do
  test_tmux list-keys -T prefix "$key" | grep -F 'display-message' >/dev/null
done
[[ -L "$test_home/.config/opencode/plugins/session-tracker.js" ]]
if command -v jq >/dev/null 2>&1; then
  jq -e '.hooks.SessionStart | length == 1' "$test_home/.claude/settings.json" >/dev/null
fi
printf 'tmux direct plugin initialization and reload passed\n'
