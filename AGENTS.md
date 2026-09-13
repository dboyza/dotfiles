# Repository instructions

- Keep the default Zsh `ls` alias comma-separated with `-m`, preserving platform-specific color flags.

- When making a change, keep it compatible with native Windows 11, Windows 11 with WSL, and macOS.
  Use platform-specific branches or fallbacks where behavior and dependencies differ, and verify each platform path as far as the available environment allows.
  If full compatibility cannot be achieved, state the limitation explicitly instead of silently breaking a supported platform.
- After completing repository work, update this file with any durable repository-specific learning discovered during the task.
  Do not add transient session details, machine-specific state, or unverified assumptions.
- Keep this root `AGENTS.md` repository-specific so coding agents apply it only within this checkout.
- Store shared global agent instructions in `agents/global/AGENTS.md`, and ensure global Codex, Claude, opencode, and Pi instruction symlinks target that file rather than this one.
  Pi's global instruction path is `~/.pi/agent/AGENTS.md`, not `~/.pi/AGENTS.md`.
- Keep WezTerm platform detection based on `wezterm.target_triple`, and avoid hard-coded usernames, home directories, or WSL shell paths.
- Keep the larger adaptive WezTerm launch size scoped to macOS so Windows and WSL retain their existing window dimensions.
- Keep the macOS WezTerm launch size proportional to the active screen so display scaling changes retain consistently large margins.
- Keep the macOS WezTerm launch position slightly above vertical center so its outer frame clears the Dock.
- Keep the WezTerm window background opacity at 0.75 on macOS and native Windows for transparency while retaining readable text.
- Keep plain `Control+Arrow` events passing through WezTerm on every platform so Neovim receives its navigation bindings.
- On macOS, disable only the Mission Control and Spaces symbolic hotkeys that consume `Control+Arrow`; merge those entries without replacing unrelated shortcut preferences.
- Keep MacBook-safe Command aliases for clipboard and Page Up or Page Down behavior while retaining the portable bindings for external keyboards.
- On macOS, route image-only Command+V paste to the application's Control+V handler and preserve normal terminal paste for text and copied file paths.
  Keep plain Control+V unbound in tmux's root table, including on configuration reload.
- Use Option+Left/Right for word movement and Command+Left/Right for Home/End on macOS.
  Send Home/End keys rather than Control+A/Control+E so Herdr's prefix remains usable, and bind both CSI and SS3 Home/End sequences in Zsh.
- Keep tmux on `Control+G` and Herdr on `Control+A` so their prefixes do not collide when Herdr runs inside tmux.
- Keep tmux windows in a single bottom status row and hide WezTerm's native tab bar when only one native tab exists so the normal tmux interface does not show duplicate tab systems.
- Center WezTerm's cell-based tab row with left-status padding measured from the whole tab, not an individual split pane.
  Keep label widths and centering calculations aligned, with display-cell-aware Unicode truncation.
- Resolve the selected WSL distribution's home directory explicitly for new WezTerm tabs so they do not inherit a Windows working directory.
- On native Windows, support PowerShell 7 when installed and fall back to built-in Windows PowerShell 5.1.
- Never pipe WSL clipboard text directly to `clip.exe`.
  Use the tracked UTF-8-safe `scripts/win-copy` and `scripts/win-paste` helpers for Windows clipboard interoperability.
- Treat macOS as a supported path, but state clearly when it received static validation only because no macOS runner was available.
- Keep portable packages and managed home files in `nix/home.nix`, and keep macOS system configuration in `nix/darwin.nix`.
- Keep the macOS app inventory in `nix/macos-apps.json` and install missing apps through `scripts/install-macos-apps.py` during nix-darwin activation.
  Skip existing bundles regardless of version or installation source, including user Applications folders and renamed apps found by bundle ID.
  Do not enable Homebrew activation upgrades or put these apps in `environment.systemPackages`, which would replace them on activation.
  Verify direct downloads with pinned checksums and preserve legacy Nix Apps bundles before nix-darwin cleans that directory.
  Install missing App Store apps by ID with the Nix-provided `mas get`; keep existing-app detection ahead of all App Store commands and leave account authentication interactive.
- Keep curated macOS preferences in `system.defaults` in `nix/darwin.nix`.
  When capturing existing preferences, use supported options and explicit saved values; do not import account data, recent items, Dock application bookmarks, or window state.
  Removing a preference declaration does not reset its stored macOS value.
- Expose Zsh plugin scripts through managed paths under `~/.config/zsh/plugins`; Home Manager profiles do not reliably link package-specific top-level `share` directories.
- Keep reproducible, non-secret Pi configuration in `pi/` and symlink its `settings.json` directly into the checkout.
  Pi may write runtime settings into that file; review these changes before committing.
  Never track Pi authentication, trust decisions, package state, or session transcripts.
- Back up Pi's managed `models.json` before activation, but leave unmanaged prompt files in place.
- Keep Codex, Pi, opencode, and Herdr on the shared `scripts/dotfiles-tool.mjs` launcher with writable, versioned installations outside the Nix store.
  Nix manages the launchers, Node.js, ripgrep, and Linux bubblewrap; package updates happen at launch.
  Preserve offline fallback, serialized updates, and the `DOTFILES_TOOL_UPDATE=0` bypass.
  Verify Herdr downloads against its official release manifest and preserve the bundled ConPTY runtime on Windows.
  Resolve npm executable entries from installed package metadata; OpenCode can publish a native binary rather than a JavaScript launcher.
- Preserve the local Pi Calm extension's bundled license and never manage or track its runtime preference file.
  Pi updates independently, so treat extension compatibility as a runtime check rather than pinning the whole application.
- Keep third-party Pi packages pinned to immutable npm versions or Git commits in `pi/settings.json`.
- Customize Pi's footer through `pi/extensions/codex-statusline`, not by patching installed packages.
  Recheck its isolated adapter-reader integration when updating Codex Conversion, and preserve cache diagnostics and error statuses.
  Keep Codex Conversion's configuration runtime-owned because its atomic writer replaces symlinks; reproduce status-only diagnostics using the extension's setup instructions.
  Follow `pi/CODEX-UI.md` for Structured rendering; standalone patch/image toggles take precedence over the saved execution mode on the Codex provider.
- Before changing third-party Pi package pins, review published artifacts and runtime dependencies, and keep npm lifecycle scripts disabled through Pi's `npmCommand` configuration.
  Preserve its production-only and legacy-peer flags so configured Git installs do not pull development dependencies or duplicate Pi runtimes.
- Keep Pi scrolling adjustments in `pi/extensions/scroll-sensitivity`, not in global terminal preferences or installed package patches.
  Revalidate its guarded internal `wheelScrollLines` integration after Pi upgrades; fullscreen wheel handling precedes extension input listeners in Pi 0.85.1.
- Install the computer-use Python runtime from `pi/computer-use/requirements.txt`, not the upstream requirements or postinstall hook.
  Regenerate its hash-locked dependencies with uv from `requirements.in`; do not edit generated requirements manually.
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
- Keep `bootstrap.sh` as the thin public entry point, with shared and platform-specific behavior in `scripts/lib/`.
- Keep the bootstrap managed-target inventory centralized so backup and verification always operate on the same paths.
  Evaluate enabled Home Manager `home.file` targets once before backup; do not maintain a second list in shell scripts.
- Keep `./bootstrap.sh --check` non-mutating and require an existing Nix installation instead of installing prerequisites.
- Run platform prerequisite preflight checks before updating inputs, installing packages, backing up files, or activating configuration.
- Keep WezTerm executable discovery centralized in `scripts/lib/wezterm.sh` for bootstrap and compatibility tests.
- Install Hack Nerd Font through nix-darwin on macOS and through Home Manager on Linux so each platform has one font owner.
- Keep the unused .NET test input removed from the pre-commit derivation so macOS checks do not build .NET, Swift, and LLVM.
- Keep Neovim's Neo-tree sidebar, Bufferline tab row, and Lualine status line visually coordinated with the transparent Rosé Pine terminal theme.
- Deploy repository-authored home files through `mkOutOfStoreSymlink` using the absolute checkout path from `DOTFILES_REPO`.
  Keep packaged Zsh and tmux plugins in the Nix store.
  Configuration edits require only application reloads; moving the checkout or changing Nix declarations requires activation.
- Keep Lazy's lockfile in the live Neovim configuration directory so plugin updates and Git restores affect the same file.
- Use a UTF-8 WezTerm loader on Windows that watches and loads the checkout path without requiring Windows symlink privileges.
- Keep Neovim's entry point small, with core settings in `nvim/lua/config` and plugin declarations in `nvim/lua/plugins`.
- Load Zsh plugins from the managed `~/.config/zsh/plugins` paths instead of searching package-manager directories.
- Share clipboard provider selection through `scripts/dotfiles-clipboard`; keep the Windows UTF-8 transport in `scripts/win-copy` and `scripts/win-paste`.
- Let Nix install and pin tmux plugins, and initialize the restoration plugins directly without TPM or tmux-yank.
  Initialize assistant restoration before continuum so restoration hooks are ready when automatic restore runs.
- Isolate tmux integration tests from the real home directory because restoration plugins install assistant hooks and write runtime state.
