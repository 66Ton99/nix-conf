{ config, lib, pkgs, modulesPath, utils, ... }:
let
  cryptUnit = name: "systemd-cryptsetup@${utils.escapeSystemdPath name}";
  rootUnlock = "${cryptUnit "crypt-nixos"}.service";
in
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "xhci_pci" "nvme" "usbhid" "usb_storage" "sd_mod" "thunderbolt"
  ];
  boot.initrd.systemd.enable = true;
  boot.initrd.services.lvm.enable = true;
  boot.kernelModules = [ "kvm-intel" ];
  boot.kernelParams = [ "mem_sleep_default=deep" "pcie_ports=auto" ];

  boot.initrd.luks.devices = {
    crypt-nixos = {
      device = "/dev/disk/by-uuid/78289650-0fc8-4baa-823b-e61d9541b5c0";
      crypttabExtraOpts = [ "password-cache=yes" ];
    };
    crypt-linux = {
      device = "/dev/disk/by-uuid/bd730649-0077-4069-a67c-c66403b3e354";
      crypttabExtraOpts = [ "password-cache=yes" ];
    };
    crypt-data = {
      device = "/dev/disk/by-uuid/0ea8b154-f086-46da-9c50-663022169563";
      crypttabExtraOpts = [ "password-cache=yes" ];
    };
  };

  # Finish the first unlock before the other devices query the password cache.
  # Drop-ins preserve the services created by systemd-cryptsetup-generator.
  boot.initrd.systemd.services = lib.listToAttrs (map (name:
    lib.nameValuePair (cryptUnit name) {
      overrideStrategy = "asDropin";
      requires = lib.optional (name != "crypt-nixos") rootUnlock;
      after = lib.optional (name != "crypt-nixos") rootUnlock;
      serviceConfig.KeyringMode = "shared";
    }
  ) [ "crypt-nixos" "crypt-linux" "crypt-data" ]);

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/f7925fa9-f2ae-406d-97a5-189993428631";
    fsType = "ext4";
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/36a2f33d-eece-4d1b-bd47-02e72e9f8509";
    fsType = "xfs";
  };
  fileSystems."/boot/efi" = {
    device = "/dev/disk/by-uuid/5F66-17ED";
    fsType = "vfat";
    options = [ "umask=0077" ];
  };
  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/0b99bdad-6645-4919-965d-9306125186d2";
    fsType = "xfs";
    neededForBoot = true;
    options = [ "x-systemd.device-timeout=infinity" ];
  };
  fileSystems."/mnt/src" = {
    device = "/dev/disk/by-uuid/9df946b8-c0f8-48db-8c53-7419e0780b33";
    fsType = "ext4";
    options = [ "x-systemd.device-timeout=infinity" ];
  };
  fileSystems."/mnt/oracle" = {
    device = "/dev/disk/by-uuid/a343a969-55d1-4086-8ec0-49f7e2947cb7";
    fsType = "xfs";
    options = [
      "rw" "nosuid" "nodev" "nofail" "x-systemd.device-timeout=30s"
    ];
  };
  swapDevices = [
    { device = "/dev/disk/by-uuid/62d909e5-d427-4cf4-a650-e18d07d0a019"; }
  ];

  hardware.apple-t2 = {
    kernelChannel = "stable";
    enableIGPU = true;
    firmware.enable = false;
  };
  hardware.apple.touchBar.enable = true;
  hardware.cpu.intel.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;
  hardware.bluetooth.enable = true;
  hardware.firmware = [
    (pkgs.runCommand "macbookpro16-1-wifi-firmware" { } ''
      mkdir -p $out/lib/firmware/brcm
      cp ${./firmware/brcm}/brcmfmac4364b3-pcie.apple,bali* $out/lib/firmware/brcm/
    '')
  ];
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
