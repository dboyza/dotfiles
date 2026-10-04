# Pi maintenance instructions

- Keep reproducible, non-secret Pi configuration in `pi/` and symlink its `settings.json` directly into the checkout.
  Pi may write runtime settings into that file; review these changes before committing.
  Never track Pi authentication, trust decisions, package state, or session transcripts.

- Pi currently uses factory settings: do not redeploy archived extensions, themes, or model overrides without an explicit request.
  See `pi/DEFAULTS.md`; keep credentials, sessions, and shared instructions outside resets.

- Preserve the archived Pi Calm extension's bundled license and never manage or track its runtime preference file.
  Pi updates independently, so treat extension compatibility as a runtime check rather than pinning the whole application.

- If third-party Pi packages are reenabled, pin them to immutable npm versions or Git commits in `pi/settings.json`.

- If Pi footer customization is requested again, use `pi/archive/extensions/codex-statusline`, not installed package patches.
  Recheck its isolated adapter-reader integration when updating Codex Conversion, and preserve cache diagnostics and error statuses.
  Keep Codex Conversion's configuration runtime-owned because its atomic writer replaces symlinks; reproduce status-only diagnostics using the extension's setup instructions.
  `pi/archive/CODEX-UI.md` documents the archived Structured profile; standalone patch/image toggles take precedence over its saved execution mode on the Codex provider.

- Before changing third-party Pi package pins, review published artifacts and runtime dependencies, and keep npm lifecycle scripts disabled through Pi's `npmCommand` configuration.
  Restore its production-only and legacy-peer flags before installing packages so configured Git installs do not pull development dependencies or duplicate Pi runtimes.

- If Pi scrolling customization is requested again, use `pi/archive/extensions/scroll-sensitivity`, not global terminal preferences or installed package patches.
  Revalidate its guarded internal `wheelScrollLines` integration after Pi upgrades; fullscreen wheel handling precedes extension input listeners in Pi 0.85.1.

- Install the computer-use Python runtime from `pi/archive/computer-use/requirements.txt`, not the upstream requirements or postinstall hook.
  Regenerate its hash-locked dependencies with uv from `requirements.in`; do not edit generated requirements manually.
