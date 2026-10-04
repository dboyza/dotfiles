# Neovim maintenance instructions

- Keep Neovim's Neo-tree sidebar, Bufferline tab row, and Lualine status line visually coordinated with the transparent Rosé Pine terminal theme.

- Keep Lazy's lockfile in the live Neovim configuration directory so plugin updates and Git restores affect the same file.

- Keep Neovim `Space e` switching focus between Neo-tree and the previous editor window without hiding the sidebar.

- Close Neo-tree after opening a file from it; expanding a directory should leave the explorer open.

- Open Neo-tree only on request through `Space e` or `:Neotree`, not automatically at startup, in new tabs, or when opening directories.

- Let Neo-tree close when the last editor window in its tab closes so normal quit commands do not require a second quit for the sidebar.

- Keep Neovim's entry point small, with core settings in `nvim/lua/config` and plugin declarations in `nvim/lua/plugins`.

- Keep Pyright type checking off by default in Neovim while retaining Python completion and navigation.

- Keep Neogit on `Space gg`, scoped through `config.project.root()`, with the existing Telescope picker and theme integration.
  Preserve `Space h` for Gitsigns hunk actions.

- Use Neovim's native commenting and Blink's native `vim.snippet` integration.
  Keep test runners and debuggers in project terminals or external tools rather than installing Neotest, DAP, or their Mason adapters.

- Keep Neovim's `Space rn` for symbol renaming, `Space d` for diagnostics, and `Space t` for toggles.
  Document changes in `docs/neovim.md`.
  Scope format-on-save toggles and terminal working directories through `config.project`; toggles last for the current Neovim session.

- Keep accelerated `j`/`k` and Up/Down movement in Normal mode through `rhysd/accelerated-jk`, preserving native counted motions.
  Keep the first 40 repeats at one line; tune onset with the acceleration table because `acceleration_limit` controls the pause between repeats that resets acceleration.

- Use Snacks indent guides with animation disabled and theme-coordinated guide colors in Neovim.
  Keep macOS held-key repeat preferences in `nix/darwin.nix`; these affect all applications, not only Neovim.
