# Compact Codex statusline

The main row follows the supplied reference: model and reasoning, home-relative directory, weekly quota remaining, Fast on/off, and Git branch.
The footer uses the reference's gold, green, pink, purple, and muted foreground colors without changing the transcript theme.
Cache diagnostics and other extension warnings appear on separate rows.
Long paths shrink before the other fields, and every row respects terminal-cell width.

The extension is archived and not deployed by the [factory-default profile](../../DEFAULTS.md).
If explicitly reenabled, run `/reload` after changing it.
Use `/statusline` to toggle the standard Pi footer back on for token totals and context usage.
The toggle lasts for the current extension lifetime; reloading restores the compact footer.
`/session` remains available for session statistics.

## Cache diagnostics

In `/codex openai`, set **Cache diagnostics** to **Status**, not **Status + log**.
This corresponds to `openai.cacheDiagnostics: "status"` in `~/.pi/agent/pi-codex-conversion.json`.
Leave cached WebSockets enabled and keep the tool set and instructions stable within a task.
Transport continuation and prompt-cache hits are separate measurements.
The footer displays only the diagnostic status reported by the adapter; it does not infer a hit from a WebSocket connection.

The adapter configuration stays runtime-owned rather than symlinked into this repository because its atomic writer replaces the destination symlink.
The setup instruction above reproduces the status-only setting without capturing voice device preferences or overwriting other adapter settings.

## Adapter integration

The integration is tested against `@howaboua/pi-codex-conversion@3.0.34`.
It resolves the installed adapter from the `/codex` command's source metadata and uses its existing configuration and weekly-usage readers.
Those internal module paths are isolated in `loadAdapter()` and must be rechecked when updating the pinned package.
Missing or incompatible adapters degrade to a usable footer with unavailable quota instead of preventing Pi startup.
No installed package files are modified.

Fast mode follows the adapter's global, trusted-project, and environment overrides.
The statusline does not change the model, reasoning, execution mode, tools, prompts, or conversation history.
Weekly usage is read through the adapter's canonical subscription client, including its five-minute cache and last-known-value fallback.
The read sends authentication to the canonical usage endpoint but no prompt, file contents, screenshots, or conversation history.
It does not redeem reset credits, enable voice, or generate model responses.
This also supports the adapter's extra-tools mode, which does not populate its own weekly status.
Unknown quota is shown as unavailable, never as a fabricated percentage.

Filesystem watchers, quota refresh timers, and in-flight requests are disposed when the footer is removed or the session shuts down.
The footer is TUI-only and does not run in RPC, JSON, or print mode.

## Validation

Run the portable unit tests with:

```sh
node --test tests/pi-statusline.test.mjs
```

The isolated macOS TUI smoke test requires the installed Pi CLI, the reviewed adapter package, tmux, and `sandbox-exec`:

```sh
node tests/pi-statusline-smoke.mjs /absolute/path/to/pi-coding-agent/dist/cli.js
```

It creates disposable configuration with fake authentication and denies network access.
The synthetic 61% quota and cache-hit values are display fixtures, not measurements of the account or transport.
Windows and WSL path behavior is covered by portable tests; terminal runtime validation is performed on macOS.
