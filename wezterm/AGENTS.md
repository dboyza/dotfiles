# Wezterm maintenance instructions

- Keep WezTerm platform detection based on `wezterm.target_triple`, and avoid hard-coded usernames, home directories, or WSL shell paths.

- Launch WezTerm centered on macOS at 94% of the active screen width and 88% of its height, without maximizing.
  Preserve the bounded proportional launch geometry on Windows and Linux/WSL.
  Keep prefix `m` and macOS `Command+Shift+M` toggling between that large geometry and a smaller centered window, leaving native fullscreen untouched.

- Keep macOS WezTerm tab navigation on `Command+[` / `Command+]` and tab close on `Command+W` with confirmation, alongside the portable shortcuts.

- Keep the WezTerm window background opacity at 0.7 on macOS and native Windows for transparency while retaining readable text.

- Keep the WezTerm steady bar cursor at 150% of the font underline thickness across platforms.

- Keep WezTerm content padding at 36 pixels on the sides, 32 on top, and 28 on the bottom across platforms.

- On macOS, use the repository's native `WezTerm Floating Tabs` companion to place clickable numbered badges and a clock across each visible window's upper edge.
  Keep its Accessibility grant interactive; never request Screen Recording or read terminal contents.
  An enabled Accessibility entry can retain an old ad-hoc code signature after rebuilding; recover with a helper-only `tccutil reset Accessibility com.dboyza.wezterm-floating-tabs`, then a fresh manual grant.
  Exchange only window identities, tab IDs, freshness timestamps, and the explicit `new_tab` action through the private state directory.
  Keep a + button after the last floating tab on macOS and Windows, sharing the portable new-tab shortcut's domain and working directory.
  Consume click requests before acting so new-tab requests cannot replay.
  Service helper input every 16 ms, keeping heartbeat, fallback, and clock work on the slower maintenance cadence.
  Rearm WezTerm's status timer with a status setter even on input-only ticks; idle windows otherwise stop polling in WezTerm 20240203.
  Validate latency and reloads with `tests/wezterm-floating-tabs.sh --e2e` in disposable macOS GUI windows, and require an explicit Lua test verdict because WezTerm can exit successfully after falling back from a configuration error.
  Publish tab changes from the window-title event and watch the state directory for atomic replacements so badge highlighting does not wait for status polling.
  Hide native tabs only after a fresh acknowledgment for the same window; restore them if the helper fails, another application gains focus, or there is no room above the window.
  Keep snapshots, acknowledgments, click requests, and overlay panels isolated per GUI process and window; preserve native window stacking order.
  Keep focused-window overlays at floating level so clicks cannot raise the terminal over them; background overlays stay at normal level and follow their own window.
  Keep the native numbered tab bar and centered clock as the Linux default and macOS/Windows fallback.
  Center the native clock using the full window pixel width and terminal cell width, including the padded area.
  Keep a one-pixel muted lavender border that dims with window focus, retaining unrelated per-window overrides.
  Reserve the bright lavender badge fill for the active tab; use subdued inactive badges and a neutral 12-hour `h:mm AM/PM` clock in both companions and the native fallback.
  Complete macOS border corners with small click-through arcs that match focus and screen pixel density; native rectangular borders are clipped at the window radius.
  Preserve tmux's left-aligned window list, lavender active tabs, and transparent bottom bar.
  Use tmux's `e` numeric comparisons for width thresholds because its plain comparison formats compare strings.

- Resolve the selected WSL distribution's home directory explicitly for new WezTerm tabs so they do not inherit a Windows working directory.

- On native Windows, support PowerShell 7 when installed and fall back to built-in Windows PowerShell 5.1.

- Remember that Windows WezTerm reads `%USERPROFILE%/.wezterm.lua`; a WSL-side `~/.wezterm.lua` alone does not configure the Windows application.

- Treat native Windows as the host-integration target for WezTerm, fonts, PowerShell, and WSL clipboard interoperation rather than as a Nix-provisioned shell environment.

- Keep the README's WezTerm screenshot in `docs/images/wezterm-macos.png`, using a clean terminal listing and including the companion's floating badges.

- Keep WezTerm executable discovery centralized in `scripts/lib/wezterm.sh` for bootstrap and compatibility tests.

- Use a UTF-8 WezTerm loader on Windows that watches and loads the checkout path without requiring Windows symlink privileges.

- On Windows, build the native floating-tab companion from `wezterm/floating-tabs/windows.cs` with the inbox .NET Framework compiler through `scripts/install-wezterm-floating-tabs.ps1`.
  Install it on the Windows host, including for WSL sessions; keep its bridge under the Windows user profile with a user/SYSTEM-only ACL.
  Persist only the state directory DACL through .NET access-control APIs so repeat installs do not request audit privileges.
  Use nonactivating owned windows, per-monitor DPI, and native fallback when maximized, fullscreen, or badges cannot fit.
  Let Windows DWM draw the rounded, muted lavender window outline and dim it on focus loss; keep Windows Lua frame border widths at zero so an inner rectangle cannot square off the corners.
  Apply DWM frame styling independently of badge visibility so it persists when another application has focus.
  Windows Lua rename cannot replace an existing destination; retain the last valid snapshot during replacement gaps until its freshness deadline.
  Run `tests/wezterm-floating-tabs.ps1` for native layout and real Windows WezTerm bridge checks.

- Keep `.wezterm.lua` as the module loader and keep appearance, shell/platform selection, keys, geometry, and bridge logic in `config/`.
  Loaders must forward the source path and watch each module; preserve legacy Windows loaders and Unix symlink chains, including paths containing spaces.
- Treat `tests/fixtures/floating-tabs.json` as the shared Lua/Swift/C# snapshot contract.
  Keep freshness in seconds, input timing in milliseconds, byte limits explicit, and requests consumed before execution.
