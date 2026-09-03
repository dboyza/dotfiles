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

  home.activation.installNvimLockfile = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    state_dir=${lib.escapeShellArg "${homeDirectory}/.local/state/nvim"}
    state_target="$state_dir/lazy-lock.json"

    $DRY_RUN_CMD mkdir -p "$state_dir"
    $DRY_RUN_CMD cp -f ${../nvim/lazy-lock.json} "$state_target"
    $DRY_RUN_CMD chmod 0644 "$state_target"
  '';

  home.activation.installPiSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settings_dir=${lib.escapeShellArg "${homeDirectory}/.pi/agent"}
    settings_target="$settings_dir/settings.json"
    settings_temp="$settings_target.tmp.$$"

    $DRY_RUN_CMD mkdir -p "$settings_dir"
    if [[ -z "''${DRY_RUN_CMD:-}" ]]; then
      trap '${pkgs.coreutils}/bin/rm -f "$settings_temp"' EXIT
      if [[ -f "$settings_target" ]] && ${pkgs.jq}/bin/jq empty "$settings_target" >/dev/null 2>&1; then
        ${pkgs.jq}/bin/jq -s '
          .[0] as $current
          | .[1] as $managed
          | ($current | del(
              .autocompleteMaxVisible,
              .defaultModel,
              .defaultProvider,
              .defaultThinkingLevel,
              .editorPaddingX,
              .enabledModels,
              .externalEditor,
              .showHardwareCursor
            )) * $managed
        ' "$settings_target" ${../pi/settings.json} > "$settings_temp"
      else
        ${pkgs.coreutils}/bin/cp ${../pi/settings.json} "$settings_temp"
      fi
      ${pkgs.coreutils}/bin/chmod 0644 "$settings_temp"
      ${pkgs.coreutils}/bin/mv -f "$settings_temp" "$settings_target"
      trap - EXIT
    fi
  '';

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
    ".pi/agent/AGENTS.md" = managed ../agents/global/AGENTS.md;
    ".agents/skills" = managed ../agents/skills;

    ".pi/agent/models.json" = managed ../pi/models.json;
    ".pi/agent/extensions" = managed ../pi/extensions;
    ".pi/agent/themes" = managed ../pi/themes;

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
