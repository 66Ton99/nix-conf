{ pkgs, ... }:
{
  imports = [
    ./ton-machine
    ../pkgs/dev.nix
  ];

  environment.systemPackages = [
    (pkgs.callPackage ../pkgs/codex-desktop.nix { })
  ];
}
