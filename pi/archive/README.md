# Archived Pi customizations

These files are retained for an explicitly requested customization, not deployed by Home Manager or enabled by `pi/settings.json`.
The active profile is described in [the defaults guide](../DEFAULTS.md).

Run the archived unit checks with `./tests/run.sh --archive` from the repository root.
The optional TUI smoke checks in `tests/pi-*-smoke.mjs` require an explicit Pi CLI path and their documented platform dependencies.
A passing unit check does not establish compatibility with the current Pi runtime.

Preserve the Calm license and the generated computer-use dependency lock.
Before reactivating packages, review [the package notes](PACKAGE-REVIEW.md) and confirm their pins and runtime behavior.
