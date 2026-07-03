# dotfiles

Personal terminal and editor configuration.

This repo keeps each tool in its own top-level directory and avoids adding a dotfile manager requirement.
Install by symlinking the files you want into the locations expected by each tool.

## Contents

| Path | Purpose |
| --- | --- |
| `nvim/` | Neovim configuration using `lazy.nvim`, Catppuccin, Telescope, Treesitter, and Markdown rendering. |
| `tmux/.tmux.conf` | tmux configuration with `C-a` prefix, vi copy mode, top status bar, pane navigation, and clipboard bindings. |
| `wezterm/.wezterm.lua` | WezTerm configuration with Rose Pine Moon colors, Hack Nerd Font, WSL domain selection on Windows, and custom keybindings. |
| `zsh/.zshrc` | zsh configuration for PATH, history, completion, aliases, optional autosuggestions and syntax highlighting, and Starship. |

## Prerequisites

Install the tools for the configs you plan to use:

- `zsh`
- `tmux`
- `wezterm`
- `nvim`
- `git`
- `rg`, recommended for Telescope live grep
- `Hack Nerd Font`, used by WezTerm
- `starship`, optional zsh prompt
- `zsh-autosuggestions`, optional shell suggestions
- `zsh-syntax-highlighting`, optional command highlighting

The Neovim config bootstraps `lazy.nvim` automatically on first launch.
That first launch needs network access so `lazy.nvim` can be cloned and plugins can be installed.

The tmux and Neovim clipboard settings also support WSL through `win-copy` and `win-paste`.
Those helpers are optional, but clipboard integration in WSL expects them to exist on `PATH`, usually under `~/.local/bin`.

## Install

Back up any existing files first.
Then create symlinks from this checkout into your home directory.

```sh
repo="$HOME/github/dboyza/dotfiles"

ln -s "$repo/zsh/.zshrc" "$HOME/.zshrc"
ln -s "$repo/tmux/.tmux.conf" "$HOME/.tmux.conf"
ln -s "$repo/wezterm/.wezterm.lua" "$HOME/.wezterm.lua"

mkdir -p "$HOME/.config"
ln -s "$repo/nvim" "$HOME/.config/nvim"
```

If a target path already exists, replace it only after you have copied out anything you still need.

## Update

Pull the repo and let the tools update their own managed state.

```sh
git -C "$HOME/github/dboyza/dotfiles" pull
```

For Neovim plugins, open Neovim and run:

```vim
:Lazy sync
```

Commit `nvim/lazy-lock.json` after plugin updates when you want to pin the new plugin revisions.

## Notes

The tmux prefix is `C-a`.
Pane movement uses `h`, `j`, `k`, and `l` behind the prefix, with uppercase variants resizing panes.

WezTerm uses `Ctrl-Space` as its leader.
On Windows, it prefers the `WSL:Ubuntu-24.04` domain when available and otherwise falls back to the first WSL domain reported by WezTerm.

Neovim uses the spacebar as leader.
The config keeps the UI minimal, enables persistent undo, and sets up clipboard integration when the host supports it.
