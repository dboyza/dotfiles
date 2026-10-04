# Archived Calm presentation

Calm changes terminal presentation without changing tool execution, stored messages, model context, or export data.
It is adapted from Firstmate under the bundled [MIT license](LICENSE) and is not deployed by the active profile.

## Where to edit

| File | Responsibility |
| --- | --- |
| `index.ts` | Toggle command, agent/session events, working-widget ownership, and export protection. |
| `lib/visibility.ts` | In-memory presentation flags shared by the adapters. |
| `lib/preference.ts` | Atomic reads/writes of the runtime-owned `calm` preference file. |
| `lib/collapsed-thinking.ts` | Remove hidden thinking rows from presentation while retaining the original message for expansion. |
| `lib/built-in-tool-shells.ts` | Hide shells around Pi's seven stock tools while retaining images and custom tools. |
| `lib/working-ship.ts` | Boat geometry, animation state, and disposable TUI widget. |

## Compatibility and lifecycle

The original implementation targeted Pi 0.82.0.
Recheck exported component methods and session events against the installed Pi before enabling it; that historical target is not evidence of current compatibility.
Each presentation adapter probes the interface it patches and fails independently, leaving the remaining features available.
Built-in tool detection retains Pi's original definitions and excludes extension collisions and SDK overrides.
The collapsed-thinking adapter keeps the unfiltered message so expansion and disabling Calm can restore the original content.
Export and share temporarily restore stock rendering because they use the same renderers as the transcript.

The boat follows one complete agent run, including tool calls, retries, and compaction.
One scheduler advances water every tick and moves the boat every fourth tick.
State is owned by the extension instance; hiding the widget freezes it, resuming reuses it, and a fresh session resets it.
Disposal stops the scheduler, and every render clamps geometry to the current width so resizing also works after a hidden interval.

The preference file belongs to Pi's runtime agent directory and contains `on` or `off` followed by a newline.
Missing, invalid, or unreadable state means off; write failures are reported instead of silently losing the preference.
Never track or deploy this runtime file.

Before reactivation, verify the toggle, thinking expansion, custom tools, images, export/share, interruption, session reset, and resize behavior in an isolated Pi profile.
The archived footer and scrolling unit tests do not cover these Calm runtime adapters.
