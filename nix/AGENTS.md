# Nix maintenance instructions

- Keep Linux packages and shared managed home files in `nix/home.nix`, macOS user packages in `nix/homebrew.nix`, and macOS system configuration in `nix/darwin.nix`.

- Keep the macOS app inventory in `nix/macos-apps.json` and install missing apps through `scripts/install-macos-apps.py` during nix-darwin activation.
  Skip existing bundles regardless of version or installation source, including user Applications folders and renamed apps found by bundle ID.
  Do not enable Homebrew activation upgrades or put these apps in `environment.systemPackages`, which would replace them on activation.
  Verify direct downloads with pinned checksums and preserve legacy Nix Apps bundles before nix-darwin cleans that directory.
  Install missing App Store apps by ID with the Homebrew-provided `mas get`; keep existing-app detection ahead of all App Store commands and leave account authentication interactive.

- Keep curated macOS preferences in `system.defaults` in `nix/darwin.nix`.
  When capturing existing preferences, use supported options and explicit saved values; do not import account data, recent items, Dock application bookmarks, or window state.
  Removing a preference declaration does not reset its stored macOS value.

- Install Hack Nerd Font through Homebrew on macOS and through Home Manager on Linux so each platform has one font owner.

- On macOS, Homebrew owns the remaining user command-line packages and Node.js; keep Codex, Claude Code, Pi, opencode, and Herdr out of its package lists.
  Keep Homebrew activation install-only with no cleanup, resolve paths from `homebrew.prefix`, and use Brew's `mas` for App Store installation.
  Declare HashiCorp's Terraform tap as trusted for Homebrew 6 activation; do not disable tap-trust checks globally.
  Keep GNU make's `libexec/gnubin` and Brew curl/unzip paths in the macOS session PATH.
  Use Apple's `/bin/zsh` as the login shell so it is available before Homebrew's first activation.

- Keep the unused .NET test input removed from the pre-commit derivation so macOS checks do not build .NET, Swift, and LLVM.

- Deploy repository-authored home files through `mkOutOfStoreSymlink` using the absolute checkout path from `DOTFILES_REPO`.
  Keep tmux plugins and Linux Zsh plugins in the Nix store; macOS Zsh plugin links target Homebrew's stable share paths.
  Configuration edits require only application reloads; moving the checkout or changing Nix declarations requires activation.

- Build missing Strafe apps from the checksum-pinned source in `nix/macos-apps.json`, using the native Apple toolchain and host architecture.
  Preserve existing bundles and leave Accessibility authorization interactive.

- Install macOS Python 3.11–3.14 with user-owned uv runtimes during activation, without upgrades or executable-link replacement.
  Homebrew remains the default Python owner; do not add a duplicate Python.org installer.
