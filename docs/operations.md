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
It also installs or upgrades WezTerm through Winget on Windows or Homebrew on macOS.
The older `./bootstrap.sh --update` form is an alias for the same behavior.

An update may change `flake.lock`.
Review and commit that file when the refresh is intentional.
Packages with explicit versions remain pinned until their declarations change.

After activation, bootstrap verifies managed Nix-store links, Pi settings and version, the tmux prefix, WezTerm configuration, and platform integration.

## Run automated tests

Run:

```sh
./tests/run.sh
```

The suite checks bootstrap update, preflight, backup, and check-only behavior.
It also checks WSL UTF-8 clipboard round trips, shell formatting and lint, JSON validity, WezTerm bindings, tmux, Neovim core mappings, PowerShell syntax when available, and every Nix platform evaluation.

## Recover managed files

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
