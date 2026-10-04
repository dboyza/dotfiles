# Neovim workflows

Restart Neovim after changing the configuration.
Lazy installs missing plugins and records their versions in `nvim/lazy-lock.json`.
Mason installs language servers, formatters, and supporting tools.
Use `:Lazy` and `:Mason` to inspect installation progress or errors.

`Space` is the leader key.
Press it and pause to see available shortcuts.
See the [shared keyboard guide](keybindings.md) for word movement, Command aliases, window controls, and terminal/multiplexer routing.

## Completion and formatting

Completion documentation opens automatically after 300 ms; signature help remains enabled.
Blink uses Neovim's native snippet engine to expand language-server completion snippets.
Use `Tab` to accept completion or advance through snippet placeholders, and `Shift+Tab` to move backward.
Saving formats supported files, including JSX and TSX, with a 1.5-second timeout.
Formatting follows the project's formatter configuration and falls back to an attached language server when no configured formatter is available.

| Shortcut | Action |
| --- | --- |
| `Space cf` | Format the current buffer or selection manually |
| `Space tf` | Toggle format-on-save for the current project |
| `Space th` | Toggle inlay hints when supported by the language server |

The formatting toggle applies to every buffer in the same Git root, or the nearest recognized project root outside Git.
It lasts for the current Neovim session; other projects remain independent.
Manual formatting stays available when automatic formatting is disabled.
Use `:ConformInfo` to inspect formatter availability and errors.

## Problems and code navigation

| Shortcut | Action |
| --- | --- |
| `Space dp` | Toggle the Problems panel for available diagnostics |
| `Space db` | Toggle Problems for the current buffer |
| `Space cs` | Toggle the code outline on the right |
| `Space cl` | Toggle definitions and references |
| `Space dq` | Toggle the quickfix panel |
| `gd` / `gr` / `gI` | Definition / references / implementation |
| `Space rn` / `Space ca` | Rename symbol / code action |

Problems displays diagnostics reported by the attached tools; it does not independently scan every unopened file.
The outline requires a language server with document-symbol support.

## Project search and replace

`Space sr` opens Grug Far with the current project path filled in.
Enter search and replacement text, inspect the results, then use its displayed replace or sync actions.
Ripgrep is required and is already part of the dotfiles toolchain.

## Git

`Space gg` opens Neogit in a new tab for the current file's project.
Use `:Neogit` to open Git status for Neovim's working directory instead.
Neogit uses the existing theme and Telescope picker.

| Shortcut in Neogit | Action |
| --- | --- |
| `Tab` | Expand or collapse a file or diff hunk |
| `s` / `u` | Stage / unstage the selected file or hunk |
| `c` | Open the commit menu |
| `b` | Open the branch menu |
| `?` | Show available actions |
| `q` | Close Neogit and return to editing |

The existing `Space h` Git hunk actions remain available in source buffers.

## Commenting

Use Neovim's native `gcc` to toggle the current line's comment and `gc` with a motion or Visual selection to toggle multiple lines.
Comment delimiters follow the file type.
The mini.comment-specific `gc` comment-block text object is no longer installed.

## Running project commands

Open the project terminal with `Space ft` to run your project's test runner or command-line debugger.
Keep pytest, Jest, Vitest, and other project dependencies in the project's own environment.
The former `Space T` test actions and `Space r` debugger actions are no longer configured.
`Space rn` still renames symbols through the language server.

## Terminal and file renaming

| Shortcut | Action |
| --- | --- |
| `Control+/` | Toggle the project terminal from Normal or Terminal mode |
| `Space ft` | Toggle the project terminal from Normal mode |
| `Esc Esc` | Leave Terminal mode to navigate editor windows |
| `Space cR` | Rename the current file and notify language servers |

The terminal opens in a bottom split and reuses the project's shell session.
`Control+_` handles the legacy encoding of `Control+/`; `Space ft` is the portable Normal-mode fallback.
File renaming saves a modified buffer before prompting for its new path.
Neo-tree move and rename actions also notify language servers so supported servers can update imports.
Inspect and save any affected buffers after a rename.

## Platform validation

The editor configuration supports native Windows, macOS, and Linux/WSL.
The IDE workflows have been exercised on macOS, and the dedicated agent workspace has been checked in WSL; native Windows still needs runtime verification.
Tree-sitter parser compilation requires an available C compiler on each platform.

## Agent workspace

Run `herdr` in a macOS or Linux/WSL terminal, then run the launcher from a shell pane:

```sh
herdr-workspace ~/code/my-project
herdr-workspace ~/code/my-project pi
```

The left pane asks you to choose Codex, Claude Code, Pi, or opencode each time.
Enter a number or agent name; `q` or `Control+C` leaves that pane at a shell.
An explicit agent argument skips the picker for that invocation.
Each invocation creates a fresh workspace in the current Herdr session, with a 40% agent pane and a 60% editor pane.
Herdr's normal New Space action creates the same layout and picker through the local `dotfiles.workspace` plugin.
Existing spaces and restored sessions are not rearranged; new worktree spaces use the layout too.
The project sidebar belongs to Herdr; Neovim contains the file editor and a persistent, 34-column Neo-tree on its right.
`Space e` switches between the tree and editor, and opening a file keeps this tree visible.
Normal Neovim launches retain the left-hand explorer that closes after file selection.
Quitting the last editor window still closes Neo-tree.

The layout hook sets `g:dotfiles_workspace` only for the new editor process.
That profile checks for external changes every 1.5 seconds in Normal mode and refreshes unmodified buffers.
Unsaved buffers are preserved so you can resolve competing edits yourself.
If automatic setup fails, the space is preserved; inspect `herdr plugin log --plugin dotfiles.workspace` for its ID and the error.
Run `herdr-workspace --help` for usage.

Reviewr is available with `Control+A`, then `v`; toggle it again to recover the editor's screen space.
Its navigator sits on the right, `2` selects All files, and `e` opens the selected file in Neovim temporarily.
Reviewr's editor does not enable the dedicated workspace profile.
Worktree creation does not automatically open Reviewr.
Bootstrap installs missing Reviewr from the pinned 0.44.0 source commit through Herdr and preserves existing installations.
Bootstrap also links the local layout plugin directly to this checkout.
To install or relink both plugins independently:

```sh
herdr-workspace --install-plugins
```

Both the launcher and Reviewr run inside WSL on Windows; native Windows Herdr remains available separately.
This layout does not embed a graphical chat interface: the agent keeps its own terminal UI.
