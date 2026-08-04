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
- Resolve the selected WSL distribution's home directory explicitly for new WezTerm tabs so they do not inherit a Windows working directory.
- On native Windows, support PowerShell 7 when installed and fall back to built-in Windows PowerShell 5.1.
- Never pipe WSL clipboard text directly to `clip.exe`.
  Use the tracked UTF-8-safe `scripts/win-copy` and `scripts/win-paste` helpers for Windows clipboard interoperability.
- Treat macOS as a supported path, but state clearly when it received static validation only because no macOS runner was available.
- Keep portable packages and managed home files in `nix/home.nix`, and keep macOS system configuration in `nix/darwin.nix`.
- Keep reproducible, non-secret Pi configuration in `pi/` and deploy its writable `settings.json` through Home Manager activation so Pi can preserve runtime metadata.
  Never track Pi authentication, trust decisions, package state, or session transcripts.
- Package Pi from a versioned npm release in `nix/pi-coding-agent.nix`.
  When updating Pi, update the version, source hash, and npm dependency hash together.
- Pi 0.80.7's published shrinkwrap omits integrity records for first-party runtime packages and excludes development dependencies.
  Keep the packaging correction, version 2 npm cache fetcher, and production-only install behavior until the published release metadata is complete.
- Implement Pi's Codex fast mode by sending `service_tier: "priority"` only for the `openai-codex` provider.
  Treat `fast` as the user-facing mode name, not the wire-level service tier.
- Fetch Pi's OpenAI usage status with its refreshed in-memory OAuth token and the Codex usage endpoint.
  Never persist or log OAuth tokens or raw usage responses.
- Send Pi notifications from native Windows and WSL through Windows WinRT using WezTerm's `org.wezfurlong.wezterm` application ID.
  Use JavaScript for Automation with Notification Center on macOS and OSC 777 as the fallback on other platforms.
  Suppress desktop notifications while WezTerm is the focused application.
- Run flake operations through `bootstrap.sh` or export `DOTFILES_USER`, `DOTFILES_HOME`, and `DOTFILES_WSL`, because host identity is intentionally resolved at evaluation time.
- Keep normal `./bootstrap.sh` activation update-first across Nix inputs, Windows Winget packages, and macOS Homebrew packages.
  Preserve `./bootstrap.sh --check` as a non-mutating build of the currently pinned configuration.
- Treat Winget's `APPINSTALLER_CLI_ERROR_UPDATE_NOT_APPLICABLE` result as success when an idempotent install finds an existing package with no applicable update.
- In `bootstrap.sh`, platform guards in functions called under `set -e` must return success when intentionally skipping another platform.
- Keep WSL host integration in explicit helpers rather than embedding PowerShell or Windows paths in portable Nix modules.
- Remember that Windows WezTerm reads `%USERPROFILE%/.wezterm.lua`; a WSL-side `~/.wezterm.lua` alone does not configure the Windows application.
- In setup documentation, label PowerShell commands separately from WSL shell commands so Windows-host actions cannot be confused with Linux guest actions.
