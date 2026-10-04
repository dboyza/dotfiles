# Scripts maintenance instructions

- Keep the optional macOS Adrafinil fallback in `scripts/adrafinil-agent-poll.py` activity-scoped, with a 60-second LaunchAgent interval and expiring, separately named holds.
  Use Codex's active-turn power assertion and Claude's live busy status, never process presence alone.
  Add fallback holds only for tool/PID pairs without native coverage, including Codex clients connected to a held service through verified Unix socket endpoints.
  Remove redundant fallback holds after rechecking that native coverage remains present.
  Clean up dead native agent holds too; a shared Codex app-server PID is not proof that its individual sessions are active.
  Check process birth times and session lifecycle metadata, then recheck each hold immediately before releasing stale hooks; preserve manual holds and unknown activity.
  Absence from one Codex index is not proof of a dead session.
  Serialize polls and keep failed or incomplete observations from removing native protection.
  Exercise the command-line workflow with `tests/adrafinil-agent-poll-e2e.py` in its isolated home before installing changes.

- Never pipe WSL clipboard text directly to `clip.exe`.
  Use the tracked UTF-8-safe `scripts/win-copy` and `scripts/win-paste` helpers for Windows clipboard interoperability.

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

- Run macOS activation with `sudo -H` so elevated Nix uses root's home; preserve the target user's home separately through `DOTFILES_HOME`.

- Run flake operations through `bootstrap.sh` or export `DOTFILES_USER`, `DOTFILES_HOME`, `DOTFILES_REPO`, and `DOTFILES_WSL`, because host identity is intentionally resolved at evaluation time.

- Keep normal `./bootstrap.sh` activation update-first for Nix inputs and Windows Winget packages; macOS desktop apps are install-only.
  Preserve `./bootstrap.sh --check` as a non-mutating build of the currently pinned configuration.

- Keep bootstrap flake checks on `--all-systems` so every exported system is evaluated before activation.

- Keep first-time Homebrew installation interactive on macOS so its installer can request administrator credentials.

- Discover Homebrew from `PATH` or the standard Apple Silicon or Intel prefix during bootstrap, and initialize it in interactive macOS shells because bootstrap cannot persist its child-process environment.

- Treat Winget's `APPINSTALLER_CLI_ERROR_UPDATE_NOT_APPLICABLE` result as success when an idempotent install finds an existing package with no applicable update.

- In `bootstrap.sh`, platform guards in functions called under `set -e` must return success when intentionally skipping another platform.

- Before the first nix-darwin activation, preserve conflicting `/etc/bashrc` and `/etc/zshrc` files without overwriting existing `.before-nix-darwin` backups; leave established `/etc/static` links untouched.

- Keep WSL host integration in explicit helpers rather than embedding PowerShell or Windows paths in portable Nix modules.

- Keep `bootstrap.sh` as the thin public entry point, with shared and platform-specific behavior in `scripts/lib/`.

- Keep the bootstrap managed-target inventory centralized so backup and verification always operate on the same paths.
  Evaluate enabled Home Manager `home.file` targets once before backup; do not maintain a second list in shell scripts.

- Keep `./bootstrap.sh --check` non-mutating and require an existing Nix installation instead of installing prerequisites.

- Share clipboard provider selection through `scripts/dotfiles-clipboard`; keep the Windows UTF-8 transport in `scripts/win-copy` and `scripts/win-paste`.

- Run platform prerequisite preflight checks before updating inputs, installing packages, backing up files, or activating configuration.

- Keep managed tool names and GitHub release owners in `scripts/managed-tools.json`, consumed by JavaScript, Nix, and PowerShell.
  Preserve thin launchers and verify deployment against this inventory.
- Keep observation, pure decisions, and mutation separate in stateful logic.
  Use named timing constants with units and preserve unknown activity as distinct from idle.

- Keep post-activation verification aligned with the managed links, launcher syntax, Pi settings, tmux prefix, WezTerm configuration, and macOS symbolic hotkeys.
