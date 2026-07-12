# Repository instructions

- When making a change, keep it compatible with native Windows 11, Windows 11 with WSL, and macOS.
  Use platform-specific branches or fallbacks where behavior and dependencies differ, and verify each platform path as far as the available environment allows.
  If full compatibility cannot be achieved, state the limitation explicitly instead of silently breaking a supported platform.
- After completing repository work, update this file with any durable repository-specific learning discovered during the task.
  Do not add transient session details, machine-specific state, or unverified assumptions.
- Keep this root `AGENTS.md` repository-specific so coding agents apply it only within this checkout.
- Store shared global agent instructions in `agents/global/AGENTS.md`, and ensure global Codex, Claude, and opencode instruction symlinks target that file rather than this one.
- Keep WezTerm platform detection based on `wezterm.target_triple`, and avoid hard-coded usernames, home directories, or WSL shell paths.
- On native Windows, support PowerShell 7 when installed and fall back to built-in Windows PowerShell 5.1.
- Never pipe WSL clipboard text directly to `clip.exe`.
  Use the tracked UTF-8-safe `scripts/win-copy` and `scripts/win-paste` helpers for Windows clipboard interoperability.
- Treat macOS as a supported path, but state clearly when it received static validation only because no macOS runner was available.
- Keep portable packages and managed home files in `nix/home.nix`, and keep macOS system configuration in `nix/darwin.nix`.
- Run flake operations through `bootstrap.sh` or export `DOTFILES_USER`, `DOTFILES_HOME`, and `DOTFILES_WSL`, because host identity is intentionally resolved at evaluation time.
- Keep WSL host integration in explicit helpers rather than embedding PowerShell or Windows paths in portable Nix modules.
- Remember that Windows WezTerm reads `%USERPROFILE%/.wezterm.lua`; a WSL-side `~/.wezterm.lua` alone does not configure the Windows application.
- In setup documentation, label PowerShell commands separately from WSL shell commands so Windows-host actions cannot be confused with Linux guest actions.
