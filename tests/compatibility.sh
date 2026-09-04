#!/usr/bin/env bash

set -Eeuo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/lib/wezterm.sh
source "$repo_dir/scripts/lib/wezterm.sh"
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

if [[ $(uname -s) == Darwin ]]; then
  homebrew_binary=
  for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [[ -x "$candidate" ]]; then
      homebrew_binary=$candidate
      break
    fi
  done

  if [[ -n "$homebrew_binary" ]]; then
    mkdir -p "$test_dir/home"
    detected_homebrew=$(
      HOME="$test_dir/home" PATH=/usr/bin:/bin TERM=xterm-256color \
        zsh -dfc 'source "$1"; command -v brew' zsh "$repo_dir/zsh/.zshrc"
    )
    if [[ "$detected_homebrew" != "$homebrew_binary" ]]; then
      printf 'compatibility test: zsh did not initialize Homebrew from %s\n' "$homebrew_binary" >&2
      exit 1
    fi
  fi
fi

if command -v jq >/dev/null 2>&1; then
  while IFS= read -r json_file; do
    jq empty "$repo_dir/$json_file"
  done < <(cd "$repo_dir" && rg --files -g '*.json')
fi

wezterm_command=$(find_wezterm || true)

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
  if [[ $(TMUX_TMPDIR="$tmux_tmp" tmux -L "$socket_name" show-options -gv status-position) != bottom ]]; then
    printf 'compatibility test: tmux window tabs are not at the bottom\n' >&2
    exit 1
  fi
  if [[ $(TMUX_TMPDIR="$tmux_tmp" tmux -L "$socket_name" show-options -gv status) != on ]]; then
    printf 'compatibility test: tmux window tabs are not a single visible row\n' >&2
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
  NVIM_LOG_FILE="$test_dir/wezterm-nvim.log" \
    nvim --headless -u NONE -l "$repo_dir/tests/wezterm-launch-size.lua" "$repo_dir/wezterm/.wezterm.lua"

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
