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
   Desktop apps are installed only when absent; activation does not update or replace existing versions.
   The inventory includes OpenSuperWhisper, Stats, and Strafe.
   Missing Strafe installations are built from checksum-verified, pinned source for Apple Silicon or Intel and require macOS 15+ and Apple's Swift 6.3+ toolchain.
   After its first installation, open `~/Applications/strafe.app`, grant Accessibility access in System Settings, then quit and reopen Strafe.
   Existing Strafe installations are skipped, preserving their signatures and permissions.
   Python 3.11, 3.12, 3.13, and 3.14 are installed through uv in your user account without upgrading existing runtimes or replacing executable links.
   Select a runtime with `uv run --python 3.12 python`, substituting the desired version.
   Homebrew continues to provide the default Python 3.14; an existing Python.org installation is left alone and is not recreated.

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

## Managed command-line tools

Homebrew installs the tools declared in `nix/homebrew.nix`, including Neovim, tmux, Git, Node.js, Python, and Terraform.
Terraform uses HashiCorp's official tap.
Homebrew also owns Zsh plugins and Hack Nerd Font; Nix retains the system configuration, activation dependencies, and tmux plugins.
macOS uses its built-in Zsh as the login shell so first activation does not depend on a Brew executable that has not been installed yet.
The `zsh` command in your interactive PATH comes from Homebrew.
Codex CLI, Claude Code, Pi, opencode, and Herdr use managed launchers in `~/.local/bin`, which takes precedence over Homebrew in Zsh.
Each launcher checks for updates and installs a new release before starting the tool, falling back to the installed version if an update fails.
See [agent-tool updates and migration](operations.md#update-agent-tools-at-launch) for storage paths, bypass controls, and manual update commands.
Existing credentials, settings, and sessions are preserved.

Run `brew update` and then `brew upgrade <package>` for package updates.
Activation installs missing packages without upgrading existing ones or removing other Homebrew packages.
The Mac App Store still handles Amphetamine through Homebrew's `mas`; Wallper retains its verified direct-download installer.

## Adrafinil activity polling

If Adrafinil misses agent hooks, install the optional per-user fallback after setting up the Adrafinil app:

```sh
python3 scripts/adrafinil-agent-poll.py --install
python3 scripts/adrafinil-agent-poll.py --dry-run
```

The LaunchAgent checks immediately at login and every 60 seconds while the Mac is awake, including when Adrafinil currently has no holds.
It recognizes Codex's `Codex is running an active turn` macOS power assertion and Claude Code's `busy` records in `~/.claude/sessions/<pid>.json`, checking that each PID still belongs to the current user's agent process.
Idle sessions, Claude approval prompts, helper processes, and stale session files do not acquire a polling hold.
Native hooks remain the immediate path, and the poller releases its own `dotfiles-poll` holds when work ends.
The same minute check also removes native Codex and Claude hook or sniffed holds whose owning process has exited.
For Codex's shared background service, it reads the local thread index and recent rollout lifecycle records to distinguish completed, interrupted, or removed sessions from an active turn.
A missing session is eligible after one minute, while an unreadable index or incomplete transcript is treated as unknown.
For Claude, a matching session's idle status must be newer than the hook before that native hold is removed.
Native holds are rechecked before release so a newly refreshed turn or restarted daemon cancels a stale cleanup decision.
Each polling hold expires after three minutes unless renewed, and Adrafinil still controls pause, process-exit cleanup, and configured safety cutouts.
If Claude's status file is temporarily unreadable, an existing polling hold keeps its current expiry without renewal so one partial write cannot immediately drop it.
Manual holds, unrelated tools, and Claude's native waiting grace retain their own release policies.

This fallback depends on those activity signals: Codex sessions without an active-turn power assertion and Claude sessions using a custom configuration directory still rely on their hooks.
It does not wake an already sleeping Mac, and a missed start hook can leave a delay of up to one minute before detection.
The installed job points at this checkout and Homebrew's stable Python executable when available, falling back to Python on `PATH`; rerun the installer after moving the checkout or replacing that Python installation.
Inspect the last successful check in `~/.local/state/dotfiles/adrafinil-poll/status.json` and failures in the adjacent `error.log`.

To disable the fallback, unload and remove only its LaunchAgent:

```sh
launchctl bootout "gui/$(id -u)/com.dboyza.adrafinil-agent-poll"
rm "$HOME/Library/LaunchAgents/com.dboyza.adrafinil-agent-poll.plist"
```

Its remaining holds expire within three minutes; other Adrafinil holds are unaffected.

## Managed desktop applications

Activation installs missing copies of Google Chrome, Visual Studio Code, BoringNotch, WezTerm, Wallper, and Amphetamine.
Existing apps are skipped regardless of version or whether they were installed with Homebrew or manually.
The installer checks `/Applications`, `~/Applications`, and their subfolders, and uses Spotlight bundle identifiers to find renamed apps or apps installed elsewhere.
Unindexed apps outside those folders cannot be discovered automatically; move them into an Applications folder before activation if needed.
No version checks, downloads, adoption, or upgrades run for an app that is found.
Homebrew automatic updates, activation upgrades, and installation cleanup are disabled for this workflow.
Apps may still update themselves according to their own preferences.

The inventory lives in `nix/macos-apps.json`, and `scripts/install-macos-apps.py` runs as the primary user during nix-darwin activation.
Missing Chrome, VS Code, BoringNotch, and WezTerm apps install through Homebrew into `~/Applications`.
[Amphetamine](https://apps.apple.com/us/app/amphetamine/id937984704) installs through the Mac App Store using the Homebrew-provided `mas` CLI and app ID `937984704`.
Sign in to the App Store on a new Mac before activation; macOS may prompt for authentication or administrator permission when installing it.
An existing Amphetamine installation skips all App Store commands, regardless of version.
The installer never runs App Store updates.
BoringNotch uses its [developer-maintained tap](https://github.com/TheBoredTeam/boring.notch#installation); its upstream cask removes quarantine from the newly installed bundle.
Missing Wallper installs from a checksum-pinned [official release](https://github.com/alxndlk/wallper-app/releases) into `~/Applications/Wallper.app` after signature verification.
That installer supports Intel and Apple Silicon and requires macOS 14.6 or later.
The pinned Wallper version only applies to a missing-app installation; changing the manifest does not replace an existing copy.
If an older configuration installed Wallper under `/Applications/Nix Apps`, activation preserves that exact version in `~/Applications` before nix-darwin cleans its old managed directory.
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
- `Command+H` and `Command+L` also send Home and End; `Command+Up` and `Command+Down` send Control+Home and Control+End for Neovim file navigation.
- `Fn+Left` and `Fn+Right` provide the same Home and End keys on a MacBook keyboard.
- `Command+C` to copy selected terminal text.
- `Command+V` to paste text or attach a clipboard screenshot in Codex, including inside tmux.
  Image-only clipboards send `Control+V` to the application; text and copied file paths use normal terminal paste.
  `Control+Shift+V` remains available for text-only paste.

The WezTerm prefix is `Control+Shift+Space`, the tmux prefix is `Control+G`, and the Herdr prefix is `Control+A`.
See the [shared keyboard guide](keybindings.md) for pane controls and application shortcuts.
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

## Floating WezTerm tabs

The native `WezTerm Floating Tabs` companion places clickable tab numbers above each visible WezTerm window, straddling its lavender border, with the clock centered above the same window.
The + button after the last tab creates a new tab using the same action as `Control+Shift+T`.
The one-pixel border dims on inactive windows, while the active tab keeps its lavender fill beside subdued inactive badges and a smaller translucent 12-hour clock with AM/PM.
The badges follow window moves and resizes without taking keyboard focus.
Focused-window overlays stay above terminal clicks; background overlays retain their window stacking order.
Small click-through corner overlays complete the lavender outline where macOS clips WezTerm’s rectangular border.
Other applications do not get overlays.

macOS activation builds the helper from `wezterm/floating-tabs/main.swift` using Apple's Command Line Tools and installs it into `~/Applications/WezTerm Floating Tabs.app`.
To install or update it without activating the rest of the dotfiles, run:

```sh
./scripts/install-wezterm-floating-tabs.sh
open -g "$HOME/Applications/WezTerm Floating Tabs.app"
```

Allow **WezTerm Floating Tabs** in **System Settings > Privacy & Security > Accessibility** when prompted.
The helper needs this permission to identify and follow WezTerm windows.
It does not need Screen Recording permission and does not read terminal text.
After installing, reload the WezTerm configuration or restart WezTerm; subsequent GUI sessions start the helper automatically.
Rebuilding a locally signed app may require granting Accessibility access again.
An enabled switch can still refer to an older build's code signature; toggling it may not replace that stale record.
Quit the helper in Activity Monitor, reset only its permission, and relaunch it:

```sh
tccutil reset Accessibility com.dboyza.wezterm-floating-tabs
open -g "$HOME/Applications/WezTerm Floating Tabs.app"
```

Enable the new Accessibility entry when prompted.
This does not reset permissions for any other application.
The grant remains manual; neither activation nor WezTerm startup changes macOS permissions.
WezTerm launches the installed helper once when the first window in a new GUI process updates its status, so no separate login item is needed.

Click a number to focus its window and switch tabs, or keep using the existing terminal shortcuts.
The clock hides when tabs need its space; crowded tab strips can scroll horizontally.
The helper uses the native tab bar when another application is focused, a window enters fullscreen, or it sits too close to the menu bar for external badges.
If the helper quits or permission is revoked, the native tab bar returns within a few seconds.
To stop the helper for the current WezTerm session, quit `wezterm-floating-tabs` in Activity Monitor.
Windows has a [native companion](windows-wsl.md#floating-wezterm-tabs-and-clock), including when displaying WSL sessions.
Linux GUI WezTerm retains its native numbered tabs and clock.

The private `~/.local/state/dotfiles/wezterm-floating-tabs` directory contains separate snapshots, acknowledgments, and click requests for each window, identified by GUI process and window ID.
Closed-window snapshots expire and are cleaned up after 30 seconds.
Window titles include an opaque identity so the companion never attaches another WezTerm process's tabs to the wrong window.
It does not collect command lines, working directories, terminal contents, or session history.
Run `./tests/wezterm-floating-tabs.sh` on macOS to check the native layout and the real WezTerm bridge in an isolated fixture home.
