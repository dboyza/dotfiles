{
  homeDirectory,
  inputs,
  pkgs,
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
        username
        ;
      isWSL = false;
    };
    users.${username} = import ./home.nix;
  };
}
