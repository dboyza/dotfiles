# Zsh maintenance instructions

- Keep the default Zsh `ls` alias in its normal listing layout without `-m`, preserving platform-specific color flags.

- Expose Zsh plugin scripts through managed paths under `~/.config/zsh/plugins`; Home Manager profiles do not reliably link package-specific top-level `share` directories.

- Initialize Zoxide in the tracked `zsh/.zshrc` after completion setup; Home Manager does not generate this live-linked file.

- Load Zsh plugins from the managed `~/.config/zsh/plugins` paths instead of searching package-manager directories.
