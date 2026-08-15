#!/usr/bin/env bash

set -Eeuo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-compatibility.XXXXXX")
cleanup() {
  local status=$?
  if [[ -n "${tmux_tmp:-}" ]]; then
    TMUX_TMPDIR="$tmux_tmp" tmux -L "${socket_name:-dotfiles-test}" kill-server >/dev/null 2>&1 || true
    rm -rf "$tmux_tmp"
  fi
  rm -rf "$test_dir"
  exit "$status"
}
trap cleanup EXIT

while IFS= read -r script; do
  bash -n "$repo_dir/$script"
done < <(cd "$repo_dir" && rg --files -g '*.sh' -g 'bootstrap.sh')

if command -v shellcheck >/dev/null 2>&1; then
  cd "$repo_dir"
  shell_scripts=()
  while IFS= read -r script; do
    shell_scripts+=("$script")
  done < <(rg --files -g '*.sh' -g 'bootstrap.sh')
  shellcheck "${shell_scripts[@]}"
fi

if command -v shfmt >/dev/null 2>&1; then
  cd "$repo_dir"
  shell_scripts=()
  while IFS= read -r script; do
    shell_scripts+=("$script")
  done < <(rg --files -g '*.sh' -g 'bootstrap.sh')
  shfmt -d -i 2 -ci "${shell_scripts[@]}"
fi

if command -v jq >/dev/null 2>&1; then
  while IFS= read -r json_file; do
    jq empty "$repo_dir/$json_file"
  done < <(cd "$repo_dir" && rg --files -g '*.json')
fi

wezterm_command=
if command -v wezterm >/dev/null 2>&1; then
  wezterm_command=$(command -v wezterm)
elif [[ -x /Applications/WezTerm.app/Contents/MacOS/wezterm ]]; then
  wezterm_command=/Applications/WezTerm.app/Contents/MacOS/wezterm
fi

if [[ -n "$wezterm_command" ]]; then
  keys="$test_dir/wezterm-keys"
  "$wezterm_command" --config-file "$repo_dir/wezterm/.wezterm.lua" show-keys >"$keys"
  for direction in Left Right Up Down; do
    if ! grep -E "^[[:space:]]*CTRL[[:space:]]+${direction}Arrow[[:space:]]+->[[:space:]]+SendKey.*mods: CTRL" "$keys" >/dev/null; then
      printf 'compatibility test: WezTerm does not pass Control+%s through unchanged\n' "$direction" >&2
      exit 1
    fi
  done
fi

if command -v tmux >/dev/null 2>&1; then
  tmux_tmp=$(mktemp -d /tmp/dotfiles-tmux-test.XXXXXX)
  socket_name="dotfiles-test-$$"
  TMUX_TMPDIR="$tmux_tmp" tmux -L "$socket_name" -f "$repo_dir/tmux/.tmux.conf" new-session -d
  if [[ $(TMUX_TMPDIR="$tmux_tmp" tmux -L "$socket_name" show-options -gv prefix) != C-g ]]; then
    printf 'compatibility test: tmux prefix is not C-g\n' >&2
    exit 1
  fi
  if TMUX_TMPDIR="$tmux_tmp" tmux -L "$socket_name" list-keys -T prefix C-a >/dev/null 2>&1; then
    printf 'compatibility test: tmux still binds C-a in the prefix table\n' >&2
    exit 1
  fi
  TMUX_TMPDIR="$tmux_tmp" tmux -L "$socket_name" kill-server
  rm -rf "$tmux_tmp"
  tmux_tmp=
fi

if command -v nvim >/dev/null 2>&1; then
  export DOTFILES_NVIM_CORE_ONLY=1
  export XDG_CACHE_HOME="$test_dir/cache"
  export XDG_CONFIG_HOME="$test_dir/config"
  export XDG_DATA_HOME="$test_dir/data"
  export XDG_STATE_HOME="$test_dir/state"
  nvim --headless -u "$repo_dir/nvim/init.lua" -l "$repo_dir/tests/nvim-core.lua"
fi

if command -v pwsh >/dev/null 2>&1; then
  pwsh -NoLogo -NoProfile -NonInteractive -File "$repo_dir/tests/windows.ps1"
fi

printf 'Cross-platform configuration compatibility passed\n'
