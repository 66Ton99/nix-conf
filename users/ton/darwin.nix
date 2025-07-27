{ inputs, pkgs, ... }:

{
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
}
