{
  allowUnfreePredicate,
  homeDirectory,
  repoDirectory,
  inputs,
  pkgs,
  username,
  ...
}:
let
  appInstaller = pkgs.writeShellScript "install-missing-macos-apps" ''
    brew_binary=$(command -v brew || true)
    for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
      if [ -z "$brew_binary" ] && [ -x "$candidate" ]; then
        brew_binary=$candidate
        break
      fi
    done
    if [ -z "$brew_binary" ]; then
      echo "Homebrew is required to install missing macOS applications" >&2
      exit 1
    fi
    exec ${pkgs.python3}/bin/python3 ${../scripts/install-macos-apps.py} \
      --manifest ${./macos-apps.json} --mas ${pkgs.mas}/bin/mas \
      --home ${pkgs.lib.escapeShellArg homeDirectory} --brew "$brew_binary" "$@"
  '';
  runAppInstaller = "/usr/bin/sudo -H --user=${pkgs.lib.escapeShellArg username} -- ${appInstaller}";
in
{
  nixpkgs.config = { inherit allowUnfreePredicate; };

  nix = {
    enable = true;
    channel.enable = false;
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  system = {
    # Explicit macOS preferences; leave unspecified settings at their existing values.
    defaults = {
      NSGlobalDomain = {
        AppleInterfaceStyle = "Dark";
        NSAutomaticCapitalizationEnabled = true;
        NSAutomaticPeriodSubstitutionEnabled = true;
        "com.apple.trackpad.scaling" = 1.0;
        "com.apple.trackpad.forceClick" = true;
        "com.apple.springing.enabled" = true;
        "com.apple.springing.delay" = 0.5;
      };

      dock = {
        autohide = true;
        magnification = false;
        mineffect = "genie";
        minimize-to-application = true;
        orientation = "bottom";
        show-recents = false;
        showAppExposeGestureEnabled = true;
        tilesize = 57;
        wvous-tl-corner = 1; # Disabled.
        wvous-tr-corner = 1;
        wvous-bl-corner = 1;
        wvous-br-corner = 14; # Quick Note.
      };

      finder = {
        FXPreferredViewStyle = "Nlsv"; # List view.
        NewWindowTarget = "Home";
        ShowExternalHardDrivesOnDesktop = true;
        ShowHardDrivesOnDesktop = false;
        ShowRemovableMediaOnDesktop = true;
        ShowPathbar = true;
        ShowStatusBar = true;
        _FXSortFoldersFirst = true;
        _FXSortFoldersFirstOnDesktop = false;
      };

      ActivityMonitor = {
        OpenMainWindow = true;
        ShowCategory = 102; # My Processes.
      };

      WindowManager = {
        GloballyEnabled = false; # Stage Manager.
        AutoHide = false;
        AppWindowGroupingBehavior = true;
        HideDesktop = true; # Hide desktop items while using Stage Manager.
        EnableTiledWindowMargins = false;
        StandardHideWidgets = false;
        StageManagerHideWidgets = false;
      };

      menuExtraClock = {
        ShowAMPM = true;
        ShowDayOfWeek = true;
        ShowDate = 0; # When space allows.
      };

      controlcenter.BatteryShowPercentage = true;
      loginwindow.GuestEnabled = false;
      SoftwareUpdate.AutomaticallyInstallMacOSUpdates = true;
      magicmouse.MouseButtonMode = "OneButton";

      trackpad = {
        Clicking = false;
        Dragging = false;
        DragLock = false;
        TrackpadRightClick = true;
        TrackpadThreeFingerDrag = false;
        TrackpadThreeFingerTapGesture = 0;
        TrackpadThreeFingerHorizSwipeGesture = 2;
        TrackpadThreeFingerVertSwipeGesture = 2;
        TrackpadFourFingerHorizSwipeGesture = 2;
        TrackpadFourFingerVertSwipeGesture = 2;
        TrackpadFourFingerPinchGesture = 2;
        TrackpadTwoFingerFromRightEdgeSwipeGesture = 3;
        ActuateDetents = true;
        FirstClickThreshold = 1;
        SecondClickThreshold = 1;
        ForceSuppressed = false;
        TrackpadCornerSecondaryClick = 0;
        TrackpadMomentumScroll = true;
        TrackpadPinch = true;
        TrackpadRotate = true;
        TrackpadTwoFingerDoubleTapGesture = true;
      };
    };

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
  system.activationScripts.preActivation.text = pkgs.lib.mkBefore ''
    ${runAppInstaller} --preserve-legacy
  '';
  system.activationScripts.postActivation.text = pkgs.lib.mkAfter ''
    ${runAppInstaller}
  '';

  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = false;
      cleanup = "none";
      upgrade = false;
    };
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      inherit
        homeDirectory
        repoDirectory
        inputs
        username
        ;
      isWSL = false;
    };
    users.${username} = import ./home.nix;
  };
}
