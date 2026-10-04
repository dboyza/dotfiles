# WezTerm configuration

`.wezterm.lua` locates the checkout, loads the modules below, and watches each one for changes.
Unix home-file symlinks and Windows UTF-8 loaders work with checkout paths containing spaces.
New Windows loaders forward the source path; older managed loaders remain supported through their saved source literal.

| Module | Responsibility |
| --- | --- |
| `config/platform.lua` | Platform detection, executable probes, shell selection, and new-tab actions |
| `config/appearance.lua` | Fonts, colors, padding, cursor, and base frame settings |
| `config/keys.lua` | Keyboard and mouse routing |
| `config/geometry.lua` | Centered launch geometry and size toggling |
| `config/tabs.lua` | Native fallback rendering, companion exchange, and status cadence |
| `config/protocol.lua` | Snapshot and request validation, freshness, and bridge limits |

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
| `window-<key>.json` | `key`, `title`, epoch-second `updated`, and nonempty `tabs` with unique nonnegative integer `id` and `index`, boolean `active`, and exactly one active tab |
| `ready-<key>.json` | Matching `title` and fresh `updated`; only this acknowledgment hides native tabs |
| `activate-<key>.json` | Matching `title`, fresh `updated`, and either `tab_id` or `action: "new_tab"`; consumed before acting |

Freshness is an absolute age strictly below three seconds, including future timestamps.
Snapshots are limited to 65,536 bytes.
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
