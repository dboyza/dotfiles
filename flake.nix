{
  description = "Dylan's reproducible terminal environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    herdr = {
      url = "github:ogulcancelik/herdr/v0.7.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    tpm = {
      url = "github:tmux-plugins/tpm";
      flake = false;
    };

    tmux-yank = {
      url = "github:tmux-plugins/tmux-yank";
      flake = false;
    };

    tmux-resurrect = {
      url = "github:tmux-plugins/tmux-resurrect";
      flake = false;
    };

    tmux-continuum = {
      url = "github:tmux-plugins/tmux-continuum";
      flake = false;
    };

    tmux-assistant-resurrect = {
      url = "github:timvw/tmux-assistant-resurrect";
      flake = false;
    };
  };

  outputs =
    inputs@{
      home-manager,
      nix-darwin,
      nixpkgs,
      ...
    }:
    let
      supportedSystems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      requireEnvironment =
        name:
        let
          value = builtins.getEnv name;
        in
        if value == "" then throw "${name} is unset. Run this flake through ./bootstrap.sh." else value;

      username = requireEnvironment "DOTFILES_USER";
      homeDirectory = requireEnvironment "DOTFILES_HOME";
      isWSL = builtins.getEnv "DOTFILES_WSL" == "1";

      specialArgs = {
        inherit
          homeDirectory
          inputs
          isWSL
          username
          ;
      };

      mkPkgs =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfreePredicate =
            package:
            builtins.elem (nixpkgs.lib.getName package) [
              "claude-code"
              "terraform"
            ];
        };

      mkHome =
        system:
        home-manager.lib.homeManagerConfiguration {
          pkgs = mkPkgs system;
          extraSpecialArgs = specialArgs;
          modules = [ ./nix/home.nix ];
        };

      mkDarwin =
        system:
        nix-darwin.lib.darwinSystem {
          inherit system specialArgs;
          modules = [
            home-manager.darwinModules.home-manager
            ./nix/darwin.nix
          ];
        };
    in
    {
      homeConfigurations = {
        linux-aarch64 = mkHome "aarch64-linux";
        linux-x86_64 = mkHome "x86_64-linux";
      };

      darwinConfigurations = {
        macos-aarch64 = mkDarwin "aarch64-darwin";
        macos-x86_64 = mkDarwin "x86_64-darwin";
      };

      apps = forAllSystems (
        system:
        {
          home-manager = {
            type = "app";
            program = "${home-manager.packages.${system}.home-manager}/bin/home-manager";
          };
        }
        // nixpkgs.lib.optionalAttrs nixpkgs.legacyPackages.${system}.stdenv.isDarwin {
          darwin-rebuild = {
            type = "app";
            program = "${nix-darwin.packages.${system}.darwin-rebuild}/bin/darwin-rebuild";
          };
        }
      );

      packages = forAllSystems (system: {
        hack-font = nixpkgs.legacyPackages.${system}.nerd-fonts.hack;
      });

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
