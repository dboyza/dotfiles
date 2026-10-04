# Pi maintenance instructions

- Keep reproducible, non-secret Pi configuration in `pi/` and symlink its `settings.json` directly into the checkout.
  Pi may write runtime settings into that file; review these changes before committing.
  Never track Pi authentication, trust decisions, package state, or session transcripts.

- Treat `pi/settings.json` as the active configuration; inspect its current values before describing defaults, packages, or model choices.
  Earlier factory-reset descriptions are historical and do not override application-written preferences or later user choices.
  Keep `pi/archive/` customizations out of managed deployment links unless explicitly requested, and preserve credentials, sessions, and shared instructions during resets.

- Preserve the archived Pi Calm extension's bundled license and never manage or track its runtime preference file.
  Pi updates independently, so treat extension compatibility as a runtime check rather than pinning the whole application.

- When adding or updating third-party Pi packages, pin them to immutable npm versions or Git commits in `pi/settings.json`.
  Existing package entries are not evidence that their versions or compatibility have been reviewed.

- If Pi footer customization is requested again, use `pi/archive/extensions/codex-statusline`, not installed package patches.
  Recheck its isolated adapter-reader integration when updating Codex Conversion, and preserve cache diagnostics and error statuses.
  Keep Codex Conversion's configuration runtime-owned because its atomic writer replaces symlinks; reproduce status-only diagnostics using the extension's setup instructions.
  `pi/archive/CODEX-UI.md` documents the archived Structured profile; standalone patch/image toggles take precedence over its saved execution mode on the Codex provider.

- Before changing third-party Pi package pins, review published artifacts and runtime dependencies, and keep npm lifecycle scripts disabled through Pi's `npmCommand` configuration.
  Restore its production-only and legacy-peer flags before installing packages so configured Git installs do not pull development dependencies or duplicate Pi runtimes.

- If Pi scrolling customization is requested again, use `pi/archive/extensions/scroll-sensitivity`, not global terminal preferences or installed package patches.
  Revalidate its guarded internal `wheelScrollLines` integration after Pi upgrades; fullscreen wheel handling precedes extension input listeners in Pi 0.85.1.

- If the archived computer-use setup is explicitly reenabled, install its Python runtime from `pi/archive/computer-use/requirements.txt`, not the upstream requirements or postinstall hook.
  Regenerate its hash-locked dependencies with uv from `requirements.in`; do not edit generated requirements manually.
