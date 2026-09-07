# Windows 11 with WSL installation and use

WSL runs Ubuntu inside Windows.
Windows PowerShell and the Ubuntu terminal are different environments, so each step names the correct window.

## Install WSL and prerequisites

1. Open Windows PowerShell as Administrator and install WSL with Ubuntu.

   ```powershell
   wsl --install
   ```

   Restart Windows if requested.
   This is the [official Microsoft WSL installation method](https://learn.microsoft.com/windows/wsl/install).

2. Open Ubuntu from the Start menu and complete its first-time setup.

   Create the Linux username and password you want to use.
   This account is separate from your Windows account.

3. Open a regular Windows PowerShell window and confirm that Winget is available.

   ```powershell
   winget --version
   ```

   If `winget` is not recognized, install or update App Installer from the Microsoft Store.

4. Return to Ubuntu and confirm that WSL can communicate with Windows.

   ```sh
   powershell.exe -NoProfile -Command '$PSVersionTable.PSVersion'
   ```

   Continue when the command prints a PowerShell version.

## Install the environment

1. In Ubuntu, install Git.

   ```sh
   sudo apt-get update
   sudo apt-get install -y git
   ```

2. In Ubuntu, clone the repository and enter it.

   ```sh
   git clone https://github.com/dboyza/dotfiles.git "$HOME/dotfiles"
   cd "$HOME/dotfiles"
   ```

3. Run the installer inside Ubuntu, never from PowerShell or Command Prompt.

   ```sh
   ./bootstrap.sh
   ```

   The preflight verifies Windows interoperability before package updates begin.
   The script installs Nix and the configured Linux tools inside Ubuntu.
   It uses Winget to install or upgrade Windows WezTerm, installs Hack Nerd Font for the Windows user, and installs a WezTerm loader in the Windows profile that reads the live checkout.

4. Close the original Ubuntu window after the script prints `Bootstrap complete`.

5. Open WezTerm from the Windows Start menu.

   WezTerm should open Ubuntu automatically.

6. Verify the installation inside WezTerm.

   ```sh
   printf 'WSL is ready\n'
   pi --version
   nvim --version
   tmux -V
   zsh --version
   ```

## Use and update

Edit application configuration directly in the checkout, then reload the application.
Codex, Pi, opencode, and Herdr update when launched.
Bootstrap is needed for other Nix packages, system settings, new managed paths, or a moved checkout.

Open WezTerm from the Windows Start menu and run Linux commands in the Ubuntu session.

To download changes and activate them, run inside WezTerm:

```sh
cd "$HOME/dotfiles"
git pull --ff-only
./bootstrap.sh
```

The `wezterm` command is not installed inside Ubuntu on WSL because WezTerm runs on Windows.

To update only Windows WezTerm, run this command in Windows PowerShell:

```powershell
winget upgrade --exact --id wez.wezterm
```

The loader continues to read the checkout after a WezTerm upgrade.
On WSL, the selected distribution must remain available for Windows WezTerm to read that configuration.
If automatic reload misses an edit across the WSL filesystem, reload WezTerm with `Ctrl+Shift+R`.
See [operations](operations.md) for non-mutating checks, testing, and recovery.

## Optional native Windows agent tools

WSL already receives the four launchers through bootstrap.
To also run Codex, Pi, opencode, and Herdr directly in Windows, install separate native launchers.
This does not install the complete Nix-managed environment or copy WSL credentials and configuration.

In a regular Windows PowerShell window, install Node.js LTS with npm:

```powershell
winget install --exact --id OpenJS.NodeJS.LTS
```

Reopen PowerShell, enter the repository directory, and run:

```powershell
.\scripts\install-windows-tools.ps1
```

The installer requires Node.js 22.19 or newer.
It adds launchers to `%USERPROFILE%\.local\bin`, preserves existing unmanaged launchers in backups, and adds the directory to your user PATH.
Keep the checkout at the same location, or rerun the installer after moving it.
Reopen your terminal, then launch `codex`, `pi`, `opencode`, or `herdr`.
Each command installs or updates its native application before starting it.
Native installations live under `%LOCALAPPDATA%\dotfiles\tools` and are independent of WSL installations.

To bypass update checks in the current PowerShell session after a tool has been installed:

```powershell
$env:DOTFILES_TOOL_UPDATE = "0"
codex
Remove-Item Env:DOTFILES_TOOL_UPDATE
```
