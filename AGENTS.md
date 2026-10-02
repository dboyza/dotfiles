# Repository instructions

- Keep the default Zsh `ls` alias in its normal listing layout without `-m`, preserving platform-specific color flags.

- When making a change, keep it compatible with native Windows 11, Windows 11 with WSL, and macOS.
  Use platform-specific branches or fallbacks where behavior and dependencies differ, and verify each platform path as far as the available environment allows.
  If full compatibility cannot be achieved, state the limitation explicitly instead of silently breaking a supported platform.
- After completing repository work, update this file with any durable repository-specific learning discovered during the task.
  Do not add transient session details, machine-specific state, or unverified assumptions.
- Keep this root `AGENTS.md` repository-specific so coding agents apply it only within this checkout.
- Store shared global agent instructions in `agents/global/AGENTS.md`, and ensure global Codex, Claude, opencode, and Pi instruction symlinks target that file rather than this one.
  Pi's global instruction path is `~/.pi/agent/AGENTS.md`, not `~/.pi/AGENTS.md`.
- Keep WezTerm platform detection based on `wezterm.target_triple`, and avoid hard-coded usernames, home directories, or WSL shell paths.
- Launch WezTerm centered on macOS at 94% of the active screen width and 88% of its height, without maximizing.
  Preserve the bounded proportional launch geometry on Windows and Linux/WSL.
  Keep prefix `m` and macOS `Command+Shift+M` toggling between that large geometry and a smaller centered window, leaving native fullscreen untouched.
- Keep macOS WezTerm tab navigation on `Command+[` / `Command+]` and tab close on `Command+W` with confirmation, alongside the portable shortcuts.
- Keep the WezTerm window background opacity at 0.7 on macOS and native Windows for transparency while retaining readable text.
- Preserve Rosé Pine Moon's palette with a deeper `#191724` default background and brighter `#eeecff` default foreground.
- Keep the WezTerm steady bar cursor at 150% of the font underline thickness across platforms.
- Keep WezTerm content padding at 36 pixels on the sides, 32 on top, and 28 on the bottom across platforms.
- Treat keybindings as one end-to-end contract across host OS shortcuts, WezTerm, tmux, Herdr, shells, Neovim, and configured agent applications.
  Every keybinding change must preserve the most consistent, sensible, ergonomic behavior possible across native Windows, WSL, and MacBook keyboards.
  Audit enclosing-layer interception, inherited defaults, editor modes, legacy terminal encodings, and laptop accessibility before assigning a chord; keep portable shortcuts plus appropriate Command/Option aliases.
  Do not make essential actions depend only on a function-key row, Home/End/Insert keys, or OS-reserved shortcuts.
  Update `docs/keybindings.md` and affected routing tests alongside changes, documenting intentional differences and migrations.
- Keep WezTerm's prefix on `Control+Shift+Space` so `Control+Space` reaches completion, and preserve the distinct tmux and Herdr prefixes below.
  Across multiplexers, use prefix `h/j/k/l` for focus, `H/J/K/L` for resizing, and backslash/minus for side-by-side/stacked splits.
  Route fullscreen application Page keys through tmux; reserve shell Page keys and explicit copy mode for scrollback.
  Let nested Neovim handle Alt pane navigation first, then the nearest enclosing Herdr pane before outer tmux.
- Keep plain `Control+Arrow` events passing through WezTerm on every platform so Neovim receives its navigation bindings.
- On macOS, disable only the Mission Control and Spaces symbolic hotkeys that consume `Control+Arrow`; merge those entries without replacing unrelated shortcut preferences.
- Keep MacBook-safe Command aliases for clipboard and Page Up or Page Down behavior while retaining the portable bindings for external keyboards.
- On macOS, route image-only Command+V paste to the application's Control+V handler and preserve normal terminal paste for text and copied file paths.
  Keep plain Control+V unbound in tmux's root table, including on configuration reload.
- Use Option+Left/Right for word movement and Command+Left/Right for Home/End on macOS.
  Translate Option+Left/Right to Control+Left/Right so shell and editor word navigation agree.
  Send Home/End keys rather than Control+A/Control+E so Herdr's prefix remains usable, and bind both CSI and SS3 Home/End sequences in Zsh.
  Map direct Command+Left/Right events to native Home/End in macOS Neovim too, including insert and command-line modes.
  Keep Command+H/L as Home/End aliases in both macOS WezTerm and Neovim, overriding WezTerm's default Command+H hide action.
  Use Command+Up/Down for native Control+Home/End file navigation in Neovim editing modes.
- Keep tmux on `Control+G` and Herdr on `Control+A` so their prefixes do not collide when Herdr runs inside tmux.
- Keep tmux windows in a single bottom status row and WezTerm's native tab bar always visible at the top, including with one tab.
- On macOS, use the repository's native `WezTerm Floating Tabs` companion to place clickable numbered badges and a clock across each visible window's upper edge.
  Keep its Accessibility grant interactive; never request Screen Recording or read terminal contents.
  An enabled Accessibility entry can retain an old ad-hoc code signature after rebuilding; recover with a helper-only `tccutil reset Accessibility com.dboyza.wezterm-floating-tabs`, then a fresh manual grant.
  Exchange only window identities, tab IDs, and freshness timestamps through the private state directory.
  Publish tab changes from the window-title event and watch the state directory for atomic replacements so badge highlighting does not wait for status polling.
  Hide native tabs only after a fresh acknowledgment for the same window; restore them if the helper fails, another application gains focus, or there is no room above the window.
  Keep snapshots, acknowledgments, click requests, and overlay panels isolated per GUI process and window; preserve native window stacking order.
  Keep focused-window overlays at floating level so clicks cannot raise the terminal over them; background overlays stay at normal level and follow their own window.
  Keep the native numbered tab bar and centered clock as the Linux default and macOS/Windows fallback.
  Center the native clock using the full window pixel width and terminal cell width, including the padded area.
  Keep the thin lavender window border and native tab backing colors matched to the dark bar.
  Complete macOS border corners with small click-through arcs in the companion; native rectangular borders are clipped at the window radius.
  Preserve tmux's left-aligned window list, lavender active tabs, and transparent bottom bar.
  Use tmux's `e` numeric comparisons for width thresholds because its plain comparison formats compare strings.
- On Windows, build the native floating-tab companion from `wezterm/floating-tabs/windows.cs` with the inbox .NET Framework compiler through `scripts/install-wezterm-floating-tabs.ps1`.
  Install it on the Windows host, including for WSL sessions; keep its bridge under the Windows user profile with a user/SYSTEM-only ACL.
  Persist only the state directory DACL through .NET access-control APIs so repeat installs do not request audit privileges.
  Use nonactivating owned windows, per-monitor DPI, and native fallback when maximized, fullscreen, or badges cannot fit.
  Windows Lua rename cannot replace an existing destination; retain the last valid snapshot during replacement gaps until its freshness deadline.
  Run `tests/wezterm-floating-tabs.ps1` for native layout and real Windows WezTerm bridge checks.
- Resolve the selected WSL distribution's home directory explicitly for new WezTerm tabs so they do not inherit a Windows working directory.
- On native Windows, support PowerShell 7 when installed and fall back to built-in Windows PowerShell 5.1.
- Never pipe WSL clipboard text directly to `clip.exe`.
  Use the tracked UTF-8-safe `scripts/win-copy` and `scripts/win-paste` helpers for Windows clipboard interoperability.
- Treat macOS as a supported path, but state clearly when it received static validation only because no macOS runner was available.
- Keep Linux packages and shared managed home files in `nix/home.nix`, macOS user packages in `nix/homebrew.nix`, and macOS system configuration in `nix/darwin.nix`.
- Keep the macOS app inventory in `nix/macos-apps.json` and install missing apps through `scripts/install-macos-apps.py` during nix-darwin activation.
  Skip existing bundles regardless of version or installation source, including user Applications folders and renamed apps found by bundle ID.
  Do not enable Homebrew activation upgrades or put these apps in `environment.systemPackages`, which would replace them on activation.
  Verify direct downloads with pinned checksums and preserve legacy Nix Apps bundles before nix-darwin cleans that directory.
  Install missing App Store apps by ID with the Homebrew-provided `mas get`; keep existing-app detection ahead of all App Store commands and leave account authentication interactive.
- Keep curated macOS preferences in `system.defaults` in `nix/darwin.nix`.
  When capturing existing preferences, use supported options and explicit saved values; do not import account data, recent items, Dock application bookmarks, or window state.
  Removing a preference declaration does not reset its stored macOS value.
- Expose Zsh plugin scripts through managed paths under `~/.config/zsh/plugins`; Home Manager profiles do not reliably link package-specific top-level `share` directories.
- Keep reproducible, non-secret Pi configuration in `pi/` and symlink its `settings.json` directly into the checkout.
  Pi may write runtime settings into that file; review these changes before committing.
  Never track Pi authentication, trust decisions, package state, or session transcripts.
- Pi currently uses factory settings: do not redeploy archived extensions, themes, or model overrides without an explicit request.
  See `pi/DEFAULTS.md`; keep credentials, sessions, and shared instructions outside resets.
- On macOS, Linux, WSL, and native Windows, keep Codex, Claude Code, Pi, opencode, and Herdr on the shared `scripts/dotfiles-tool.mjs` launcher with writable, versioned installations outside the Nix store.
  On Linux, Nix manages the launchers, Node.js, ripgrep, and bubblewrap; package updates happen at launch.
  Preserve offline fallback, serialized updates, and the `DOTFILES_TOOL_UPDATE=0` bypass.
  Install official standalone releases for all five tools, using GitHub asset SHA-256 digests for Codex, Pi, and opencode and publisher manifests for Claude Code and Herdr.
  Preserve complete Codex and Pi runtime bundles and Herdr's ConPTY runtime on Windows; reject archive links and unsafe paths before extraction.
  Track the selected archive in installation state so old npm installs migrate even when the version is unchanged.
  Keep Node.js for the launchers and npm for extension or development workflows, without using npm to install the applications.
  Keep Claude Code's internal updater disabled only in managed child processes so it cannot compete with launcher version selection.
  Put `~/.local/bin` ahead of Homebrew and Nix package paths after shell initialization so old installs cannot shadow managed launchers.
  On native Windows, back up same-name executables and PowerShell scripts before installing `.cmd` launchers so command precedence cannot bypass updates.
  Use opencode baseline builds on x64 for older CPUs; Pi standalone Linux builds require glibc.
- Preserve the archived Pi Calm extension's bundled license and never manage or track its runtime preference file.
  Pi updates independently, so treat extension compatibility as a runtime check rather than pinning the whole application.
- If third-party Pi packages are reenabled, pin them to immutable npm versions or Git commits in `pi/settings.json`.
- If Pi footer customization is requested again, use `pi/extensions/codex-statusline`, not installed package patches.
  Recheck its isolated adapter-reader integration when updating Codex Conversion, and preserve cache diagnostics and error statuses.
  Keep Codex Conversion's configuration runtime-owned because its atomic writer replaces symlinks; reproduce status-only diagnostics using the extension's setup instructions.
  `pi/CODEX-UI.md` documents the archived Structured profile; standalone patch/image toggles take precedence over its saved execution mode on the Codex provider.
- Before changing third-party Pi package pins, review published artifacts and runtime dependencies, and keep npm lifecycle scripts disabled through Pi's `npmCommand` configuration.
  Restore its production-only and legacy-peer flags before installing packages so configured Git installs do not pull development dependencies or duplicate Pi runtimes.
- If Pi scrolling customization is requested again, use `pi/extensions/scroll-sensitivity`, not global terminal preferences or installed package patches.
  Revalidate its guarded internal `wheelScrollLines` integration after Pi upgrades; fullscreen wheel handling precedes extension input listeners in Pi 0.85.1.
- Install the computer-use Python runtime from `pi/computer-use/requirements.txt`, not the upstream requirements or postinstall hook.
  Regenerate its hash-locked dependencies with uv from `requirements.in`; do not edit generated requirements manually.
- Run macOS activation with `sudo -H` so elevated Nix uses root's home; preserve the target user's home separately through `DOTFILES_HOME`.
- Run flake operations through `bootstrap.sh` or export `DOTFILES_USER`, `DOTFILES_HOME`, `DOTFILES_REPO`, and `DOTFILES_WSL`, because host identity is intentionally resolved at evaluation time.
- Keep normal `./bootstrap.sh` activation update-first for Nix inputs and Windows Winget packages; macOS desktop apps are install-only.
  Preserve `./bootstrap.sh --check` as a non-mutating build of the currently pinned configuration.
- Keep bootstrap flake checks on `--all-systems` so every exported system is evaluated before activation.
- Keep first-time Homebrew installation interactive on macOS so its installer can request administrator credentials.
- Discover Homebrew from `PATH` or the standard Apple Silicon or Intel prefix during bootstrap, and initialize it in interactive macOS shells because bootstrap cannot persist its child-process environment.
- Keep post-activation verification aligned with the managed links, launcher syntax, Pi settings, tmux prefix, WezTerm configuration, and macOS symbolic hotkeys.
- Keep `tests/run.sh` covering x86_64 and ARM64 Linux and macOS evaluation, native Windows PowerShell validation when PowerShell is available, and WSL profile and clipboard behavior.
- Treat Winget's `APPINSTALLER_CLI_ERROR_UPDATE_NOT_APPLICABLE` result as success when an idempotent install finds an existing package with no applicable update.
- In `bootstrap.sh`, platform guards in functions called under `set -e` must return success when intentionally skipping another platform.
- Before the first nix-darwin activation, preserve conflicting `/etc/bashrc` and `/etc/zshrc` files without overwriting existing `.before-nix-darwin` backups; leave established `/etc/static` links untouched.
- Keep WSL host integration in explicit helpers rather than embedding PowerShell or Windows paths in portable Nix modules.
- Remember that Windows WezTerm reads `%USERPROFILE%/.wezterm.lua`; a WSL-side `~/.wezterm.lua` alone does not configure the Windows application.
- Treat native Windows as the host-integration target for WezTerm, fonts, PowerShell, and WSL clipboard interoperation rather than as a Nix-provisioned shell environment.
- In setup documentation, label PowerShell commands separately from WSL shell commands so Windows-host actions cannot be confused with Linux guest actions.
- Keep the section index at the top of `README.md` synchronized with every level-two and level-three heading.
- Keep the README's WezTerm screenshot in `docs/images/wezterm-macos.png`, using a clean terminal listing and including the companion's floating badges.
- Keep `bootstrap.sh` as the thin public entry point, with shared and platform-specific behavior in `scripts/lib/`.
- Keep the bootstrap managed-target inventory centralized so backup and verification always operate on the same paths.
  Evaluate enabled Home Manager `home.file` targets once before backup; do not maintain a second list in shell scripts.
- Keep `./bootstrap.sh --check` non-mutating and require an existing Nix installation instead of installing prerequisites.
- Run platform prerequisite preflight checks before updating inputs, installing packages, backing up files, or activating configuration.
- Keep WezTerm executable discovery centralized in `scripts/lib/wezterm.sh` for bootstrap and compatibility tests.
- Install Hack Nerd Font through Homebrew on macOS and through Home Manager on Linux so each platform has one font owner.
- On macOS, Homebrew owns the remaining user command-line packages and Node.js; keep Codex, Claude Code, Pi, opencode, and Herdr out of its package lists.
  Keep Homebrew activation install-only with no cleanup, resolve paths from `homebrew.prefix`, and use Brew's `mas` for App Store installation.
  Declare HashiCorp's Terraform tap as trusted for Homebrew 6 activation; do not disable tap-trust checks globally.
  Keep GNU make's `libexec/gnubin` and Brew curl/unzip paths in the macOS session PATH.
  Use Apple's `/bin/zsh` as the login shell so it is available before Homebrew's first activation.
- Keep the unused .NET test input removed from the pre-commit derivation so macOS checks do not build .NET, Swift, and LLVM.
- Keep Neovim's Neo-tree sidebar, Bufferline tab row, and Lualine status line visually coordinated with the transparent Rosé Pine terminal theme.
- Deploy repository-authored home files through `mkOutOfStoreSymlink` using the absolute checkout path from `DOTFILES_REPO`.
  Keep tmux plugins and Linux Zsh plugins in the Nix store; macOS Zsh plugin links target Homebrew's stable share paths.
  Configuration edits require only application reloads; moving the checkout or changing Nix declarations requires activation.
- Keep Lazy's lockfile in the live Neovim configuration directory so plugin updates and Git restores affect the same file.
- Use a UTF-8 WezTerm loader on Windows that watches and loads the checkout path without requiring Windows symlink privileges.
- Keep Neovim `Space e` switching focus between Neo-tree and the previous editor window without hiding the sidebar.
- Close Neo-tree after opening a file from it; expanding a directory should leave the explorer open.
- Open Neo-tree only on request through `Space e` or `:Neotree`, not automatically at startup, in new tabs, or when opening directories.
- Let Neo-tree close when the last editor window in its tab closes so normal quit commands do not require a second quit for the sidebar.
- Keep Neovim's entry point small, with core settings in `nvim/lua/config` and plugin declarations in `nvim/lua/plugins`.
- Initialize Zoxide in the tracked `zsh/.zshrc` after completion setup; Home Manager does not generate this live-linked file.
- Load Zsh plugins from the managed `~/.config/zsh/plugins` paths instead of searching package-manager directories.
- Share clipboard provider selection through `scripts/dotfiles-clipboard`; keep the Windows UTF-8 transport in `scripts/win-copy` and `scripts/win-paste`.
- Let Nix install and pin tmux plugins, and initialize the restoration plugins directly without TPM or tmux-yank.
  Initialize assistant restoration before continuum so restoration hooks are ready when automatic restore runs.
- Isolate tmux integration tests from the real home directory because restoration plugins install assistant hooks and write runtime state.
- Inspect complete tmux key tables and filter by table and key when checking bindings; the Brew tmux 3.7 positional key filter can return empty output even for existing bindings.
- Keep Pyright type checking off by default in Neovim while retaining Python completion and navigation.
- Keep Neovim's IDE shortcuts under `Space T` for tests and `Space r` for debugging, preserving `Space d` for diagnostics and `Space t` for toggles.
  Document changes in `docs/neovim.md`.
  Scope format-on-save toggles and terminal working directories through `config.project`; toggles last for the current Neovim session.
  Run Jest and Vitest through Node entry points with argument arrays, avoiding platform-specific `.bin` shims and whitespace-split executable paths.
  Keep debug adapters managed by Mason, and keep test runners in the user's project environment.
- Keep Reviewr preferences in `herdr/reviewr.toml` and use Herdr `Control+A`, then `v` to toggle its review pane.
  Install the plugin through Herdr on macOS or Linux/WSL; upstream does not support native Windows.

- Keep accelerated `j`/`k` and Up/Down movement in Normal mode through `rhysd/accelerated-jk`, preserving native counted motions.
  Keep the first 40 repeats at one line; tune onset with the acceleration table because `acceleration_limit` controls the pause between repeats that resets acceleration.
- Use Snacks indent guides with animation disabled and theme-coordinated guide colors in Neovim.
  Keep macOS held-key repeat preferences in `nix/darwin.nix`; these affect all applications, not only Neovim.

- Build missing Strafe apps from the checksum-pinned source in `nix/macos-apps.json`, using the native Apple toolchain and host architecture.
  Preserve existing bundles and leave Accessibility authorization interactive.
- Install macOS Python 3.11–3.14 with user-owned uv runtimes during activation, without upgrades or executable-link replacement.
  Homebrew remains the default Python owner; do not add a duplicate Python.org installer.
