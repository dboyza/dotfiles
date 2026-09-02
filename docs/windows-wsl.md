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
   It uses Winget to install or upgrade Windows WezTerm, installs Hack Nerd Font for the Windows user, and copies the tracked WezTerm configuration into the Windows profile.

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

Then rerun `./bootstrap.sh` inside WSL to refresh and verify the Windows configuration.
See [operations](operations.md) for non-mutating checks, testing, and recovery.
