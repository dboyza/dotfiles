{
  config,
  repoDirectory,
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

  live = relative: managed (config.lib.file.mkOutOfStoreSymlink "${repoDirectory}/${relative}");

  system = pkgs.stdenv.hostPlatform.system;
  codex = pkgs.callPackage ./codex.nix { };
  pi-coding-agent = pkgs.callPackage ./pi-coding-agent.nix { };
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
        gh
        git
        git-lfs
        gnumake
        gnupg
        inputs.herdr.packages.${system}.default
        jq
        kubectl
        neovim
        nodejs_24
        pi-coding-agent
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
        zsh
        zsh-autosuggestions
        zsh-syntax-highlighting
      ]
      ++ lib.optionals pkgs.stdenv.isLinux [
        gcc
        nerd-fonts.hack
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
    ".zshenv" = live "zsh/.zshenv";
    ".zshrc" = live "zsh/.zshrc";
    ".config/zsh/plugins/zsh-autosuggestions.zsh" =
      managed "${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh";
    ".config/zsh/plugins/zsh-syntax-highlighting.zsh" =
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
    ".pi/agent/models.json" = live "pi/models.json";
    ".pi/agent/extensions" = live "pi/extensions";
    ".pi/agent/themes" = live "pi/themes";

    ".tmux/plugins/tmux-resurrect" = managed inputs.tmux-resurrect;
    ".tmux/plugins/tmux-continuum" = managed inputs.tmux-continuum;
    ".tmux/plugins/tmux-assistant-resurrect" = managed inputs.tmux-assistant-resurrect;
  }
  // lib.optionalAttrs isWSL {
    ".local/bin/win-copy" = live "scripts/win-copy";
    ".local/bin/win-paste" = live "scripts/win-paste";
  };
}
