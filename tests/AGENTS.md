# Tests maintenance instructions

- Keep `tests/run.sh` covering x86_64 and ARM64 Linux and macOS evaluation, native Windows PowerShell validation when PowerShell is available, and WSL profile and clipboard behavior.

- Require strict WezTerm option validation and explicit Lua verdicts with `tests/run-lua.lua` and `scripts/lib/check-wezterm.lua`; a process exit code alone can hide configuration failures.
- Keep the local runner's exit codes consistent: 77 is skipped/not applicable, 78 is unavailable, and other nonzero codes fail.
  Report missing optional subchecks with `UNAVAILABLE:` and use `--strict` when all prerequisites are required.
  Keep inactive Pi checks opt-in through `--archive`.
- Test observable behavior and failure recovery; avoid source-substring assertions when a function can be exercised directly.
