# Fullscreen scrolling sensitivity

Ordinary wheel and trackpad events move five lines instead of one in Pi's fullscreen UI.
Run `/reload` to load this repository-managed extension.
It leaves WezTerm, OS preferences, regular terminal scrollback, and model settings unchanged.

- `/scroll-speed normal` restores one line per event for this session.
- `/scroll-speed fast` restores five lines per event.
- Reloading extensions defaults to fast again.
- Alt-wheel retains Pi's native additional 5x multiplier, giving 25 lines per event in fast mode.

## Compatibility

Pi 0.85.1 consumes wheel input before extension input listeners, and does not expose wheel sensitivity in its settings or a public setter.
The extension therefore adjusts the renderer's internal `wheelScrollLines` value in memory through the live TUI reference supplied by a zero-height widget.
It does not patch installed package files or replace the editor or footer.
Pi retains ownership of event parsing, pointer targeting, nested scrolling, and modifier handling.

The adjustment checks that the field is a positive integer and writable, warns if incompatible, and restores the previous value on disposal when it still owns the value.
Revalidate this integration after Pi upgrades and prefer a public setting if one becomes available.
The code is platform-neutral; actual terminal validation was performed on macOS, not Windows or WSL.

## Validation

From the repository root:

```sh
node --test tests/pi-scroll.test.mjs
node tests/pi-scroll-smoke.mjs /absolute/path/to/pi-coding-agent/dist/cli.js
```

The macOS smoke test uses isolated tmux and Pi instances with network access denied.
It injects SGR mouse-wheel events into a real fullscreen terminal with a numbered transcript, first reproducing the one-line default, then checking the five-line adjustment, both directions, Alt-wheel, speed controls, reload, and removal.
It does not simulate the physical trackpad or use browser-rendered terminal previews.
