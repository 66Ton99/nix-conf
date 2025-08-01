{ inputs, pkgs, config, ... }:

{
  environment.systemPackages = with pkgs; [
#    xcode-install
#    darwin.xcode
    colima
  ];
  
  imports = [
    ../../pkgs/php83.nix
  ];

#  homebrew = {
#    enable = true;
#    casks  = [
#    ];
#
#    brews = [
#    ];
#  };

  # The user should already exist, but we need to set this up so Nix knows
  # what our home directory is (https://github.com/LnL7/nix-darwin/issues/423).
  users.users.ton = {
    home = "/Users/ton";
    shell = pkgs.zsh;
  };
  environment.shells = with pkgs; [ zsh ];
  
  # zsh is the default shell on Mac and we want to make sure that we're
  # configuring the rc correctly with nix-darwin paths.
  programs.zsh.enable = true;
  programs.zsh.shellInit = ''
    # Nix
    if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
      . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
    fi
    # End Nix
    '';

  # Required for some settings like homebrew to know what user to apply to.
  system.primaryUser = "ton";
  
  # sudo with finger print
  security.pam.services.sudo_local = {
  	enable = true;
   	reattach = true;
   	touchIdAuth = true;
   	watchIdAuth = true;
  };
  # set some OSX preferences that I always end up hunting down and changing.
  system.defaults = {
    # a finder that tells me what I want to know and lets me work
    finder = {
      AppleShowAllExtensions = true;
      ShowPathbar = true;
      FXEnableExtensionChangeWarning = false;
    };
    
    # Tab between form controls and F-row that behaves as F1-F12
    NSGlobalDomain = {
      AppleKeyboardUIMode = 3;
      "com.apple.keyboard.fnState" = true;
    };
  };
  
  # Set in Sept 2024 as part of the macOS Sequoia release.
  system.stateVersion = 5;

  # This makes it work with the Determinate Nix installer
  ids.gids.nixbld = 30000;

  # We use proprietary software on this machine
  nixpkgs.config.allowUnfree = true;

  # Keep in async with vm-shared.nix. (todo: pull this out into a file)
  nix = {
    # We use the determinate-nix installer which manages Nix for us,
    # so we don't want nix-darwin to do it.
    enable = false;

    # We need to enable flakes
    extraOptions = ''
      experimental-features = nix-command flakes
      keep-outputs = true
      keep-derivations = true
    '';

    # public binary cache that I use for all my derivations. You can keep
    # this, use your own, or toss it. Its typically safe to use a binary cache
    # since the data inside is checksummed.
#    settings = {
#      substituters = ["https://mitchellh-nixos-config.cachix.org"];
#      trusted-public-keys = ["mitchellh-nixos-config.cachix.org-1:bjEbXJyLrL1HZZHBbO4QALnI5faYZppzkU4D2s0G8RQ="];
#
#      # Required for the linux builder
#      trusted-users = ["@admin"];
#    };
  };
}
