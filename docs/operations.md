# Checks, updates, testing, and recovery

Run shell commands in this guide from the repository directory inside Ubuntu, WSL, or macOS unless a step says otherwise.

```sh
cd "$HOME/dotfiles"
```

## Check without changing the installation

Run:

```sh
./bootstrap.sh --check
```

This command requires an existing Nix installation.
It evaluates and builds the pinned configuration without installing Nix, updating `flake.lock`, activating configuration, or replacing managed files.

Lazygit and Zoxide are installed through Homebrew on macOS and through Nix on Linux and WSL.
Run `lazygit` inside a Git checkout to open its terminal interface.
In Zsh, use `z <directory>` to jump to a frequently visited directory or `zi` for interactive selection with fzf.
Zoxide initializes in the tracked `zsh/.zshrc`; its directory history remains local runtime data.

## Update and activate

Run:

```sh
./bootstrap.sh
```

The command updates declared Nix package and plugin inputs, checks the result, and activates it.
It also installs or upgrades WezTerm through Winget on Windows.
On macOS, desktop apps are installed only when missing; existing versions are preserved.
The older `./bootstrap.sh --update` form is an alias for the same behavior.

An update may change `flake.lock`.
Review and commit that file when the refresh is intentional.
On every supported platform, Codex, Claude Code, Pi, opencode, and Herdr update independently at launch; bootstrap manages their launchers and runtime dependencies.

After activation, bootstrap verifies managed links, Pi settings, launcher syntax, the tmux prefix, WezTerm configuration, and platform integration.
The managed-file inventory comes from the evaluated Home Manager configuration, including its platform-specific files.
Add managed files in `nix/home.nix`; backup and verification discover them automatically.

tmux plugins are pinned Nix inputs and load directly from their managed paths.
Use bootstrap to update them along with other declared inputs.
Resurrect, assistant session restoration, and continuum remain enabled; TPM and tmux-yank are no longer needed.

## Update macOS packages

Homebrew owns macOS command-line dependencies, Zsh plugins, and Hack Nerd Font.
Their declarations live in `nix/homebrew.nix`; GUI app declarations remain in `nix/macos-apps.json` so existing installations can be preserved.
Bootstrap installs missing packages without upgrading existing installations or removing unlisted packages.
Update a Brew package explicitly with `brew update` followed by `brew upgrade <formula>`.
These versions are outside Nix generations and are not reverted by nix-darwin rollback.

Codex, Claude Code, Pi, opencode, and Herdr use the managed launchers instead of Homebrew.
After activation, open a new terminal so `~/.local/bin` takes precedence over Homebrew and older Nix packages.
Launch each tool once and verify it works before removing any old Brew installation.
Use `brew uninstall --formula herdr pi-coding-agent opencode` and `brew uninstall --cask codex claude-code` for the packages you still have installed.
Do not use `--zap`, which can remove application data.
Bootstrap intentionally does not uninstall existing Brew packages automatically.

## Update agent tools at launch

Launching `codex`, `claude`, `pi`, `opencode`, or `herdr` checks the official release source and installs a new release before starting the application.
This applies to macOS, Linux, WSL, and native Windows.
Codex, Pi, and opencode follow the latest stable GitHub release from their official repositories; Claude Code follows its native `latest` channel, and Herdr follows its stable release manifest.
Prerelease version identifiers are rejected.
Every download must match a SHA-256 checksum from the publisher: GitHub release asset digests for Codex, Pi, and opencode, or the official release manifest for Claude Code and Herdr.
Archive paths and file types are checked before extraction, and every new executable must pass a version check before becoming current.
Codex keeps its complete package, including code-mode, search, and platform helpers; Pi keeps its themes, native helpers, and other bundled runtime assets.
On x64 machines, opencode uses its baseline build for compatibility with older CPUs.
Pi standalone Linux builds require glibc, as provided by the supported Linux and WSL configurations.
The launchers own application updates, so Claude Code's internal updater is disabled for launched processes; use the commands below instead of `claude update` or `claude install`.
The official [Codex standalone instructions](https://learn.chatgpt.com/docs/codex/cli), [Pi releases](https://github.com/earendil-works/pi/releases), [opencode installation guide](https://opencode.ai/docs/), [Claude Code setup guide](https://code.claude.com/docs/en/setup), and [Herdr installation guide](https://herdr.dev/docs/install/) describe the upstream distributions.
Node.js runs the managed launchers, but application installation no longer uses npm.
Keep npm available for Pi extension packages or other development workflows that need it.

The first launch requires an internet connection.
A failed check or installation falls back to the installed version, including when GitHub rate-limits a release check.
Existing npm installations migrate on the next successful check even if the release version is unchanged; their old directories remain available as fallback.
`DOTFILES_TOOL_UPDATE=0` also postpones this migration.
Concurrent launches coordinate through a per-tool update lock; if another launch is already updating, an existing installation starts immediately.
Installs live under `${XDG_DATA_HOME:-~/.local/share}/dotfiles/tools` on macOS and Linux, or `%LOCALAPPDATA%/dotfiles/tools` on native Windows.
Previous version directories remain available so an update does not replace a running binary.
Tool versions are outside Nix generations and are not changed by Nix rollback.
Credentials, settings, and sessions stay in their existing application directories.

Skip updates for one launch when offline or diagnosing an issue:

```sh
DOTFILES_TOOL_UPDATE=0 codex
```

The bypass requires an existing managed installation.
Replace `codex` with `claude`, `pi`, `opencode`, or `herdr` as needed.
To prepare an installation or update without opening a session:

```sh
node scripts/dotfiles-tool.mjs --update-only codex
```

Pi's local extensions and pinned extension packages are independent of the Pi application version.
Check extension behavior after upgrades, especially the Calm extension's UI integrations.

## Run automated tests

Run:

```sh
./tests/run.sh
```

The suite checks bootstrap update, preflight, backup, and check-only behavior.
It exercises launch-time updates with isolated installations and mocked release sources.
It also checks WSL UTF-8 clipboard round trips, shell formatting and lint, JSON validity, WezTerm bindings, tmux, Neovim core mappings, PowerShell syntax when available, and every Nix platform evaluation.
Shared clipboard tests exercise provider selection and Unicode payloads, and isolated tmux tests check restoration plugin initialization and reloads.

## Recover managed files

Application configurations point at the live checkout, so Nix generation rollback does not roll back their contents.
Use Git to review and restore configuration changes.
Pi settings are backed up before their first conversion to a live symlink; later Pi writes affect `pi/settings.json` directly.
Credentials and sessions remain outside the checkout.

Before activation, bootstrap moves an existing managed file to a path such as `.zshrc.backup.20260712153000`.
Do not delete backups until the new setup works correctly.

On the first macOS activation, existing `/etc/bashrc` and `/etc/zshrc` files move to `.before-nix-darwin` backup names.
If a backup name exists, the new backup receives a timestamp suffix instead of overwriting it.

On Ubuntu or WSL, list Home Manager generations with:

```sh
home-manager generations
```

To restore one, copy its `/nix/store/...-home-manager-generation` path, append `/activate`, and run that complete path.

On macOS, roll back the latest nix-darwin generation with:

```sh
sudo darwin-rebuild --rollback
```

## Reclaim Nix storage

Remove unused Nix store paths with:

```sh
nix-collect-garbage
```

Review the command's output before using more aggressive garbage-collection options.
