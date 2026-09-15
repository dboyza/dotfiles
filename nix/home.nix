{
  config,
  repoDirectory,
  homeDirectory,
  homebrewPrefix ? null,
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

  live = relative: managed (config.lib.file.mkOutOfStoreSymlink "${repoDirectory}/${relative}");

  pre-commit-without-dotnet-tests = pkgs.pre-commit.overridePythonAttrs (old: {
    nativeCheckInputs = builtins.filter (input: input != pkgs.dotnet-sdk) old.nativeCheckInputs;
    preCheck = lib.concatStringsSep "\n" (
      builtins.filter (line: !(lib.hasInfix ".NET location" line || lib.hasInfix "DOTNET_ROOT" line)) (
        lib.splitString "\n" (builtins.unsafeDiscardStringContext old.preCheck)
      )
    );
  });
in
{
  home = {
    inherit homeDirectory username;
    stateVersion = "24.11";

    # Brew leaves these tools unlinked or GNU-prefixed to avoid replacing Apple tools.
    sessionPath = lib.optionals pkgs.stdenv.isDarwin [
      "${homebrewPrefix}/opt/curl/bin"
      "${homebrewPrefix}/opt/unzip/bin"
      "${homebrewPrefix}/opt/make/libexec/gnubin"
    ];

    packages =
      with pkgs;
      lib.optionals pkgs.stdenv.isLinux [
        bat
        bind
        btop
        claude-code
        curl
        direnv
        fzf
        gh
        git
        git-lfs
        gnumake
        gnupg
        jq
        kubectl
        lazygit
        neovim
        nodejs_24
        pre-commit-without-dotnet-tests
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
        zoxide
        zsh
        zsh-autosuggestions
        zsh-syntax-highlighting
      ]
      ++ lib.optionals pkgs.stdenv.isLinux [
        bubblewrap
        gcc
        nerd-fonts.hack
        wl-clipboard
        xclip
        xsel
      ]
      ++ lib.optionals (pkgs.stdenv.isLinux && !isWSL) [
        wezterm
      ];
  };

  fonts.fontconfig.enable = pkgs.stdenv.isLinux;

  programs.home-manager.enable = true;

  home.file = {
    ".zshenv" = live "zsh/.zshenv";
    ".zshrc" = live "zsh/.zshrc";
    ".config/zsh/plugins/zsh-autosuggestions.zsh" =
      if pkgs.stdenv.isDarwin then
        managed (
          config.lib.file.mkOutOfStoreSymlink "${homebrewPrefix}/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
        )
      else
        managed "${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh";
    ".config/zsh/plugins/zsh-syntax-highlighting.zsh" =
      if pkgs.stdenv.isDarwin then
        managed (
          config.lib.file.mkOutOfStoreSymlink "${homebrewPrefix}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
        )
      else
        managed "${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh";
    ".tmux.conf" = live "tmux/.tmux.conf";
    ".wezterm.lua" = live "wezterm/.wezterm.lua";
    ".config/herdr/config.toml" = live "herdr/config.toml";
    ".config/nvim" = live "nvim";
    ".config/starship.toml" = live "starship/starship.toml";
    ".local/bin/dotfiles-clipboard" = live "scripts/dotfiles-clipboard";

    ".codex/AGENTS.md" = live "agents/global/AGENTS.md";
    ".claude/CLAUDE.md" = live "agents/global/AGENTS.md";
    ".config/opencode/AGENTS.md" = live "agents/global/AGENTS.md";
    ".pi/agent/AGENTS.md" = live "agents/global/AGENTS.md";
    ".agents/skills" = live "agents/skills";

    ".pi/agent/settings.json" = live "pi/settings.json";

    ".tmux/plugins/tmux-resurrect" = managed inputs.tmux-resurrect;
    ".tmux/plugins/tmux-continuum" = managed inputs.tmux-continuum;
    ".tmux/plugins/tmux-assistant-resurrect" = managed inputs.tmux-assistant-resurrect;
  }
  // lib.optionalAttrs pkgs.stdenv.isLinux {
    ".local/bin/dotfiles-tool.mjs" = live "scripts/dotfiles-tool.mjs";
    ".local/bin/codex" = live "scripts/codex";
    ".local/bin/pi" = live "scripts/pi";
    ".local/bin/opencode" = live "scripts/opencode";
    ".local/bin/herdr" = live "scripts/herdr";
  }
  // lib.optionalAttrs isWSL {
    ".local/bin/win-copy" = live "scripts/win-copy";
    ".local/bin/win-paste" = live "scripts/win-paste";
  };
}
