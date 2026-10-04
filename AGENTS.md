# Repository instructions

This is a living document: always tidy this file and its linked component instructions as part of repository work.
Check guidance against current code and user decisions, correct stale claims, remove duplication, and replace superseded instructions.
Keep only verified, durable repository guidance; put component details in their scoped files and omit transient session or machine state.
Preserve explicit user requirements when code disagrees with them, and report the mismatch rather than silently changing the policy.

Keep policy shared, platform integration explicit, and functions readable.
Prefer a few named responsibilities over broad frameworks or duplicated platform implementations.

Keep every handwritten code and configuration file easy for a human to navigate and edit.
Start with a concise purpose comment, group distinct responsibilities under descriptive `Section:` comments, and explain non-obvious decisions, invariants, platform differences, and side effects beside the relevant code.
Keep each explanatory comment or docstring to at most two lines, moving longer design notes into the nearest guide.
Keep comments accurate when changing behavior; avoid comments that merely restate syntax or artificial sections in tiny files.
For formats that cannot contain comments, document their fields and editing workflow in the nearest README or guide.
Preserve generated files and upstream-managed code; document their source and regeneration path instead.
Use [the code map](docs/code-map.md) to find the relevant entry points and verification commands.

Before changing a component or its tests/installers, read its scoped instructions:

| Area | Instructions |
| --- | --- |
| Terminal configuration and native companions | [wezterm/AGENTS.md](wezterm/AGENTS.md) |
| Bootstrap, managed tools, clipboard, activity polling | [scripts/AGENTS.md](scripts/AGENTS.md) |
| Package ownership and home-file deployment | [nix/AGENTS.md](nix/AGENTS.md) |
| Editor | [nvim/AGENTS.md](nvim/AGENTS.md) |
| Active Pi settings and archived customizations | [pi/AGENTS.md](pi/AGENTS.md) |
| Shell, multiplexer, review integration | [zsh/AGENTS.md](zsh/AGENTS.md), [tmux/AGENTS.md](tmux/AGENTS.md), [herdr/AGENTS.md](herdr/AGENTS.md) |
| Verification and documentation | [tests/AGENTS.md](tests/AGENTS.md), [docs/AGENTS.md](docs/AGENTS.md) |

- When making a change, preserve supported behavior on Linux, macOS, native Windows 11, and Windows 11 with WSL.
  Use platform-specific branches or fallbacks where behavior and dependencies differ, and verify each platform path as far as the available environment allows.
  If full compatibility cannot be achieved, state the limitation explicitly instead of silently breaking a supported platform.

- Keep this root `AGENTS.md` repository-specific so coding agents apply it only within this checkout.

- Preserve Rosé Pine Moon's palette with a deeper `#191724` default background and brighter `#eeecff` default foreground.

- On macOS, disable only the Mission Control and Spaces symbolic hotkeys that consume `Control+Arrow`; merge those entries without replacing unrelated shortcut preferences.

- Keep MacBook-safe Command aliases for clipboard and Page Up or Page Down behavior while retaining the portable bindings for external keyboards.

- On macOS, route image-only Command+V paste to the application's Control+V handler and preserve normal terminal paste for text and copied file paths.
  Keep plain Control+V unbound in tmux's root table, including on configuration reload.

- Use Option+Left/Right for word movement and Command+Left/Right for Home/End on macOS.
  Translate Option+Left/Right to Control+Left/Right so shell and editor word navigation agree.
  Send Home/End keys rather than Control+A/Control+E so Herdr's prefix remains usable, and bind both CSI and SS3 Home/End sequences in Zsh.
  Map direct Command+Left/Right events to native Home/End in macOS Neovim too, including insert and command-line modes.
  Keep Command+H/L as Home/End aliases in both macOS WezTerm and Neovim, overriding WezTerm's default Command+H hide action.
  Use Command+Up/Down for native Control+Home/End file navigation in Neovim editing modes.

- Keep tmux on `Control+G` and Herdr on `Control+A` so their prefixes do not collide when Herdr runs inside tmux.

- Report native runtime, simulated, and static validation separately for each supported platform.
  Missing native runners must remain explicit coverage gaps.

- Keep WezTerm's prefix on `Control+Shift+Space` so `Control+Space` reaches completion, and preserve the distinct tmux and Herdr prefixes below.
  Across multiplexers, use prefix `h/j/k/l` for focus, `H/J/K/L` for resizing, and backslash/minus for side-by-side/stacked splits.
  Route fullscreen application Page keys through tmux; reserve shell Page keys and explicit copy mode for scrollback.
  Let nested Neovim handle Alt pane navigation first, then the nearest enclosing Herdr pane before outer tmux.

- Keep tmux windows in a single bottom status row and WezTerm's native tab bar at the top, including with one tab.
  Native tabs are the default and fallback; hide them only while a fresh matching companion acknowledgment permits it.

- Keep plain `Control+Arrow` events passing through WezTerm on every platform so Neovim receives its navigation bindings.

- Store shared global agent instructions in `agents/global/AGENTS.md`, and ensure global Codex, Claude, opencode, and Pi instruction symlinks target that file rather than this one.
  Pi's global instruction path is `~/.pi/agent/AGENTS.md`, not `~/.pi/AGENTS.md`.

- Treat keybindings as one end-to-end contract across host OS shortcuts, WezTerm, tmux, Herdr, shells, Neovim, and configured agent applications.
  Every keybinding change must preserve the most consistent, sensible, ergonomic behavior possible across native Windows, WSL, and MacBook keyboards.
  Audit enclosing-layer interception, inherited defaults, editor modes, legacy terminal encodings, and laptop accessibility before assigning a chord; keep portable shortcuts plus appropriate Command/Option aliases.
  Do not make essential actions depend only on a function-key row, Home/End/Insert keys, or OS-reserved shortcuts.
  Update `docs/keybindings.md` and affected routing tests alongside changes, documenting intentional differences and migrations.
