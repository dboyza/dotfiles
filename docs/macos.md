# macOS installation and use

This guide installs the complete environment on Apple Silicon or Intel macOS.
Apple's Command Line Tools are required, but the full Xcode application is not.

## Install prerequisites

1. Open Terminal from Spotlight.

2. Check whether Command Line Tools are already selected.

   ```sh
   xcode-select -p
   ```

   A working command-line-tools-only installation normally prints `/Library/Developer/CommandLineTools`.
   A full Xcode selection normally prints `/Applications/Xcode.app/Contents/Developer`.

3. If the check reports an error, open Apple's installer.

   ```sh
   xcode-select --install
   ```

   Select **Install** in the macOS window and wait for it to finish.
   This installs Apple's developer command-line tools, not `/Applications/Xcode.app`.

4. Confirm that Git is available.

   ```sh
   git --version
   ```

## Install the environment

1. Clone the repository and enter it.

   ```sh
   git clone https://github.com/dboyza/dotfiles.git "$HOME/dotfiles"
   cd "$HOME/dotfiles"
   ```

2. Run the installer as your normal user.

   ```sh
   ./bootstrap.sh
   ```

   The preflight verifies Command Line Tools and reports whether Nix or Homebrew will be installed.
   No package update or system activation starts until that preflight succeeds.
   The script installs Nix, Homebrew when needed, nix-darwin, Home Manager, command-line tools, Hack Nerd Font, WezTerm, and tracked configuration.
   It may request your macOS password.
   Homebrew activation updates configured packages and may upgrade other packages already managed by Homebrew.

3. Close every Terminal window after the script prints `Bootstrap complete`.

4. Open WezTerm from Spotlight or the Applications folder.

5. Verify the installation inside WezTerm.

   ```sh
   wezterm --version
   pi --version
   nvim --version
   tmux -V
   zsh --version
   ```

## Use and update

Edit application configuration directly in the checkout, then reload the application.
Bootstrap is only needed for packages, system settings, new managed paths, or a moved checkout.

Open WezTerm whenever you want to use the configured environment.
The configuration disables only the macOS Mission Control and Spaces shortcuts that consume `Control+Arrow`.
The Mission Control key, trackpad gestures, and other macOS shortcuts remain available.

MacBook keyboard aliases include:

- `Command+Shift+Up` and `Command+Shift+Down` for Page Up and Page Down.
- `Command+Option+Up` and `Command+Option+Down` for Control+Page Up and Control+Page Down.
- `Option+Left` and `Option+Right` to move by a word.
- `Control+Left` and `Control+Right` also move by a word in Codex and Zsh once the macOS shortcuts are disabled.
- `Command+Left` and `Command+Right` for Home and End, moving to the beginning or end of the current line.
- `Fn+Left` and `Fn+Right` provide the same Home and End keys on a MacBook keyboard.
- `Command+C` to copy selected terminal text.
- `Command+V` to paste text or attach a clipboard screenshot in Codex, including inside tmux.
  Image-only clipboards send `Control+V` to the application; text and copied file paths use normal terminal paste.
  `Control+Shift+V` remains available for text-only paste.

The tmux prefix is `Control+G`, while the Herdr prefix is `Control+A`.
Plain `Control+V` passes through tmux so applications can handle their own image paste.

WezTerm reloads checkout edits automatically; `Control+Shift+R` also reloads its configuration.
In an existing tmux session, press `Control+G`, then `R` to reload its bindings.
Open a new shell to pick up Zsh changes.
If macOS still consumes `Control+Arrow`, disable Mission Control and Move left/right a space in System Settings > Keyboard > Keyboard Shortcuts > Mission Control, then log out and back in if needed.
Bootstrap also manages these shortcut preferences.

To download changes and activate them, run:

```sh
cd "$HOME/dotfiles"
git pull --ff-only
./bootstrap.sh
```

To update only WezTerm, run:

```sh
brew upgrade --cask wezterm
```

See [operations](operations.md) for non-mutating checks, testing, and recovery.
