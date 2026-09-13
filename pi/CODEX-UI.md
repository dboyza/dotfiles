# Codex-style Pi UI

Use the installed Codex Conversion adapter's Structured mode for `Ran` / `Explored` tool rows, indented command output, and expandable previews.
This is the adapter's existing presentation, not an exact reproduction of Codex CLI.
It retains Pi's tool panels and `Ctrl+O` expansion shortcut rather than Codex's `Ctrl+T` transcript shortcut.
The custom footer and cache diagnostics remain enabled.

## Configuration

In `/codex`, choose **Structured** execution mode and turn off the standalone `apply_patch` and `view_image` toggles.
Those toggles select extra-tools mode on the current Codex provider and otherwise bypass the Structured adapter.
In `/codex display`, keep **Tool naming** enabled and set **Compact tool output** to **on**.
Compact output hides collapsed patch diffs while keeping shell output previews.

Merge these fields into `~/.pi/agent/pi-codex-conversion.json`, preserving all other settings:

```json
{
  "executionMode": "normal",
  "tools": {
    "applyPatchOnly": false,
    "viewImageOnly": false
  },
  "ui": {
    "toolRenaming": true,
    "compactTools": "on"
  }
}
```

Run `/reload` after editing the file.
New tool calls use `exec_command`, `write_stdin`, `apply_patch`, and `view_image` instead of Pi's `bash`, `read`, `edit`, and `write` tools.
Existing transcript entries keep their original tool identities.
Turning off the standalone image/patch toggles does not remove those capabilities from Structured mode.
The model, reasoning effort, other extensions, fullscreen mode, and terminal scrolling settings are unchanged.

Keep this runtime configuration out of an ordinary managed symlink because the adapter's atomic settings writer replaces symlinks.
Back up the file before package upgrades and recheck these fields after configuration migrations.
See [footer setup](extensions/codex-statusline/README.md) for cache diagnostics and quota display.

## Validation

The existing isolated TUI smoke test also exercises Structured mode when `PI_STATUSLINE_STRUCTURED=1` is set.
It verifies active tool names, native collapsed command/output rendering, `Ctrl+O` expansion, and footer compatibility with network access denied and synthetic transcript entries.
The test does not generate model responses or execute the displayed fixture command.
