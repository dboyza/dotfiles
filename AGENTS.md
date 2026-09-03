# Repository instructions

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
- Keep the macOS WezTerm launch cap near 2800 by 1800 physical pixels to match the preferred manually sized window.
- Keep plain `Control+Arrow` events passing through WezTerm on every platform so Neovim receives its navigation bindings.
- On macOS, disable only the Mission Control and Spaces symbolic hotkeys that consume `Control+Arrow`; merge those entries without replacing unrelated shortcut preferences.
- Keep MacBook-safe Command aliases for clipboard and Page Up or Page Down behavior while retaining the portable bindings for external keyboards.
- Keep tmux on `Control+G` and Herdr on `Control+A` so their prefixes do not collide when Herdr runs inside tmux.
- Resolve the selected WSL distribution's home directory explicitly for new WezTerm tabs so they do not inherit a Windows working directory.
- On native Windows, support PowerShell 7 when installed and fall back to built-in Windows PowerShell 5.1.
- Never pipe WSL clipboard text directly to `clip.exe`.
  Use the tracked UTF-8-safe `scripts/win-copy` and `scripts/win-paste` helpers for Windows clipboard interoperability.
- Treat macOS as a supported path, but state clearly when it received static validation only because no macOS runner was available.
- Keep portable packages and managed home files in `nix/home.nix`, and keep macOS system configuration in `nix/darwin.nix`.
- Keep reproducible, non-secret Pi configuration in `pi/` and deploy its writable `settings.json` through Home Manager activation so Pi can preserve runtime metadata.
  Never track Pi authentication, trust decisions, package state, or session transcripts.
- Back up Pi's managed `models.json` before activation, but leave unmanaged prompt files in place.
- When replacing managed Pi settings, remove obsolete repository-managed keys during activation while preserving unrelated runtime metadata.
- Package Pi from a versioned npm release in `nix/pi-coding-agent.nix`.
  When updating Pi, update the version, source hash, and npm dependency hash together.
- Package Codex from official release binaries in `nix/codex.nix` because the stable Nixpkgs package may lag upstream.
  When updating Codex, update the version and both artifact hashes for every supported Nix platform together.
- Pi 0.82.0's published shrinkwrap omits integrity records for first-party runtime packages and includes development dependencies.
  Keep the packaging correction, version 2 npm cache fetcher, and production-only install behavior until the published release metadata is complete.
- Keep Pi's shared `postPatch` compatible with `fetchNpmDeps`' minimal build environment; do not invoke Node there unless the npm dependency derivation explicitly includes it.
- Keep the local Pi Calm extension on its verified Pi version, preserve its bundled license, and never manage or track its runtime preference file.
- Keep third-party Pi packages pinned to immutable npm versions or Git commits in `pi/settings.json`.
- Run flake operations through `bootstrap.sh` or export `DOTFILES_USER`, `DOTFILES_HOME`, and `DOTFILES_WSL`, because host identity is intentionally resolved at evaluation time.
- Keep normal `./bootstrap.sh` activation update-first across Nix inputs, Windows Winget packages, and macOS Homebrew packages.
  Preserve `./bootstrap.sh --check` as a non-mutating build of the currently pinned configuration.
- Keep bootstrap flake checks on `--all-systems` so every exported system is evaluated before activation.
- Keep first-time Homebrew installation interactive on macOS so its installer can request administrator credentials.
- Keep post-activation verification aligned with the managed links, pinned Pi version, tmux prefix, WezTerm configuration, and macOS symbolic hotkeys.
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
- Keep `./bootstrap.sh --check` non-mutating and require an existing Nix installation instead of installing prerequisites.
- Run platform prerequisite preflight checks before updating inputs, installing packages, backing up files, or activating configuration.
- Keep WezTerm executable discovery centralized in `scripts/lib/wezterm.sh` for bootstrap and compatibility tests.
- Install Hack Nerd Font through nix-darwin on macOS and through Home Manager on Linux so each platform has one font owner.
- Keep the unused .NET test input removed from the pre-commit derivation so macOS checks do not build .NET, Swift, and LLVM.
