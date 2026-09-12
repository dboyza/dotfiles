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

## Managed desktop applications

Activation installs Google Chrome, Visual Studio Code, BoringNotch, and WezTerm through Homebrew.
BoringNotch uses its [developer-maintained tap](https://github.com/TheBoredTeam/boring.notch#installation).
Its upstream cask removes quarantine from the installed BoringNotch bundle as part of installation.

Wallper is packaged from its [official release](https://github.com/alxndlk/wallper-app/releases) in `nix/packages/wallper.nix`, with a pinned version and SHA-256 checksum.
Nix-darwin installs it under `/Applications/Nix Apps/Wallper.app`.
The pinned release supports Intel and Apple Silicon and requires macOS 14.6 or later.
To update the reproducible Wallper installation, update its version and checksum together, then run `./bootstrap.sh --check` before activation.
Wallper updates made inside the application may be replaced by the pinned version on a later activation.
Existing manually installed copies in `/Applications` are not removed; use the managed copy to avoid launching an older duplicate.
App sign-in, licenses, wallpaper selection, and permissions remain interactive setup steps.

## Customize macOS preferences

Edit `system.defaults` in [`nix/darwin.nix`](../nix/darwin.nix) to manage macOS preferences as code.
The checked-in settings capture appearance, text input, Dock and Finder behavior, window management, widgets, menu-bar clock and battery percentage, mouse and trackpad behavior, guest login, automatic macOS updates, and Activity Monitor preferences.
Finder opens new windows in the home folder with list view, path and status bars, and folders sorted first.
The Dock hides automatically, omits recent apps, and uses its bottom-right hot corner for Quick Note.
Tap-to-click and three-finger dragging are disabled; two-finger secondary click is enabled.

Only explicitly declared preferences are managed.
Unspecified preferences, including keyboard repeat timing and extension visibility, retain their existing macOS values.
Dock app lists, recent items, account data, and window positions are not imported.
These declarations are scoped to nix-darwin and do not affect Windows or WSL.
See the [nix-darwin option reference](https://nix-darwin.github.io/nix-darwin/manual/) for supported settings and value types.

Validate the configuration from the repository root before applying changes:

```sh
./bootstrap.sh --check
```

Apply it with `./bootstrap.sh`.
Normal activation also updates packages and Nix inputs, as described below.
Some preferences require restarting the affected application or logging out and back in.
Changes made in System Settings to a managed preference are overwritten on the next activation.
Removing a declaration stops managing that preference; it does not restore its previous value.
To restore an earlier choice, use the option's supported value and activate again.
Some preferences use absence rather than an explicit opposite value: `AppleInterfaceStyle` accepts `"Dark"` or `null`, not `"Light"`.
To return to light appearance, remove that declaration or set it to `null`, then run `defaults delete -g AppleInterfaceStyle` if the key is present.

### Coverage and remaining manual settings

The preference review compares saved user and system values with the options in the pinned nix-darwin release, including relevant host-specific preferences.
It is not a complete export of every System Settings control.
An absent key does not prove a feature is disabled: macOS can supply defaults or store its state elsewhere.

| Area | Managed or remaining scope |
| --- | --- |
| Appearance and text input | Dark appearance, capitalization, and period substitution are managed; key repeat, extension visibility, and other unset options remain unmanaged. |
| Dock, Finder, and desktop | Saved supported view, sorting, hot-corner, and Dock behavior preferences are managed; app lists and per-folder window state remain unmanaged. |
| Windows and widgets | Saved Stage Manager, grouping, widget visibility, and tiling margin settings are managed. |
| Menu bar | Saved clock preferences and battery percentage are managed; the observed Now Playing value is outside the pinned option's supported mapping and is not converted. |
| Mouse and trackpad | Supported saved click, tracking, scrolling, and gesture settings are managed; device-specific driver settings remain unmanaged. |
| Keyboard and language | Existing Control+Arrow integration remains managed; the U.S. input source, language/region, dictation, text replacements, and other shortcuts are not imported. |
| Screenshots and Spaces | No explicit values for the supported options were found; existing behavior remains unmanaged. |
| Login and updates | Guest login is disabled and automatic macOS installation is enabled; account identities and update runtime state are not imported. |
| Activity Monitor | Opening its main window and showing My Processes are managed. |
| Power | AC sleep settings were inspected; battery-specific values were not available, so global sleep options are not used to extrapolate them. |
| Sound, accessibility, and lock screen | No explicit saved values were found for supported alert sound, cursor/motion/transparency/zoom, or screen-lock password timing options; these remain unmanaged. |
| Displays | Display state could not be read in the inspection environment; resolution, brightness, True Tone, and Night Shift require manual review. |
| Security | Firewall, Gatekeeper, and SIP status were inspected without importing policy; FileVault status could not be determined and requires manual review. |
| Privacy, accounts, and services | Apple Account, iCloud, Touch ID, app permissions, network credentials, Bluetooth pairing, Focus, notifications, Screen Time, Siri, and Apple Intelligence are not cloned by this configuration. |
| Wallpaper and third-party apps | Wallpaper assets and application-specific preferences require separate portable configuration. |

Keep new declarations limited to settings with verified meaning and supported values.
Use System Settings to review the remaining areas on a new Mac; do not treat this configuration as a full machine backup.

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
