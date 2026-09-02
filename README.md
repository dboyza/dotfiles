# dotfiles

This repository recreates the same terminal and editor environment on Ubuntu, Windows 11 with WSL, and macOS.
One bootstrap command installs the configured tools, activates tracked configuration, and verifies the result.

Sections:

- [Quick Start](#quick-start)
- [What the Setup Manages](#what-the-setup-manages)
- [Common Workflows](#common-workflows)
- [Repository Layout](#repository-layout)
- [Platform Limitations](#platform-limitations)
- [Personal Data and Secrets](#personal-data-and-secrets)

## Quick Start

You need an internet connection and an account that can install software.
Run the installer as your normal user, not as `root`.
Existing managed files are moved to timestamped backups before activation.

Choose the complete guide for the computer you are configuring:

- [Ubuntu installation and use](docs/ubuntu.md)
- [Windows 11 with WSL installation and use](docs/windows-wsl.md)
- [macOS installation and use](docs/macos.md)

Each guide starts from a standard platform installation and ends with version checks in WezTerm.
Native Windows without WSL is not a complete installation target because the reproducible command-line environment requires Nix.

For an already prepared machine, the central workflow is:

```sh
git clone https://github.com/dboyza/dotfiles.git "$HOME/dotfiles"
cd "$HOME/dotfiles"
./bootstrap.sh
```

The preflight reports missing prerequisites before package updates or activation begin.
Leave the computer awake until the script prints `Bootstrap complete`.

## What the Setup Manages

The shared environment includes:

- Git, Zsh, tmux, Neovim, Starship, and Herdr.
- Pi, Codex, Claude Code, and opencode.
- ripgrep, fzf, bat, btop, jq, tree, curl, wget, DNS tools, and direnv.
- Node.js, uv, pre-commit, Make, ShellCheck, and shfmt.
- kubectl and Terraform.
- Hack Nerd Font and WezTerm.
- Shared coding-agent instructions, skills, and configuration.
- Pinned tmux plugin sources.

Linux desktop installations receive WezTerm, GCC, and common X11 and Wayland clipboard tools.
WSL receives Windows WezTerm, a Windows font installation, and UTF-8-safe Windows clipboard helpers.
macOS receives WezTerm through Homebrew and system integration through nix-darwin.
opencode is omitted on Intel macOS because its upstream package does not support that platform.

Pi includes the local Calm extension, terminal-title status, model overrides, and the Rose Pine Moon theme.
Its settings declare pinned web-access, Codex fast-mode, and OpenAI server-compaction packages.
The server-compaction extension is experimental and sends relevant compaction and continuity data to OpenAI.

## Common Workflows

Read [checks, updates, testing, and recovery](docs/operations.md) before changing or repairing an installation.

To validate the pinned configuration without updating inputs or activating configuration, run:

```sh
cd "$HOME/dotfiles"
./bootstrap.sh --check
```

This command requires Nix to be installed already.

To update declared inputs and activate the configuration, run:

```sh
cd "$HOME/dotfiles"
./bootstrap.sh
```

The normal bootstrap is intentionally update-first across Nix inputs, Windows Winget packages, and macOS Homebrew packages.
It may change `flake.lock` and may upgrade existing Homebrew packages on macOS.

Run the complete local test suite with:

```sh
./tests/run.sh
```

## Repository Layout

| Path | Purpose |
| --- | --- |
| `bootstrap.sh` | Selects the platform and coordinates preflight, update, activation, and verification. |
| `scripts/lib/` | Contains shared, Linux, macOS, and WezTerm bootstrap functions. |
| `flake.nix` | Defines supported systems, packages, and platform profiles. |
| `flake.lock` | Pins Nix, Home Manager, nix-darwin, Herdr, and tmux plugin revisions. |
| `nix/home.nix` | Defines portable packages and managed home files. |
| `nix/darwin.nix` | Defines macOS settings, fonts, and Homebrew applications. |
| `nix/pi-coding-agent.nix` | Packages the pinned Pi npm release. |
| `agents/` | Stores shared coding-agent instructions and skills. |
| `pi/` | Stores Pi settings, model overrides, extensions, and themes. |
| `herdr/`, `nvim/`, `starship/`, `tmux/`, `wezterm/`, `zsh/` | Store application configuration. |
| `scripts/` | Contains WSL clipboard and Windows integration helpers. |
| `tests/` | Contains bootstrap, compatibility, platform evaluation, and integration checks. |

Add portable packages to `nix/home.nix`.
Add macOS-only settings or applications to `nix/darwin.nix`.
Run `./bootstrap.sh --check` before activating configuration changes.

## Platform Limitations

- Native Windows without WSL is only a host-integration target for WezTerm, fonts, PowerShell, and clipboard handling.
- A real Windows-to-WSL GUI and clipboard smoke test requires a Windows 11 machine.
- Apple ID data, App Store authentication, privacy permissions, and personal application data are not managed.
- Nixpkgs 26.05 is the final release supporting Intel macOS, so a future Nixpkgs upgrade may require removing that profile.
- Apple Silicon macOS receives local build and runtime validation in the primary development environment.
- Intel macOS and Linux profiles receive static Nix evaluation unless tested on matching hardware.

## Personal Data and Secrets

This repository manages intentional packages and configuration, not personal data or machine state.
It does not copy SSH keys, cloud credentials, browser profiles, project files, Apple ID data, or other secrets.
Pi authentication, trust decisions, package state, and session transcripts under `~/.pi/agent` remain untracked.
Store personal data and secrets in a separate encrypted backup.
