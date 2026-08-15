# dotfiles

This repository recreates the same terminal and editor environment on Ubuntu, Windows 11 with WSL, and macOS.
One script installs Nix, installs the configured tools, and puts the tracked configuration files in the correct locations.

Sections:

- [Read This First](#read-this-first)
- [Ubuntu Linux](#ubuntu-linux)
  - [Install on Ubuntu](#install-on-ubuntu)
  - [Use on Ubuntu](#use-on-ubuntu)
- [Windows 11 with WSL](#windows-11-with-wsl)
  - [Install on Windows 11 with WSL](#install-on-windows-11-with-wsl)
  - [Use on Windows 11 with WSL](#use-on-windows-11-with-wsl)
- [macOS](#macos)
  - [Install on macOS](#install-on-macos)
  - [Use on macOS](#use-on-macos)
- [Native Windows Without WSL](#native-windows-without-wsl)
- [Safe Checks and Updates](#safe-checks-and-updates)
  - [Automated compatibility checks](#automated-compatibility-checks)
- [Recovery](#recovery)
- [Troubleshooting](#troubleshooting)
  - [The Repository Directory Already Exists](#the-repository-directory-already-exists)
  - [A Password Does Not Appear While Typing](#a-password-does-not-appear-while-typing)
  - [A Command Is Missing After Installation](#a-command-is-missing-after-installation)
  - [WSL Cannot Find Winget](#wsl-cannot-find-winget)
  - [WezTerm Does Not Open Ubuntu on Windows](#wezterm-does-not-open-ubuntu-on-windows)
  - [WezTerm Uses the Wrong Font](#wezterm-uses-the-wrong-font)
  - [The First Neovim Launch Takes Time](#the-first-neovim-launch-takes-time)
- [What the Setup Manages](#what-the-setup-manages)
  - [Pi customizations](#pi-customizations)
- [Repository Layout](#repository-layout)
- [Platform Limitations](#platform-limitations)
- [Personal Data and Secrets](#personal-data-and-secrets)

## Read This First

- You need an internet connection and an account that can install software.
- Run the commands as your normal user, not as `root`.
- Copy one code block at a time, paste it into the named window, and press Enter.
- Commands and file names are case-sensitive.
- A password prompt may look frozen while you type because Linux and macOS do not display password characters.
- Type your password anyway, then press Enter.
- Existing managed configuration files are moved to files ending in `.backup.<timestamp>` before they are replaced.
- On macOS, pre-existing `/etc/bashrc` and `/etc/zshrc` files are preserved with `.before-nix-darwin` backup names before nix-darwin takes ownership of them.
- Leave the computer awake until the script prints `Bootstrap complete`.

The examples clone the repository into `$HOME/dotfiles` for simplicity.
You may use any directory, but substitute your chosen location whenever the instructions use `$HOME/dotfiles`.

Choose exactly one installation section below.

## Ubuntu Linux

### Install on Ubuntu

1. Open the Terminal application.

   Open the application menu, search for `Terminal`, and select it.

2. Install Git.

   Paste these commands into Terminal:

   ```sh
   sudo apt-get update
   sudo apt-get install -y git
   ```

3. Download this repository.

   Paste these commands into the same Terminal window:

   ```sh
   git clone https://github.com/dboyza/dotfiles.git "$HOME/dotfiles"
   cd "$HOME/dotfiles"
   ```

4. Run the installer.

   ```sh
   ./bootstrap.sh
   ```

   The script installs Nix, all configured command-line tools, Home Manager, Hack Nerd Font, WezTerm, and the tracked configuration files.
   The Nix installer may ask for confirmation or your password.
   Follow its prompts and allow the installation to finish.

5. Start the new environment.

   Close every Terminal window after the script finishes.
   Open WezTerm from the application menu.
   If WezTerm is not shown in the menu yet, open Terminal and run:

   ```sh
   wezterm
   ```

6. Verify the installation inside WezTerm.

   ```sh
   wezterm --version
   pi --version
   nvim --version
   tmux -V
   zsh --version
   ```

   Each command should print a version and return to the prompt without an error.

### Use on Ubuntu

Open WezTerm whenever you want to use the configured environment.

To download repository changes and apply them, run these commands inside WezTerm:

```sh
cd "$HOME/dotfiles"
git pull --ff-only
./bootstrap.sh
```

To apply changes that you made locally in this repository, run:

```sh
cd "$HOME/dotfiles"
./bootstrap.sh
```

## Windows 11 with WSL

WSL runs Ubuntu inside Windows.
Windows PowerShell and the Ubuntu terminal are different environments, so use the window named in each step.

### Install on Windows 11 with WSL

1. Install WSL and Ubuntu from Windows PowerShell.

   Open the Start menu and type `PowerShell`.
   Right-click Windows PowerShell and select **Run as administrator**.
   Select **Yes** if Windows asks for permission.
   Paste this command into the Administrator PowerShell window:

   ```powershell
   wsl --install
   ```

   Restart the computer if Windows tells you to restart.
   This is the [official Microsoft WSL installation method](https://learn.microsoft.com/windows/wsl/install).

2. Create the Ubuntu user account.

   After the restart, open the Start menu, search for `Ubuntu`, and open it.
   Wait while Ubuntu completes its first-time setup.
   Enter the Linux username and password that you want to use when prompted.
   The password will remain invisible while you type it.
   This Linux account is separate from your Windows account.

3. Confirm that Winget is available in Windows.

   Open a regular Windows PowerShell window from the Start menu.
   Administrator access is not needed for this step.
   Run:

   ```powershell
   winget --version
   ```

   Continue if the command prints a version number.
   If Windows says that `winget` is not recognized, install or update **App Installer** from the Microsoft Store, then run the command again.

4. Confirm that Ubuntu can communicate with Windows.

   Return to the Ubuntu window.
   Do not run the next command in PowerShell.
   Run:

   ```sh
   powershell.exe -NoProfile -Command '$PSVersionTable.PSVersion'
   ```

   Continue if the command prints a PowerShell version.

5. Install Git inside Ubuntu.

   Run these commands in the Ubuntu window:

   ```sh
   sudo apt-get update
   sudo apt-get install -y git
   ```

6. Download this repository inside Ubuntu.

   Run these commands in the Ubuntu window:

   ```sh
   git clone https://github.com/dboyza/dotfiles.git "$HOME/dotfiles"
   cd "$HOME/dotfiles"
   ```

7. Run the installer inside Ubuntu.

   ```sh
   ./bootstrap.sh
   ```

   Never run `bootstrap.sh` from PowerShell or Command Prompt.
   The script installs Nix and the configured Linux tools inside Ubuntu.
   It also uses Winget to install WezTerm on Windows, installs Hack Nerd Font for your Windows account, and copies the tracked WezTerm configuration into your Windows profile.
   Follow any password or confirmation prompts and allow the script to finish.

8. Open the configured terminal.

   Close the original Ubuntu window after the script prints `Bootstrap complete`.
   Open the Windows Start menu, search for `WezTerm`, and open it.
   WezTerm should open Ubuntu automatically.

9. Verify the installation inside WezTerm.

   ```sh
   printf 'WSL is ready\n'
   pi --version
   nvim --version
   tmux -V
   zsh --version
   ```

   Each command should print text or a version and return to the prompt without an error.

### Use on Windows 11 with WSL

Open WezTerm from the Windows Start menu whenever you want to use the configured environment.
Run Linux commands inside the WezTerm window that opens Ubuntu.

To download repository changes and apply them, run these commands inside WezTerm:

```sh
cd "$HOME/dotfiles"
git pull --ff-only
./bootstrap.sh
```

To apply changes that you made locally in this repository, run:

```sh
cd "$HOME/dotfiles"
./bootstrap.sh
```

The `wezterm` command is not installed inside Ubuntu on WSL.
This is expected because the WezTerm application runs on Windows and connects to Ubuntu.

To update the Windows WezTerm application, open Windows PowerShell and run:

```powershell
winget upgrade --exact --id wez.wezterm
```

Then return to WezTerm and rerun `./bootstrap.sh` from the repository so the Windows configuration is refreshed.

## macOS

### Install on macOS

1. Open Terminal.

   Press Command and Space together to open Spotlight Search.
   Type `Terminal`, then press Return.

2. Install Apple's Command Line Tools.

   Paste this command into Terminal:

   ```sh
   xcode-select --install
   ```

   Select **Install** in the window that appears and wait for it to finish.
   If macOS says the tools are already installed, continue to the next step.

3. Confirm that Git is available.

   ```sh
   git --version
   ```

   Continue if the command prints a version number.

4. Download this repository.

   Paste these commands into Terminal:

   ```sh
   git clone https://github.com/dboyza/dotfiles.git "$HOME/dotfiles"
   cd "$HOME/dotfiles"
   ```

5. Run the installer.

   ```sh
   ./bootstrap.sh
   ```

   The script installs Nix, Homebrew when needed, nix-darwin, Home Manager, all configured command-line tools, Hack Nerd Font, WezTerm, and the tracked configuration files.
   The installers may ask for your macOS password or confirmation.
   Follow their prompts and allow the installation to finish.

6. Start the new environment.

   Close every Terminal window after the script prints `Bootstrap complete`.
   Press Command and Space, type `WezTerm`, then press Return.
   You can also open WezTerm from the Applications folder.

7. Verify the installation inside WezTerm.

   ```sh
   wezterm --version
   pi --version
   nvim --version
   tmux -V
   zsh --version
   ```

   Each command should print a version and return to the prompt without an error.

### Use on macOS

Open WezTerm from Spotlight or the Applications folder whenever you want to use the configured environment.
The configuration disables the `Control+Arrow` keyboard shortcuts for Mission Control, Application Windows, and moving between Spaces so those keys reach terminal applications.
The Mission Control key, trackpad gestures, and other macOS shortcuts remain available.
On a MacBook keyboard, use `Command+Shift+Up` and `Command+Shift+Down` as Page Up and Page Down.
Use `Command+Option+Up` and `Command+Option+Down` as Control+Page Up and Control+Page Down.
Use `Command+C` and `Command+V` for clipboard operations.
The tmux prefix is `Control+G`, while the Herdr prefix remains `Control+A`.

To download repository changes and apply them, run these commands inside WezTerm:

```sh
cd "$HOME/dotfiles"
git pull --ff-only
./bootstrap.sh
```

To apply changes that you made locally in this repository, run:

```sh
cd "$HOME/dotfiles"
./bootstrap.sh
```

To update the macOS WezTerm application, run:

```sh
brew upgrade --cask wezterm
```

## Native Windows Without WSL

The reproducible command-line environment requires Nix and is not provisioned in a PowerShell-only or Command Prompt-only Windows environment.
Follow the **Windows 11 with WSL** section above for the complete setup.
Native Windows remains a supported host-integration target for WezTerm, fonts, PowerShell 7 with a Windows PowerShell 5.1 fallback, and the Windows side of WSL clipboard handling.
The bootstrap process installs those Windows components from WSL and verifies the copied WezTerm configuration by SHA256.

## Safe Checks and Updates

Run all commands in this section from the repository directory inside Ubuntu, WSL, or macOS.

Change to that directory first:

```sh
cd "$HOME/dotfiles"
```

Check that the configuration can build without activating it:

```sh
./bootstrap.sh --check
```

If Nix is not installed yet, this check installs Nix first.
It builds the configuration but does not replace or activate the managed configuration files.

Apply the current repository configuration:

```sh
./bootstrap.sh
```

The command refreshes the declared Nix package and plugin sources, checks the result, and activates the newest available versions.
It also installs or upgrades WezTerm through Winget on Windows or Homebrew on macOS.
The command is safe to rerun, and an update may change `flake.lock`.
After activation, it verifies the managed Nix-store links, Pi settings and version, the tmux prefix, the WezTerm configuration, and the macOS Control+Arrow shortcut state where applicable.

The older explicit update form remains available as an alias for the same behavior:

```sh
./bootstrap.sh --update
```

Review and commit `flake.lock` when a refresh is intentional.
Packages with an explicit version in the repository remain at that version until the declaration is changed.
This preserves reproducibility for software that needs packaging fixes or compatibility constraints.

### Automated compatibility checks

Run the complete local test suite with:

```sh
./tests/run.sh
```

The suite checks bootstrap update and backup behavior, WSL UTF-8 clipboard round trips, shell formatting and lint, JSON validity, rendered WezTerm Control+Arrow bindings, an isolated tmux server, Neovim core mappings, PowerShell syntax when PowerShell is available, and every Nix platform evaluation.

Remove unused Nix store files when disk space is needed:

```sh
nix-collect-garbage
```

## Recovery

The installer moves an existing managed file to a backup with a name such as `.zshrc.backup.20260712153000` before replacing it.
Do not delete those backups until the new setup works correctly.

On the first macOS activation, the installer similarly moves pre-existing system shell files to `/etc/bashrc.before-nix-darwin` and `/etc/zshrc.before-nix-darwin`.
If either backup name is already occupied, the new backup receives a timestamp suffix so earlier contents are not overwritten.

On Ubuntu or WSL, show older Home Manager generations with:

```sh
home-manager generations
```

To restore one, copy the desired `/nix/store/...-home-manager-generation` path from the output, add `/activate`, and run that complete path as a command.

On macOS, roll back the latest nix-darwin change with:

```sh
sudo darwin-rebuild --rollback
```

## Troubleshooting

### The Repository Directory Already Exists

Do not run `git clone` again.
Enter the existing directory and run the installer:

```sh
cd "$HOME/dotfiles"
./bootstrap.sh
```

### A Password Does Not Appear While Typing

This is normal in Linux and macOS password prompts.
Type the password carefully and press Enter.

### A Command Is Missing After Installation

Close every terminal window, open WezTerm, and try the command again.
If it is still missing, enter the repository and rerun the installer:

```sh
cd "$HOME/dotfiles"
./bootstrap.sh
```

### WSL Cannot Find Winget

Open the Microsoft Store in Windows and install or update **App Installer**.
Open a new PowerShell window and confirm that `winget --version` works, then rerun `./bootstrap.sh` inside Ubuntu.

### WezTerm Does Not Open Ubuntu on Windows

Open Windows PowerShell and run:

```powershell
wsl --list --verbose
```

Start Ubuntu once from the Start menu if it is not running correctly.
Then rerun `./bootstrap.sh` inside Ubuntu and restart WezTerm.

### WezTerm Uses the Wrong Font

Rerun `./bootstrap.sh`, close every WezTerm window, and open WezTerm again.

### The First Neovim Launch Takes Time

Neovim downloads `lazy.nvim`, plugins, Mason tools, and Treesitter parsers on its first launch.
Keep the network connected and allow it to finish.
Run `:Lazy sync` or `:Mason` inside Neovim if a download needs to be retried.

## What the Setup Manages

The shared environment includes:

- Git, zsh, tmux, Neovim, Starship, and Herdr.
- Pi, Codex, Claude Code, and opencode.
- Shared agent instructions and skills, plus Pi settings, model overrides, extensions, and the Rosé Pine Moon theme.
- ripgrep, fzf, bat, btop, jq, tree, curl, wget, DNS tools, and direnv.
- Node.js, uv, pre-commit, GCC on Linux, Make, ShellCheck, and shfmt.
- kubectl and Terraform.
- Hack Nerd Font.
- Neovim, tmux, WezTerm, Starship, Herdr, and coding-agent configuration.
- Pinned tmux plugin sources.

Linux desktop installations receive WezTerm and common X11 and Wayland clipboard tools.
WSL receives Windows WezTerm plus UTF-8-safe Windows clipboard helpers.
macOS receives WezTerm through Homebrew and system integration through nix-darwin.

### Pi customizations

Run `/calm` to toggle the local Calm presentation mode for the current Pi installation.
Calm is off by default, hides built-in tool shells and collapsed thinking while enabled, and replaces the working row with a compact animated status widget.
It does not alter prompts, tool execution, model context, session data, exports, or shared transcripts.
Its preference is stored in the unmanaged `~/.pi/agent/calm` runtime file.

The terminal-title extension shows a spinner while Pi is working and a completion mark when it finishes.
The model overrides raise the context window for the configured Codex models without selecting a default provider or model.

Pi installs the pinned `pi-web-access`, Codex fast mode, and OpenAI server-compaction packages declared in `settings.json`.
The server-compaction extension is experimental and sends the relevant compaction and continuity data to OpenAI.
Third-party package code and package state remain in Pi's unmanaged runtime directories rather than this repository.

## Repository Layout

| Path | Purpose |
| --- | --- |
| `bootstrap.sh` | Installs, activates, and verifies the setup. |
| `flake.nix` | Defines supported systems and platform profiles. |
| `flake.lock` | Pins exact Nix, Home Manager, nix-darwin, Herdr, and tmux plugin revisions. |
| `nix/home.nix` | Defines shared packages and home files. |
| `nix/pi-coding-agent.nix` | Pins and packages Pi from its published npm release. |
| `nix/darwin.nix` | Defines macOS system settings, fonts, and Homebrew applications. |
| `agents/global/AGENTS.md` | Stores shared coding-agent instructions. |
| `agents/skills/` | Stores portable skills shared through `~/.agents/skills`. |
| `pi/` | Stores Pi settings, model overrides, extensions, and themes. |
| `herdr/config.toml` | Configures Herdr. |
| `nvim/` | Configures Neovim and pins its plugins. |
| `scripts/` | Contains WSL clipboard and Windows integration helpers. |
| `starship/starship.toml` | Configures the shell prompt. |
| `tmux/.tmux.conf` | Configures tmux. |
| `wezterm/.wezterm.lua` | Configures WezTerm across all supported platforms. |
| `zsh/` | Configures the shell. |

Add portable packages to `nix/home.nix`.
Add macOS-only settings or applications to `nix/darwin.nix`.
Run `./bootstrap.sh --check` before applying configuration changes.

## Platform Limitations

- Native Windows without WSL is not provisioned by Nix.
- The local suite validates WSL profile evaluation and mocked UTF-8 interoperation, but a real Windows-to-WSL GUI and clipboard smoke test still requires a Windows 11 machine.
- Apple ID data, App Store authentication, privacy permissions, and personal application data are not managed.
- The upstream opencode package does not support Intel macOS, so opencode is omitted on Intel Macs.
- Nixpkgs 26.05 is the final release supporting Intel macOS, so a future Nixpkgs upgrade may require removing the Intel profile.
- Apple Silicon macOS receives local build and runtime validation.
- Intel macOS and the Linux profiles receive static Nix evaluation unless they are checked on their native platforms manually.

## Personal Data and Secrets

This repository manages intentional packages and configuration, not personal data or machine state.
It does not copy SSH keys, cloud credentials, browser profiles, project files, Apple ID data, or other secrets.
Pi authentication, trust decisions, package state, and session transcripts under `~/.pi/agent` remain untracked.
Store those items in a separate encrypted backup.
