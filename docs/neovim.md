# Neovim workflows

Restart Neovim after changing the configuration.
Lazy installs missing plugins and records their versions in `nvim/lazy-lock.json`.
Mason installs language servers, formatters, and the Python and JavaScript debug adapters.
Use `:Lazy` and `:Mason` to inspect installation progress or errors.

`Space` is the leader key.
Press it and pause to see available shortcuts.
See the [shared keyboard guide](keybindings.md) for word movement, Command aliases, window controls, and terminal/multiplexer routing.

## Completion and formatting

Completion documentation opens automatically after 300 ms; signature help remains enabled.
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

## Tests

Neotest supports pytest, Vitest, and Jest.
Install pytest in your project's virtual environment and install Jest or Vitest through the project's package manager.
JavaScript runners must be available under a local or ancestor `node_modules` directory; Plug'n'Play-only installations need project-specific adapter configuration.
The configuration runs their JavaScript entry points directly, supporting paths with spaces and avoiding Windows shell shims.

| Shortcut | Action |
| --- | --- |
| `Space Tn` | Run the nearest test |
| `Space Tf` | Run the current test file |
| `Space Ta` | Run tests under the current project root |
| `Space Tl` | Rerun the last test |
| `Space Td` | Debug the nearest test |
| `Space Ts` | Toggle the test tree and results |
| `Space To` / `Space TO` | Open test output / toggle the output panel |
| `Space Tq` | Stop the test |

Test discovery needs the corresponding Tree-sitter parser.
Python, JavaScript, TypeScript, and TSX parsers are configured for installation when a C compiler and the Tree-sitter CLI are available.
In repositories containing multiple test frameworks, use the test summary to select each runner's suite.

## Debugging

Mason installs `debugpy` and `js-debug-adapter`; Node.js runs the JavaScript adapter.
Python debugging detects project virtual environments independently from Mason's adapter environment.
The debug panels open when a session initializes and close when it ends.

| Shortcut | Action |
| --- | --- |
| `Space rc` | Start or continue debugging |
| `Space rb` / `Space rB` | Toggle a breakpoint / set a conditional breakpoint |
| `Space ro` / `Space ri` / `Space rO` | Step over / into / out |
| `Space rq` | Stop debugging |
| `Space rl` | Repeat the last debug configuration |
| `Space ru` | Toggle variables, breakpoints, stacks, watches, and console |
| `Space re` | Evaluate the word under the cursor or selected expression |

Python has launch and attach configurations.
JavaScript and TypeScript have Node launch and process-attach configurations with source maps.
The current-file launch uses Node directly; applications requiring bundlers, JSX/TSX transformation, or a custom TypeScript runtime need a project-specific launch configuration.
Browser debugging is not configured.

Open Neovim from your project root to use its `.vscode/launch.json` configurations.
nvim-dap reads these when starting a session; use valid JSON without trailing commas.

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

The configuration includes native Windows interpreter paths and portable argument arrays for test runners, plus macOS and Linux/WSL paths.
The IDE workflows have been exercised on macOS; native Windows and WSL still need runtime verification.
Tree-sitter parser compilation requires an available C compiler on each platform.
