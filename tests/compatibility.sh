#!/usr/bin/env bash
# Validate available configuration runtimes and report missing platform prerequisites explicitly.

set -Eeuo pipefail

export DOTFILES_TEST_REPO
repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DOTFILES_TEST_REPO=$repo_dir
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

# Section: Shell syntax and formatting
while IFS= read -r script; do
  bash -n "$repo_dir/$script"
done < <(cd "$repo_dir" && rg --files -g '*.sh' -g 'scripts/dotfiles-clipboard' -g 'scripts/win-*')

if command -v shellcheck >/dev/null 2>&1; then
  cd "$repo_dir"
  shell_scripts=()
  while IFS= read -r script; do
    shell_scripts+=("$script")
  done < <(rg --files -g '*.sh' -g 'scripts/dotfiles-clipboard' -g 'scripts/win-*')
  shellcheck "${shell_scripts[@]}"
fi

if command -v shfmt >/dev/null 2>&1; then
  cd "$repo_dir"
  shell_scripts=()
  while IFS= read -r script; do
    shell_scripts+=("$script")
  done < <(rg --files -g '*.sh' -g 'scripts/dotfiles-clipboard' -g 'scripts/win-*')
  shfmt -d -i 2 -ci "${shell_scripts[@]}"
fi

# Section: Shell initialization and managed PATH
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
    # Managed launchers must win even while old Brew installations remain.
    mkdir -p "$test_dir/home/.local/bin"
    while IFS= read -r tool; do
      printf '#!/bin/sh\nexit 99\n' >"$test_dir/home/.local/bin/$tool"
      chmod +x "$test_dir/home/.local/bin/$tool"
      detected_tool=$(
        HOME="$test_dir/home" PATH=/usr/bin:/bin TERM=xterm-256color \
          zsh -dfc 'source "$1"; command -v "$2"' zsh "$repo_dir/zsh/.zshrc" "$tool"
      )
      [[ "$detected_tool" == "$test_dir/home/.local/bin/$tool" ]] || exit 1
    done < <(python3 -c 'import json,sys; print("\n".join(json.load(open(sys.argv[1]))))' "$repo_dir/scripts/managed-tools.json")
    if [[ "$detected_homebrew" != "$homebrew_binary" ]]; then
      printf 'compatibility test: zsh did not initialize Homebrew from %s\n' "$homebrew_binary" >&2
      exit 1
    fi
  fi
fi

if command -v zsh >/dev/null 2>&1; then
  zsh_home="$test_dir/zsh-home"
  mkdir -p "$zsh_home/.config/zsh/plugins"
  printf 'typeset -g DOTFILES_AUTOSUGGESTIONS_LOADED=1\n' \
    >"$zsh_home/.config/zsh/plugins/zsh-autosuggestions.zsh"
  autosuggestions_loaded=$(
    HOME="$zsh_home" PATH=/usr/bin:/bin TERM=xterm-256color \
      zsh -dfc 'source "$1"; print -r -- "${DOTFILES_AUTOSUGGESTIONS_LOADED:-0}"' \
      zsh "$repo_dir/zsh/.zshrc"
  )
  if [[ "$autosuggestions_loaded" != 1 ]]; then
    printf 'compatibility test: zsh did not load ghost suggestions from the managed plugin path\n' >&2
    exit 1
  fi
fi

# Section: JSON data and WezTerm configuration
if command -v jq >/dev/null 2>&1; then
  while IFS= read -r json_file; do
    jq empty "$repo_dir/$json_file"
  done < <(cd "$repo_dir" && rg --files -g '*.json')
fi

wezterm_command=$(find_wezterm_gui || true)

if [[ -n "$wezterm_command" ]]; then
  keys="$test_dir/wezterm-keys"
  check_wezterm_config "$repo_dir/wezterm/.wezterm.lua" >"$keys"
  check_wezterm_config "$repo_dir/tests/wezterm-tabs.lua" >/dev/null
  for direction in Left Right Up Down; do
    if ! grep -E "^[[:space:]]*CTRL[[:space:]]+${direction}Arrow[[:space:]]+->[[:space:]]+SendKey.*mods: CTRL" "$keys" >/dev/null; then
      printf 'compatibility test: WezTerm does not pass Control+%s through unchanged\n' "$direction" >&2
      exit 1
    fi
  done
fi

# Section: Multiplexer configuration
if command -v tmux >/dev/null 2>&1; then
  tmux_tmp=$(mktemp -d /tmp/dotfiles-tmux-test.XXXXXX)
  socket_name="dotfiles-test-$$"
  tmux_home="$test_dir/tmux-home"
  mkdir -p "$tmux_home/.tmux/plugins"
  # Plugins can install assistant hooks; keep those writes out of the user's HOME.
  for plugin in tmux-resurrect tmux-assistant-resurrect tmux-continuum; do
    if [[ -d "$HOME/.tmux/plugins/$plugin" ]]; then
      ln -s "$HOME/.tmux/plugins/$plugin" "$tmux_home/.tmux/plugins/$plugin"
    fi
  done
  HOME="$tmux_home" TMUX_TMPDIR="$tmux_tmp" tmux -L "$socket_name" -f "$repo_dir/tmux/.tmux.conf" new-session -d
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
  if TMUX_TMPDIR="$tmux_tmp" tmux -L "$socket_name" list-keys -T prefix | grep -Eq -- '-T[[:space:]]+prefix[[:space:]]+C-a[[:space:]]'; then
    printf 'compatibility test: tmux still binds C-a in the prefix table\n' >&2
    exit 1
  fi
  TMUX_TMPDIR="$tmux_tmp" tmux -L "$socket_name" kill-server
  rm -rf "$tmux_tmp"
  tmux_tmp=
fi

# Section: Editor and key routing
if command -v nvim >/dev/null 2>&1; then
  NVIM_LOG_FILE="$test_dir/wezterm-keys.log" \
    nvim --headless -u NONE -i NONE -l "$repo_dir/tests/run-lua.lua" "$repo_dir/tests/wezterm-keys.lua" "$repo_dir/wezterm/.wezterm.lua"

  NVIM_LOG_FILE="$test_dir/wezterm-nvim.log" \
    nvim --headless -u NONE -l "$repo_dir/tests/run-lua.lua" "$repo_dir/tests/wezterm-launch-size.lua" "$repo_dir/wezterm/.wezterm.lua"

  (
    export DOTFILES_NVIM_CORE_ONLY=1
    export XDG_CACHE_HOME="$test_dir/cache"
    export XDG_CONFIG_HOME="$test_dir/config"
    export XDG_DATA_HOME="$test_dir/data"
    export XDG_STATE_HOME="$test_dir/state"
    nvim --headless -u "$repo_dir/nvim/init.lua" -l "$repo_dir/tests/run-lua.lua" "$repo_dir/tests/nvim-core.lua"
    nvim --headless -u "$repo_dir/nvim/init.lua" -l "$repo_dir/tests/run-lua.lua" "$repo_dir/tests/nvim-project.lua"
  )
fi

if command -v herdr >/dev/null 2>&1; then
  DOTFILES_TOOL_UPDATE=0 HERDR_CONFIG_PATH="$repo_dir/herdr/config.toml" herdr config check
fi

if command -v pwsh >/dev/null 2>&1; then
  pwsh -NoLogo -NoProfile -NonInteractive -File "$repo_dir/tests/windows.ps1"
fi

# Section: Explicit coverage gaps
for dependency in shellcheck shfmt zsh jq tmux nvim herdr pwsh; do
  if ! command -v "$dependency" >/dev/null 2>&1; then
    printf 'UNAVAILABLE: compatibility requires %s for its associated checks\n' "$dependency"
  fi
done
if [[ -z "$wezterm_command" ]]; then
  printf 'UNAVAILABLE: WezTerm configuration checks require wezterm-gui\n'
fi
printf 'Available configuration compatibility checks passed\n'
