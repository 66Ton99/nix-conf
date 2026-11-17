{ lib, ... }:
{
  # Upstream nixos-hardware provides the updated 6.18 patchset and T2BCE driver stack.
  # Ensure required LUKS and input modules are available in initrd for root unlock:
  boot.initrd.kernelModules = [
    "dm_mod" "dm_crypt" "t2bce_core" "t2bce_vhci" "usbhid"
  ];
  boot.kernelModules = [ "t2bce_audio" "uhid" ];

  # Linux 6.18.57 can load this alternative alongside the normal button driver.
  # It binds PNP0C0C/LNXPWRBN and sends signal 38 (SIGRTMIN+4) directly to PID 1,
  # bypassing evdev grabs, GNOME and logind's HandlePowerKey=lock policy.
  # Keep the regular ACPI button driver as the sole owner, including in initrd.
  boot.blacklistedKernelModules = [ "tiny_power_button" ];
  boot.kernelParams = [ "module_blacklist=tiny_power_button" ];

  # 6.18.57 backported the button driver's platform conversion without its
  # fixed-event enumeration prerequisite. LNXPWRBN:00 otherwise has no input
  # device, so blacklisting tiny_power_button alone leaves the key inert.
  # Upstream: ab06eb9204010c61e754bf4e71ee6f554584714d.
  boot.kernelPatches = [ {
    name = "acpi-fixed-event-buttons";
    patch = ./patches/acpi-fixed-event-buttons.patch;
    structuredExtraConfig.ACPI_TINY_POWER_BUTTON = lib.kernel.no;
  } ];
}
