#!/usr/bin/env bash

set -Eeuo pipefail
repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d /tmp/dotfiles-clipboard.XXXXXX)
cleanup() {
  if [[ -n ${tmux_command:-} ]]; then
    "$tmux_command" -S "$test_dir/tmux.sock" kill-server >/dev/null 2>&1 || true
  fi
  rm -rf "$test_dir"
}
trap cleanup EXIT
fake_bin="$test_dir/bin"
mkdir -p "$fake_bin"
for command in bash cat; do
  ln -s "$(command -v "$command")" "$fake_bin/$command"
done
for command in uname pbcopy pbpaste win-copy win-paste wl-copy wl-paste xclip xsel tmux; do
  ln -s "$repo_dir/tests/fixtures/clipboard-provider.sh" "$fake_bin/$command"
done
ln -s "$repo_dir/scripts/dotfiles-clipboard" "$fake_bin/dotfiles-clipboard"
export CLIPBOARD_TEST_FILE="$test_dir/clipboard" CLIPBOARD_TEST_LOG="$test_dir/log"
export CLIPBOARD_TEST_SYSTEM=Linux CLIPBOARD_TEST_KERNEL=generic
export WSL_DISTRO_NAME='' WSL_INTEROP='' WAYLAND_DISPLAY='' DISPLAY='' TMUX=''

round_trip() {
  local expected=$1
  : >"$CLIPBOARD_TEST_LOG"
  PATH="$fake_bin" dotfiles-clipboard --check
  test ! -s "$CLIPBOARD_TEST_LOG"
  for payload in 'héllo 🌙
second line without a trailing newline' '' $'trailing\n\n'; do
    printf '%s' "$payload" >"$test_dir/sample"
    PATH="$fake_bin" dotfiles-clipboard copy <"$test_dir/sample"
    PATH="$fake_bin" dotfiles-clipboard paste >"$test_dir/output"
    cmp "$test_dir/sample" "$test_dir/output"
  done
  [[ $(head -n 1 "$CLIPBOARD_TEST_LOG") == "$expected" ]]
}

export WSL_DISTRO_NAME=Ubuntu WAYLAND_DISPLAY=wayland-0 DISPLAY=:0 TMUX=fake
round_trip 'win-copy '
export WSL_DISTRO_NAME='' CLIPBOARD_TEST_KERNEL=6.6-microsoft-standard-WSL2
round_trip 'win-copy '
export CLIPBOARD_TEST_KERNEL=generic CLIPBOARD_TEST_SYSTEM=Darwin
round_trip 'pbcopy '
export CLIPBOARD_TEST_SYSTEM=Linux
round_trip 'wl-copy '
export WAYLAND_DISPLAY=
round_trip 'xclip -selection clipboard'
rm "$fake_bin/xclip"
round_trip 'xsel --clipboard --input'
export DISPLAY=
round_trip 'tmux load-buffer -'
export TMUX=
if PATH="$fake_bin" dotfiles-clipboard --check; then
  printf 'Clipboard probe accepted an unavailable session\n' >&2
  exit 1
fi

# Exercise Neovim's actual clipboard register API with the shared provider.
if command -v nvim >/dev/null 2>&1; then
  export WAYLAND_DISPLAY=wayland-0
  PATH="$fake_bin:$PATH" NVIM_LOG_FILE="$test_dir/nvim.log" \
    nvim --headless -u NONE -i NONE -l "$repo_dir/tests/nvim-clipboard.lua" "$repo_dir/nvim/lua/config/clipboard.lua"
fi

# Run the real Zsh selection widget with only the editor display calls stubbed.
if command -v zsh >/dev/null 2>&1; then
  mkdir -p "$test_dir/home"
  HOME="$test_dir/home" TERM=xterm-256color \
    zsh -dfc '
      source "$1/zsh/.zshrc"
      export PATH="$2"
      export WSL_DISTRO_NAME=Ubuntu
      zle() { :; }
      REGION_ACTIVE=1
      BUFFER="héllo 🌙"
      CUTBUFFER="$BUFFER"
      copy-selected-region
      [[ $REGION_ACTIVE == 0 && $CURSOR == ${#BUFFER} ]]
    ' zsh "$repo_dir" "$fake_bin"
  [[ $(cat "$CLIPBOARD_TEST_FILE") == 'héllo 🌙' ]]
fi

# Load the real tmux configuration and execute its configured clipboard commands.
tmux_command=$(command -v tmux || true)
if [[ -n $tmux_command ]]; then
  rm "$fake_bin/tmux"
  ln -s "$tmux_command" "$fake_bin/tmux"
  export WSL_DISTRO_NAME=Ubuntu
  mkdir -p "$test_dir/home/.local/bin"
  ln -s "$repo_dir/scripts/dotfiles-clipboard" "$test_dir/home/.local/bin/dotfiles-clipboard"
  # Plugin behavior is tested separately; keep clipboard reloads self-contained.
  for plugin in tmux-resurrect tmux-assistant-resurrect tmux-continuum; do
    mkdir -p "$test_dir/home/.tmux/plugins/$plugin"
    entrypoint=${plugin#tmux-}
    [[ $plugin != tmux-assistant-resurrect ]] || entrypoint=$plugin
    printf '#!/bin/sh\nexit 0\n' >"$test_dir/home/.tmux/plugins/$plugin/$entrypoint.tmux"
    chmod +x "$test_dir/home/.tmux/plugins/$plugin/$entrypoint.tmux"
  done
  HOME="$test_dir/home" PATH="$fake_bin:$PATH" "$tmux_command" -S "$test_dir/tmux.sock" -f "$repo_dir/tmux/.tmux.conf" \
    new-session -d "cat > '$test_dir/pane-output'; tmux wait-for -S pasted; cat"
  # Reload must clear the old text-only shortcut so apps receive image-paste keys.
  "$tmux_command" -S "$test_dir/tmux.sock" bind-key -n C-v run-shell 'legacy-text-paste'
  "$tmux_command" -S "$test_dir/tmux.sock" source-file "$repo_dir/tmux/.tmux.conf"
  if "$tmux_command" -S "$test_dir/tmux.sock" list-keys -T root C-v >/dev/null 2>&1; then
    printf 'tmux still intercepts Control+V after configuration reload\n' >&2
    exit 1
  fi
  printf 'héllo 🌙\nsecond line\n' >"$test_dir/sample"
  "$tmux_command" -S "$test_dir/tmux.sock" run-shell "cat '$test_dir/sample' | #{@clipboard_copy}"
  cmp "$test_dir/sample" "$CLIPBOARD_TEST_FILE"
  # Execute the actual configured paste binding's shell command.
  paste_binding=$("$tmux_command" -S "$test_dir/tmux.sock" list-keys -T root S-C-v)
  [[ $paste_binding == *'/.local/bin/dotfiles-clipboard'*'paste-to-tmux'* ]]
  # Expand HOME inside the isolated tmux server's environment.
  # shellcheck disable=SC2016
  "$tmux_command" -S "$test_dir/tmux.sock" run-shell '"$HOME/.local/bin/dotfiles-clipboard" paste-to-tmux #{pane_id}'
  "$tmux_command" -S "$test_dir/tmux.sock" save-buffer "$test_dir/output"
  cmp "$test_dir/sample" "$test_dir/output"
  "$tmux_command" -S "$test_dir/tmux.sock" send-keys C-d
  "$tmux_command" -S "$test_dir/tmux.sock" wait-for pasted
  cmp "$test_dir/sample" "$test_dir/pane-output"
  if PATH="$fake_bin:$PATH" CLIPBOARD_TEST_FAIL_PASTE=1 \
    TMUX="$test_dir/tmux.sock,0,0" dotfiles-clipboard paste-to-tmux %0; then
    printf 'tmux paste ignored a clipboard provider failure\n' >&2
    exit 1
  fi
  "$tmux_command" -S "$test_dir/tmux.sock" save-buffer "$test_dir/output"
  cmp "$test_dir/sample" "$test_dir/output"
  : >"$CLIPBOARD_TEST_FILE"
  # An empty clipboard is a successful no-op, even with no valid target pane.
  PATH="$fake_bin:$PATH" TMUX="$test_dir/tmux.sock,0,0" dotfiles-clipboard paste-to-tmux %9999
  "$tmux_command" -S "$test_dir/tmux.sock" list-keys -T copy-mode-vi y | grep -q 'copy-pipe-and-cancel'
fi
printf 'Shared clipboard selection and UTF-8 round trips passed\n'
