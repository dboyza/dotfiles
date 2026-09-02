# Ubuntu installation and use

This guide installs the complete environment on Ubuntu Linux.
Run every command in this guide from the Ubuntu terminal.

## Install

1. Open the Terminal application.

2. Install Git.

   ```sh
   sudo apt-get update
   sudo apt-get install -y git
   ```

3. Clone the repository and enter it.

   ```sh
   git clone https://github.com/dboyza/dotfiles.git "$HOME/dotfiles"
   cd "$HOME/dotfiles"
   ```

4. Run the installer as your normal user.

   ```sh
   ./bootstrap.sh
   ```

   The preflight reports whether Nix must be installed before making changes.
   The script installs Nix when needed, Home Manager, the configured command-line tools, Hack Nerd Font, WezTerm, and tracked configuration.
   It may request confirmation or your password.

5. Close every Terminal window after the script prints `Bootstrap complete`.

6. Open WezTerm from the application menu.

   If WezTerm is not yet shown in the menu, open Terminal and run:

   ```sh
   wezterm
   ```

7. Verify the installation inside WezTerm.

   ```sh
   wezterm --version
   pi --version
   nvim --version
   tmux -V
   zsh --version
   ```

   Every command should print a version without an error.

## Use and update

Open WezTerm whenever you want to use the configured environment.

To download repository changes and activate the newest declared inputs, run:

```sh
cd "$HOME/dotfiles"
git pull --ff-only
./bootstrap.sh
```

To activate local repository changes, run:

```sh
cd "$HOME/dotfiles"
./bootstrap.sh
```

See [operations](operations.md) for non-mutating checks, testing, and recovery.
