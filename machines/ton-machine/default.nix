{ t2Hardware, ... }:
{
  imports = [
    t2Hardware.nixosModules.apple-t2
    ./t2-kernel.nix
    ./hardware-configuration.nix
    ./configuration.nix
    ./enterprise-apps.nix
    ./shared-certificates.nix
    ./shared-opt.nix
    ./desktop-repair.nix
    ./user-settings.nix
    ./keyboard.nix
  ];
}
