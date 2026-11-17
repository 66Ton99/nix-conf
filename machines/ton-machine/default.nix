{ t2Hardware, ... }:
{
  imports = [
    t2Hardware.nixosModules.apple-t2
    ./t2-kernel.nix
    ./hardware-configuration.nix
    ./configuration.nix
    ./kind-ofs-runtime.nix
    ./enterprise-apps.nix
    ./jetbrains-toolbox.nix
    ./shared-certificates.nix
    ./shared-opt.nix
    ./desktop-repair.nix
    ./user-settings.nix
    ./keyboard.nix
    ./touchbar-lock.nix
  ];
}
