{ lib, pkgs, t2Hardware, ... }:
let
  # nixos-hardware's pinned patchset predates the Linux 6.18.56 backports.
  # Use t2linux's updated 6.18 patchset and its replacement BCE driver stack.
  # Upstream: t2linux/linux-t2-patches@4bd58ee8d301c7ee199fe8640276813d50f7357a
  # Archive SHA256: recorded in patches/upstream-6.18.txt.
  updatedNames = lib.filter (lib.hasSuffix ".patch") (
    builtins.attrNames (builtins.readDir ./patches/t2-6.18)
  );
  updatedKernel = pkgs.callPackage (t2Hardware + "/apple/t2/pkgs/linux-t2") {
    argsOverride.kernelPatches = map (name: {
      inherit name;
      patch = pkgs.writeText name (
        builtins.readFile (./patches/t2-6.18 + "/${name}")
      );
    }) updatedNames;
    argsOverride.structuredExtraConfig = with lib.kernel; {
      T2BCE_CORE = module;
      T2BCE_VHCI = module;
      T2BCE_AUDIO = module;
      T2BCE_AVE = module;
      APPLE_GMUX = module;
      APFS_FS = module;
      BRCMFMAC = module;
      BT_BCM = module;
      BT_HCIBCM4377 = module;
      BT_HCIUART_BCM = yes;
      BT_HCIUART = module;
      HID_APPLETB_BL = module;
      HID_APPLETB_KBD = module;
      HID_APPLE = module;
      HID_MAGICMOUSE = module;
      DRM_APPLETBDRM = module;
      HID_SENSOR_ALS = module;
      SND_PCM = module;
      STAGING = yes;
    };
  };
in
{
  boot.kernelPackages = lib.mkForce (pkgs.linuxPackagesFor updatedKernel);
  # Upstream replaced apple-bce with the separate T2 BCE core and VHCI drivers.
  boot.initrd.kernelModules = lib.mkForce [
    "dm_mod" "dm_crypt" "t2bce_core" "t2bce_vhci" "usbhid"
  ];
  boot.kernelModules = [ "t2bce_audio" ];
}
