{
  homeDirectory,
  inputs,
  pkgs,
  repositoryDirectory,
  username,
  ...
}:
{
  nixpkgs.config.allowUnfreePredicate =
    package:
    builtins.elem (pkgs.lib.getName package) [
      "claude-code"
      "terraform"
    ];

  nix = {
    enable = true;
    channel.enable = false;
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  system = {
    activationScripts.disableControlArrowShortcuts.text =
      let
        user = pkgs.lib.escapeShellArg username;
        disabledShortcut = pkgs.lib.escapeShellArg ''
          <dict>
            <key>enabled</key>
            <false/>
          </dict>
        '';
      in
      ''
        user_id=$(/usr/bin/id -u -- ${user})
        for shortcut in 32 33 79 80 81 82; do
          /bin/launchctl asuser "$user_id" /usr/bin/sudo --user=${user} -- \
            /usr/bin/defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys \
              -dict-add "$shortcut" ${disabledShortcut}
        done
      '';
    primaryUser = username;
    stateVersion = 6;
  };

  users.users.${username} = {
    home = homeDirectory;
    shell = pkgs.zsh;
  };

  programs.zsh.enable = true;
  environment.shells = [ pkgs.zsh ];
  fonts.packages = [ pkgs.nerd-fonts.hack ];

  homebrew = {
    enable = true;
    casks = [ "wezterm" ];
    onActivation = {
      autoUpdate = true;
      cleanup = "none";
      upgrade = true;
    };
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      inherit
        homeDirectory
        inputs
        repositoryDirectory
        username
        ;
      isWSL = false;
    };
    users.${username} = import ./home.nix;
  };
}
