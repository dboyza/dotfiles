# WezTerm configuration

`.wezterm.lua` locates the checkout, loads the modules below, and watches each one for changes.
Unix home-file symlinks and Windows UTF-8 loaders work with checkout paths containing spaces.
New Windows loaders forward the source path; older managed loaders remain supported through their saved source literal.

| Module | Responsibility |
| --- | --- |
| `config/palette.lua` | Shared Rose Pine Moon colors for the terminal, native tabs, and window border |
| `config/platform.lua` | Platform detection, executable probes, shell selection, and new-tab actions |
| `config/appearance.lua` | Fonts, renderer, colors, bell, command palette, padding, window frame, and native tab bar |
| `config/keys.lua` | Keyboard and mouse routing, Quick Select patterns, and clickable links |
| `config/tab_info.lua` | Per-tab label, git branch, path, progress, and alert hints shared by every publisher |
| `config/geometry.lua` | Centered launch geometry and size toggling |
| `config/tabs.lua` | Native fallback rendering, companion exchange, and status cadence |
| `config/protocol.lua` | Snapshot and request validation, freshness, and bridge limits |

Bindings that match WezTerm's defaults are not repeated in `keys.lua`: `Control+Shift+R` reload, `Control+Shift+K` clear scrollback, `Control+/Shift+Insert` copy/paste, and `Command+C`.

## Companion contract

Lua owns tab creation and activation.
Swift and C# own native window discovery, placement, rendering, and focus handling.
They exchange no terminal contents or executable commands.
Shared snapshot examples live in `tests/fixtures/floating-tabs.json` and run through all three implementations.
Request cases run through Lua, which is the only request consumer.

Each GUI process creates an opaque alphanumeric token.
A window's key is `<token>-<window-id>` and its title is `WezTerm [<token>:<window-id>]`.
Files live under `~/.local/state/dotfiles/wezterm-floating-tabs/` on the host, including the Windows user profile for WSL.

| File | Payload and behavior |
| --- | --- |
| `window-<key>.json` | `key`, `title`, epoch-second `updated`, and nonempty `tabs` with unique nonnegative integer `id` and `index`, boolean `active`, and exactly one active tab; optional display hints: `label` and `branch` (at most 64 UTF-8 bytes each), `path` (at most 256), boolean `alert`, `progress` (0 to 100), and `progress_state` (`normal`, `error`, or `indeterminate`) |
| `ready-<key>.json` | Matching `title` and fresh `updated`; only this acknowledgment hides native tabs |
| `activate-<key>.json` | Matching `title`, fresh `updated`, and a `tab_id` (activate), `action: "new_tab"`, `"move_tab"` with a `tab_id` and target `index`, or `"close_tab"`, `"rename_tab"`, `"duplicate_tab"`, or `"detach_tab"` with a `tab_id`; consumed before acting |

Freshness is an absolute age strictly below three seconds, including future timestamps.
Snapshots are limited to 65,536 bytes.
Every tab action activates the tab first. `close_tab` then runs the same confirmed close as `Control+Shift+W`, `move_tab` reorders it, `duplicate_tab` opens a sibling in the same directory, `detach_tab` moves it to a new window, and `rename_tab` prompts for a name (empty resets it).
Labels name the tab's custom title first, then its program; branches are read from repository files with no child processes, and progress comes from programs that report it through the terminal (OSC 9;4).
Labels name the foreground program (or the folder for a plain shell); alerts come from the terminal bell and the Zsh integration's `dotfiles_command_done` user variable.
Unknown object fields are tolerated; malformed, ambiguous, foreign, or stale requests cause no action.
Tab IDs must belong to the target window at execution time.
Consumption prevents a second status tick from replaying new-tab actions.

Changes publish immediately through the title event; unchanged snapshots get a one-second heartbeat.
Input is checked every 16 milliseconds when a companion is installed.
The clock, fallback, and border maintenance keep their slower cadence.
Every input tick rearms WezTerm's status timer, including ticks without a click.
Windows readers retain the last fresh snapshot through the short remove/rename gap.

## Verification

Run `./tests/wezterm-floating-tabs.sh` on macOS for the real Lua API, simulated Windows/WSL selection, compiled Swift contract, layout, and filesystem notification checks.
Add `--e2e` for isolated two-window activation and configuration/module reload measurements.
Run `./tests/wezterm-floating-tabs.ps1` from Windows PowerShell for compiled C#, frame styling, layout, ACL, and real Windows bridge checks.
A simulation is not a native platform run.
