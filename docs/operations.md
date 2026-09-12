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
Codex, Pi, opencode, and Herdr update independently at launch; bootstrap manages their launchers and runtime dependencies.

After activation, bootstrap verifies managed links, Pi settings, launcher syntax, the tmux prefix, WezTerm configuration, and platform integration.
The managed-file inventory comes from the evaluated Home Manager configuration, including its platform-specific files.
Add managed files in `nix/home.nix`; backup and verification discover them automatically.

tmux plugins are pinned Nix inputs and load directly from their managed paths.
Use bootstrap to update them along with other declared inputs.
Resurrect, assistant session restoration, and continuum remain enabled; TPM and tmux-yank are no longer needed.

## Update agent tools at launch

Launching `codex`, `pi`, `opencode`, or `herdr` checks the official release source for a newer stable version and installs it before starting the application.
The first launch requires an internet connection.
A failed check or installation falls back to the installed version, and concurrent launches coordinate through a per-tool update lock.
Installs live under `${XDG_DATA_HOME:-~/.local/share}/dotfiles/tools` on macOS and Linux, or `%LOCALAPPDATA%/dotfiles/tools` on native Windows.
Tool versions are outside Nix generations and are not changed by Nix rollback.

Skip updates for one launch when offline or diagnosing an issue:

```sh
DOTFILES_TOOL_UPDATE=0 codex
```

The bypass requires an existing managed installation.
Replace `codex` with `pi`, `opencode`, or `herdr` as needed.
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
