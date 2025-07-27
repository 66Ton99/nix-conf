{ inputs, pkgs, config, ... }:

{
  imports = [
    ../../pkgs/php84.nix
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
#    shell = pkgs.fish;
  };

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

  environment.systemPackages = [
    pkgs.colima
  ];
}
