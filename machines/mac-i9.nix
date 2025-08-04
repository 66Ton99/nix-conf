{ config, pkgs, ... }: {
  imports = [
    ../pkgs/dev.nix
  ];
  environment.systemPackages = with pkgs; [
    cachix
  ];
}
