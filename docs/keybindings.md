# Keyboard shortcuts

Use the same portable shortcuts on Windows, WSL, and macOS, with Command and Option aliases for the MacBook keyboard.
Application modes still matter: typing in a shell, editing in Neovim, and browsing terminal scrollback have different native behavior.
The host OS handles shortcuts first, followed by WezTerm, tmux, Herdr, and the foreground application.

## Prefixes and panes

Press a prefix, release it, then press the action key.
These prefixes select the layer you want to control, even when the applications are nested.

| Layer | Prefix | Purpose |
| --- | --- | --- |
| WezTerm | `Control+Shift+Space` | Native terminal tabs and panes |
| tmux | `Control+G` | Persistent sessions, windows, and panes |
| Herdr | `Control+A` | Agent workspaces, tabs, and panes |
| Neovim | `Space` in Normal mode | Editor actions and discoverable menus |

WezTerm's prefix waits 1.5 seconds for an action.
`Control+Space` reaches the application for completion; if macOS assigns it to input-source switching, change that shortcut in System Settings or use Neovim's automatic completion and `Tab`.
Within tmux, press `Control+G` twice to send one `Control+G` to the application, including Pi's external-editor action.
Use Home instead of relying on shell `Control+A` while inside Herdr.

| After the multiplexer prefix | WezTerm | tmux | Herdr |
| --- | --- | --- | --- |
| `h` / `j` / `k` / `l` | Focus left / down / up / right | Same | Same |
| `H` / `J` / `K` / `L` | Resize toward that direction | Same | Same |
| `\` / `-` | Split side by side / stacked | Same | Same |
| `c` | New tab | New window | New tab |
| `p` / `n` | Previous / next tab | Previous / next window | Previous / next tab |
| `x` | Close pane, with confirmation | Close pane | Close pane |
| `z` | Toggle pane zoom | Same | Same |
| `y` | Terminal copy mode | tmux copy mode | Use the enclosing terminal's copy mode |
| `s` | Use command palette | Session picker | Workspace picker |
| `r` | Use `Control+Shift+R` | Reload configuration | Reload configuration |

WezTerm also has prefix `P` for PowerShell, `f` for terminal search, `q` for Quick Select, `Space` for its command palette, and `Enter` for fullscreen.
Use prefix `m` to toggle between the large launch size and a smaller centered window; macOS also supports `Command+M`, replacing the default minimize action.
The smaller size is 55% of the active screen's width and height, capped at 70% of the large size on very large displays.
Leave fullscreen before using the size toggle; Linux window positioning depends on the window manager and is unavailable under Wayland.
Prefix `=` / `_` / `0` increases / decreases / resets font size; macOS also retains `Command+=` / `Command+-` / `Command+0`.
PowerShell tabs fall back to the default domain when PowerShell is unavailable.
`Control+Shift+T` creates a terminal tab, `Control+Tab` and `Control+Shift+Tab` switch terminal tabs, and `Control+Shift+W` closes a terminal tab with confirmation.
On macOS, use `Command+[` / `Command+]` for the previous / next WezTerm tab, `Command+T` for a new tab, and `Command+W` to close the current tab with confirmation.
The two-key bracket shortcuts work directly from shells, tmux, Herdr, and Neovim because WezTerm handles them first.
Existing `Command+Shift+[` / `Command+Shift+]` and portable `Control+Tab` / `Control+Shift+Tab` shortcuts remain available.
WezTerm launches centered on macOS at 94% of the screen width and 88% of its height, leaving desktop margins instead of maximizing.
On macOS, the floating-tab companion places clickable numbered tabs and a centered clock across the focused window’s upper edge.
Existing tab shortcuts continue to work.
The built-in numbered tab bar remains the fallback on Windows/Linux, in fullscreen, and whenever the companion cannot draw safely.
See [macOS floating tabs](macos.md#floating-wezterm-tabs) for the one-time Accessibility setup.
Herdr prefix `v` toggles Reviewr, `d` detaches, and `?` shows its full shortcut list.
Herdr also has a native Windows launcher; its Reviewr plugin is supported here only on macOS and Linux/WSL.

In Neovim Normal mode, `Alt+h/j/k/l` focuses an editor window first, then the nearest enclosing Herdr pane, or tmux when outside Herdr.
Use left Option for these Alt shortcuts on macOS; right Option remains available for composed characters.
Use explicit prefixes to target an outer layer or to navigate panes while at a shell prompt inside Herdr.
Neovim `Space \` and `Space -` split side by side and stacked; `Space |` remains an alias.
Use native `Control+W` followed by `+`, `-`, `>`, `<`, or `=` to resize or equalize editor windows.

## Navigation and clipboard

| Action | Portable keyboard | MacBook alias |
| --- | --- | --- |
| Word backward / forward | `Control+Left` / `Control+Right` | `Option+Left` / `Option+Right` |
| Line beginning / end | `Home` / `End` | `Command+Left` / `Command+Right`, or `Command+H` / `Command+L` |
| File beginning / end in Neovim | `Control+Home` / `Control+End` | `Command+Up` / `Command+Down` |
| Page up / down | `Page Up` / `Page Down` | `Command+Shift+Up` / `Command+Shift+Down` |
| Modified page up / down | `Control+Page Up` / `Control+Page Down` | `Command+Option+Up` / `Command+Option+Down` |
| Copy terminal selection | `Control+Shift+C` or `Control+Insert` | `Command+C` |
| Paste clipboard text | `Control+Shift+V` or `Shift+Insert` | `Command+V` |
| Application clipboard/image paste | Application's `Control+V` handler | Image-only `Command+V` sends `Control+V` |

Page keys scroll WezTerm history at a plain shell prompt and tmux history at a shell prompt inside tmux.
Fullscreen applications receive them directly, including through nested tmux; their own page and modified-page behavior applies.
In terminal scrollback, the modified page keys scroll one line; in Neovim, native `Control+Page Up/Down` switches tabs.
Use WezTerm prefix `y` or tmux prefix `y` when you explicitly want terminal history over a fullscreen application.
Apps running in the normal screen rather than the alternate screen can still have page keys handled by the enclosing terminal.

Zsh supports Home/End in both CSI and SS3 encodings and uses Shift+Left/Right or Control+Shift+Left/Right to select characters or words.
With no terminal selection, `Control+Shift+C` sends the Zsh selection-copy event on macOS and Linux/WSL; native Windows passes the modified key to its application.
`Command+C` copies the terminal selection; use `Space y` to copy a Neovim selection and `Space p` to paste within Neovim.
Plain `Control+C` remains available to interrupt applications.
Text and copied file paths use normal terminal paste; the macOS image-only path preserves the application's screenshot handler.
Pi's native Windows/WSL image-paste fallback is `Alt+V`.

macOS Mission Control and Spaces must release `Control+Arrow`; the managed system configuration disables only those conflicting shortcuts.
Apply changed macOS system settings through bootstrap, or disable the corresponding shortcuts manually as described in the [macOS guide](macos.md#use-and-update).
Windows logo shortcuts and system language shortcuts remain owned by Windows.
Native PowerShell retains PSReadLine's defaults; this repository does not deploy a custom PowerShell editing keymap.
International layouts and custom OS shortcuts may require local adjustments; the portable prefix actions do not require a Home, End, Insert, or function-key row.

## Neovim and agent applications

Neovim retains its modal editing vocabulary and the [IDE workflow shortcuts](neovim.md).
`Space` opens the shortcut menu; `Space fk` searches mappings.
`Control+H/L` aliases word navigation and `Control+J/K` aliases five-line scrolling in Normal and Visual modes.
Insert-mode completion keeps its own `Control+K` signature-help binding.
`j/k` and Up/Down accelerate only after 40 rapid repeats; counted motions remain native.
`Control+/` toggles the project terminal, with `Control+_` supported for legacy terminal encoding and `Space ft` as the portable Normal-mode fallback.
Press `Esc Esc` to leave Terminal mode before using Normal-mode shortcuts.

WezTerm passes `Control+Shift+P`, `Control+Shift+F`, `Control+Shift+Up/Down`, and `Control+-` to foreground applications so Pi can use its model, transcript, and undo bindings.
On Windows/WSL, Pi additionally provides platform-specific alternatives such as `Alt+P`, `Control+F`, and `Alt+Z` on WSL or `Control+Z` on Windows.
This repository does not replace agent applications' keymaps or reactivate archived Pi extensions.
Use each application's shortcut help for its current model-specific, mode-specific, or extension-provided actions.

## Changes and maintenance

WezTerm's old `Control+Space` prefix is now `Control+Shift+Space`.
Terminal search moved from `Control+Shift+F` to prefix `f`, and PowerShell moved from `Control+Shift+P` or prefix `p` to prefix `P`.
Bare `Control+-` now reaches application undo; use prefix `_` or `Command+-` for font reduction.
tmux prefix lowercase `h/j/k/l` now focuses panes; uppercase `H/J/K/L` continues to resize them.
Herdr pane focus moved from bare Alt chords to prefix `h/j/k/l`, allowing nested Neovim to receive Alt chords.
Neovim Option+Left/Right now moves by words instead of resizing; use its native window-resize commands.
Neovim `Control+J/K` now scrolls like `Control+Down/Up` rather than moving the cursor five lines.

WezTerm reloads automatically; use `Control+Shift+R` if needed.
Reload tmux with prefix `r`, reload Herdr with prefix `r`, and restart Neovim.
No Nix activation is required for these application configuration changes.

Maintain this guide and the routing tests whenever changing shortcuts.
`tests/wezterm-keys.lua` checks Mac ARM/Intel, Windows, and Linux configuration branches; `tests/nvim-core.lua` exercises editor modes and nested pane routing.
`tests/keyboard-routing.py` sends real terminal bytes through an isolated tmux client into Neovim and checks shell scrollback and pane controls.
`tests/clipboard.sh` covers clipboard selection, UTF-8 transport, and reload behavior.
The keyboard changes have runtime coverage on macOS; Windows and WSL configuration paths have static/mocked coverage and still need keyboard testing on those hosts.
