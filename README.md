# dotfiles

Personal terminal and editor configuration for Dylan's daily shell, tmux, terminal, and Neovim setup.
The repo is public enough to be readable by other people, but it is still tuned for Dylan's machines and workflow.

The checkout is intentionally small.
There is no dotfile manager and no installer script in this tree.
Install the pieces you want by backing up any existing files and symlinking these tracked config files into the paths each tool expects.

## Contents

| Path | Purpose |
| --- | --- |
| `.gitattributes` | Repository attributes. |
| `README.md` | This operations guide. |
| `nvim/` | Neovim configuration, including `init.lua` and `lazy-lock.json`. |
| `tmux/.tmux.conf` | tmux configuration with a `C-a` prefix, vi copy mode, top status bar, clipboard helpers, and TPM plugins. |
| `wezterm/.wezterm.lua` | WezTerm configuration with Rose Pine Moon colors, Hack Nerd Font, WSL domain selection on Windows, and custom keybindings. |
| `zsh/.zshrc` | zsh configuration for PATH, history, completion, aliases, optional highlighting, optional suggestions, and Starship. |

## Prerequisites

### Required Base Tools

Install the tools for the configs you plan to use:

- `git`
- `zsh`
- `tmux`
- `wezterm`
- `nvim`

Neovim also expects a reasonably current Neovim release with Lua support.
The config uses modern Neovim APIs and is not written for legacy Vim.

### Recommended Tools

These are not installed by the repo, but the configs are better with them present:

- `rg`, used by Neovim's `grepprg` and Telescope live grep.
- `node`, used by Mason-installed language tooling such as `bash-language-server`, `pyright`, and `typescript-language-server`.
- `make` and `cc`, used only when building Telescope's native fzf extension.
- `Hack Nerd Font`, used by WezTerm and by completion icons in Neovim.
- `batcat` or `bat`, used by the copy-paste friendly `cat` alias when available.

### Optional Integrations

Install these only when you want the related integration:

- `starship`, used as the zsh prompt when available.
- `zsh-autosuggestions`, sourced from common Linux and Homebrew locations when available.
- `zsh-syntax-highlighting`, sourced from common Linux and Homebrew locations when available.
- `win-copy` and `win-paste`, preferred by Neovim on WSL when available.
- `win32yank.exe`, used by Neovim on WSL when the `win-copy` pair is not available.
- `clip.exe` and `powershell.exe`, used by tmux clipboard bindings on Windows or WSL.
- `pbcopy` and `pbpaste`, used by Neovim and tmux on macOS.
- `wl-copy` and `wl-paste`, used by Neovim and tmux on Wayland.
- `xclip` or `xsel`, used by Neovim and tmux on X11.

### Config-Managed Tools

Neovim bootstraps `lazy.nvim` on first launch if it is missing.
After `lazy.nvim` is present, it installs the plugins declared in `nvim/init.lua` and uses `nvim/lazy-lock.json` to pin plugin revisions.

Mason is managed inside Neovim.
The config asks Mason to install `bash-language-server`, `lua-language-server`, `pyright`, `stylua`, `typescript-language-server`, `prettierd`, and `shfmt`.
These Mason packages still depend on external runtime support where applicable, especially `node`.

tmux plugins are declared in `tmux/.tmux.conf`, but TPM itself is external.
Install TPM into `~/.tmux/plugins/tpm` before expecting plugin bootstrapping to work.

## Installation

Clone the repo with SSH:

```sh
mkdir -p "$HOME/github/dboyza"
git clone git@github.com:dboyza/dotfiles.git "$HOME/github/dboyza/dotfiles"
cd "$HOME/github/dboyza/dotfiles"
```

Back up or remove existing targets before creating symlinks.
The symlink commands below are intentionally plain `ln -s` commands, so they will fail instead of overwriting an existing file or directory.

```sh
stamp="$(date +%Y%m%d%H%M%S)"

[ -e "$HOME/.zshrc" ] && mv "$HOME/.zshrc" "$HOME/.zshrc.backup.$stamp"
[ -e "$HOME/.tmux.conf" ] && mv "$HOME/.tmux.conf" "$HOME/.tmux.conf.backup.$stamp"
[ -e "$HOME/.wezterm.lua" ] && mv "$HOME/.wezterm.lua" "$HOME/.wezterm.lua.backup.$stamp"
[ -e "$HOME/.config/nvim" ] && mv "$HOME/.config/nvim" "$HOME/.config/nvim.backup.$stamp"
```

Create the symlinks:

```sh
repo="$HOME/github/dboyza/dotfiles"

mkdir -p "$HOME/.config"

ln -s "$repo/zsh/.zshrc" "$HOME/.zshrc"
ln -s "$repo/tmux/.tmux.conf" "$HOME/.tmux.conf"
ln -s "$repo/wezterm/.wezterm.lua" "$HOME/.wezterm.lua"
ln -s "$repo/nvim" "$HOME/.config/nvim"
```

Install TPM if you use the tmux config:

```sh
git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
```

Start tmux and press `prefix` + `I` to install the declared tmux plugins.
In this config, `prefix` is `C-a`.

## First Run

Open Neovim after the symlink is in place:

```sh
nvim
```

The first launch may download `lazy.nvim`, install plugins, install Mason-managed tools, and build Treesitter parsers or optional plugin components.
That first launch needs network access and working external tools such as `git`, `node`, `make`, and `cc` depending on which plugins are being installed.

If the first launch fails during the `lazy.nvim` clone, fix network or Git access and run `nvim` again.
If a Mason tool fails, open Neovim and use `:Mason` to inspect the failed package.
If plugin state looks stale after changing this repo, run `:Lazy sync`.

## Updating

Pull the repo:

```sh
git -C "$HOME/github/dboyza/dotfiles" pull
```

Update Neovim plugins from inside Neovim:

```vim
:Lazy sync
```

Commit `nvim/lazy-lock.json` after intentional plugin updates so plugin revisions stay reproducible.

Update tmux plugins from inside tmux with `prefix` + `U`.
Reload tmux config with `prefix` + `r` or `prefix` + `R`.

## Tool Notes

### Neovim

The Neovim leader key is Space.
The UI uses absolute and relative line numbers, a persistent undo file, split defaults, visible whitespace characters, a compact statusline, and a winbar showing the current file.

Clipboard support is detected at startup.
The preferred paths are WSL `win-copy` and `win-paste`, WSL `win32yank.exe`, macOS `pbcopy` and `pbpaste`, Wayland `wl-copy` and `wl-paste`, X11 `xclip`, X11 `xsel`, then Neovim's built-in clipboard support where available.

The plugin set includes Catppuccin, guess-indent, gitsigns, which-key, todo-comments, mini.nvim modules, blink.cmp with LuaSnip, native LSP support, Mason, conform.nvim, Telescope, render-markdown, and Treesitter.
Configured language servers are Bash, Lua, Python, and TypeScript.
Configured formatters cover JavaScript, JSON, Lua, Markdown, Python, shell, and TypeScript.

Telescope live grep searches hidden files and depends on `rg`.
The native fzf extension is built only when both `make` and `cc` are available.

### tmux

The tmux prefix is `C-a`.
Windows and panes start at index `1`, mouse support is on, copy mode uses vi keys, the status bar is at the top, and the scrollback history limit is `50000`.

The config declares TPM, tmux-yank, tmux-resurrect, tmux-continuum, and `timvw/tmux-assistant-resurrect`.
Those plugins are not available until TPM exists at `~/.tmux/plugins/tpm/tpm` and the plugins have been installed.

Clipboard commands are selected from the host environment.
tmux falls back to its own buffer when no external clipboard command is found.

### WezTerm

WezTerm uses the Rose Pine Moon color scheme, Hack Nerd Font, a steady bar cursor, high scrollback, hidden tab bar when only one tab is open, and centered startup sizing.

On Windows, the config enables Acrylic background settings and prefers the `WSL:Ubuntu-24.04` domain when WezTerm reports it.
If that exact WSL domain is not available, it uses the first WSL domain reported by WezTerm.
Outside Windows, no default domain override is set.

The WezTerm leader key is `Ctrl-Space`.
Copy behavior is tmux-aware for `Ctrl-Shift-c`: if text is selected, it copies the selection; otherwise, it sends `Ctrl-Shift-c` through to the pane.

### zsh

The zsh config prepends `~/.local/bin` and `~/.opencode/bin` to `PATH` when those directories exist.
It enables shared history, cached completion, Emacs keybindings, word movement bindings, a few common aliases, optional shell suggestions, optional syntax highlighting, and Starship when installed.

The `cat` alias uses `batcat --plain --paging=never` when `batcat` is available.
If the binary is named `bat`, it uses `bat --plain --paging=never` instead.
That keeps output free of line numbers, headers, grid borders, and pager behavior so terminal selection stays copy-paste friendly.

## Key Reference

### Neovim

| Key | Mode | Action |
| --- | --- | --- |
| `Space` | Normal | Leader key. |
| `<leader>w` | Normal | Save file. |
| `<leader>x` | Normal | Save and quit. |
| `<leader>q` | Normal | Quit window. |
| `<leader>e` | Normal | Open mini.files at the current file or working directory. |
| `<leader>[` / `<leader>]` | Normal | Previous or next buffer. |
| `<leader>bd` | Normal | Delete buffer. |
| Leader plus vertical bar / `<leader>-` | Normal | Vertical or horizontal split. |
| `<A-h/j/k/l>` | Normal | Move between Neovim windows, or tmux panes at the edge. |
| `<A-Up/Down/Left/Right>` | Normal | Resize windows. |
| `<leader>y` / `<leader>Y` | Normal, Visual | Copy selection or line to the system clipboard. |
| `<leader>p` | Normal, Visual | Paste from the system clipboard. |
| `<leader>ff` | Normal | Telescope find files. |
| `<leader>fg` | Normal | Telescope live grep. |
| `<leader>fb` | Normal | Telescope buffers. |
| `<leader>/` | Normal | Fuzzy find in the current buffer. |
| `[d` / `]d` | Normal | Previous or next diagnostic. |
| `<leader>dd` | Normal | Show line diagnostic. |
| `<leader>dl` | Normal | Populate the location list with diagnostics. |
| `gd` / `gr` / `gI` | Normal, LSP | Definition, references, or implementation. |
| `<leader>rn` | Normal, LSP | Rename symbol. |
| `<leader>ca` | Normal, Visual, LSP | Code action. |
| `<leader>cf` | Normal, Visual | Format buffer or selection. |
| `<leader>th` | Normal, LSP | Toggle inlay hints when supported by the server. |
| `]h` / `[h` | Normal, Git | Next or previous git hunk. |
| `<leader>hp` / `<leader>hb` | Normal, Git | Preview hunk or blame line. |

### tmux

| Key | Action |
| --- | --- |
| `C-a` | Prefix. |
| `prefix` + `C-a` | Send prefix to the pane. |
| `prefix` + `h/j/k/l` | Move between panes. |
| `prefix` + `H/J/K/L` | Resize panes by 5 cells. |
| `prefix` + `\` | Split pane horizontally in the current path. |
| `prefix` + `-` or `_` | Split pane vertically in the current path. |
| `prefix` + `c` | New window in the current path. |
| `prefix` + `r` or `R` | Reload `~/.tmux.conf`. |
| `prefix` + `y` | Enter copy mode. |
| `v` in copy mode | Begin selection. |
| `Ctrl-c` or `Shift-Ctrl-c` in copy mode | Copy selection using the selected clipboard command. |
| `Ctrl-v` or `Shift-Ctrl-v` | Paste from the selected clipboard command or tmux buffer. |
| `Alt-h/j/k/l` | Move panes unless the foreground process is Vim, Neovim, or view. |
| `prefix` + `s` / `w` | Choose session or window. |
| `prefix` + `z` | Zoom pane. |
| `prefix` + `Space` | Next layout. |

### WezTerm

| Key | Action |
| --- | --- |
| `Ctrl-Space` | Leader key. |
| `Ctrl-Shift-r` | Reload WezTerm configuration. |
| `Ctrl-Shift-f` | Search scrollback. |
| `Ctrl-Shift-k` | Clear scrollback only. |
| `Alt-Enter` | Toggle fullscreen. |
| `Ctrl-Shift-t` | Spawn tab. |
| `Ctrl-Shift-w` | Close current tab with confirmation. |
| `leader` + `c` | Spawn tab in the default domain. |
| `Ctrl-Shift-c` | Copy selected text, or send the key through when nothing is selected. |
| `Ctrl-Shift-v` | Paste from clipboard. |
| `Ctrl-Insert` / `Shift-Insert` | Copy or paste. |
| `Ctrl-Up` / `Ctrl-Down` | Scroll by 5 lines. |
| `PageUp` / `PageDown` | Scroll by page, or send through to tmux and alternate-screen programs. |
| `Ctrl-PageUp` / `Ctrl-PageDown` | Scroll by line, or send through to tmux and alternate-screen programs. |
| Right click | Clear selection and paste from clipboard. |

## Troubleshooting

### First Neovim Run Cannot Clone `lazy.nvim`

Check network access and Git HTTPS access.
The bootstrap path clones `https://github.com/folke/lazy.nvim.git` into Neovim's data directory.
After fixing the underlying Git or network issue, start Neovim again.

### Telescope Live Grep Fails

Install `rg`.
The config sets `grepprg` to `rg --vimgrep`, and Telescope live grep also expects ripgrep.

### WezTerm Font Looks Wrong

Install Hack Nerd Font and make sure WezTerm can see it.
The config explicitly requests `Hack Nerd Font`.

### tmux Reports Missing TPM

Install TPM into `~/.tmux/plugins/tpm`.
The last line of `tmux/.tmux.conf` runs `~/.tmux/plugins/tpm/tpm`, so tmux will complain if that file is absent.

### Clipboard Does Not Reach the Host OS

Install the clipboard tool for your platform.
Without an external clipboard command, tmux falls back to its internal buffer, and Neovim only enables system clipboard behavior when a supported provider is available.

### Symlink Creation Fails

Check whether the target already exists.
The install commands use plain `ln -s`, so existing files and directories must be backed up, moved, or removed first.

## Maintenance Notes

Keep docs tied to tracked files and live config behavior.
Do not document helper scripts unless they are present in this checkout.

When changing Neovim plugins intentionally, run `:Lazy sync`, test startup, and commit the resulting `nvim/lazy-lock.json` if plugin revisions changed.
When changing tmux plugins, make sure the TPM plugin list and any documented key behavior stay aligned.
When changing terminal or clipboard behavior, verify the affected host path directly because Windows, WSL, macOS, Wayland, and X11 use different commands.
