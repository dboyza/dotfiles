{
  homeDirectory,
  inputs,
  isWSL,
  lib,
  pkgs,
  username,
  ...
}:
let
  managed = source: {
    inherit source;
    force = true;
  };

  system = pkgs.stdenv.hostPlatform.system;
in
{
  home = {
    inherit homeDirectory username;
    stateVersion = "24.11";

    packages =
      with pkgs;
      [
        bat
        bind
        btop
        claude-code
        codex
        curl
        direnv
        fzf
        git
        git-lfs
        gnumake
        gnupg
        inputs.herdr.packages.${system}.default
        jq
        kubectl
        nerd-fonts.hack
        neovim
        nodejs_24
        pre-commit
        ripgrep
        shellcheck
        shfmt
        socat
        starship
        terraform
        tmux
        tree
        unzip
        uv
        wget
        zsh
        zsh-autosuggestions
        zsh-syntax-highlighting
      ]
      ++ lib.optionals pkgs.stdenv.isLinux [
        gcc
        wl-clipboard
        xclip
        xsel
      ]
      ++ lib.optionals (pkgs.stdenv.isLinux && !isWSL) [
        wezterm
      ]
      ++ lib.optionals (system != "x86_64-darwin") [
        opencode
      ];
  };

  fonts.fontconfig.enable = pkgs.stdenv.isLinux;

  programs.home-manager.enable = true;

  home.file = {
    ".zshenv" = managed ../zsh/.zshenv;
    ".zshrc" = managed ../zsh/.zshrc;
    ".tmux.conf" = managed ../tmux/.tmux.conf;
    ".wezterm.lua" = managed ../wezterm/.wezterm.lua;
    ".config/herdr/config.toml" = managed ../herdr/config.toml;
    ".config/nvim" = managed ../nvim;
    ".config/starship.toml" = managed ../starship/starship.toml;

    ".codex/AGENTS.md" = managed ../agents/global/AGENTS.md;
    ".claude/CLAUDE.md" = managed ../agents/global/AGENTS.md;
    ".config/opencode/AGENTS.md" = managed ../agents/global/AGENTS.md;

    ".tmux/plugins/tpm" = managed inputs.tpm;
    ".tmux/plugins/tmux-yank" = managed inputs.tmux-yank;
    ".tmux/plugins/tmux-resurrect" = managed inputs.tmux-resurrect;
    ".tmux/plugins/tmux-continuum" = managed inputs.tmux-continuum;
    ".tmux/plugins/tmux-assistant-resurrect" = managed inputs.tmux-assistant-resurrect;
  }
  // lib.optionalAttrs isWSL {
    ".local/bin/win-copy" = managed ../scripts/win-copy;
    ".local/bin/win-paste" = managed ../scripts/win-paste;
  };
}
