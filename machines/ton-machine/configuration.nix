{ config, lib, pkgs, ... }:
{
  system.stateVersion = "26.05";
  system.nixos.versionSuffix = ".12658.1f607aa79b63";
  system.nixos.revision = "1f607aa79b6356ed45d3cd3c8079c196e79efa2c";
  networking.hostName = "ton-machine";
  networking.networkmanager.enable = true;
  time.timeZone = "Europe/Kyiv";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.supportedLocales = [ "en_US.UTF-8/UTF-8" "uk_UA.UTF-8/UTF-8" ];
  console.keyMap = "us";

  boot.loader = {
    efi = {
      efiSysMountPoint = "/boot/efi";
      canTouchEfiVariables = false;
    };
    grub = {
      enable = true;
      efiSupport = true;
      efiInstallAsRemovable = false;
      configurationLimit = 2;
      useOSProber = false;
      mirroredBoots = [ {
        path = "/boot";
        devices = [ "nodev" ];
        efiSysMountPoint = "/boot/efi";
        efiBootloaderId = "NixOS";
      } ];
      extraEntries = ''
        menuentry "Oracle Linux" --class gnu-linux --id oracle-linux {
          insmod part_gpt
          insmod fat
          search --no-floppy --fs-uuid --set=esp 5F66-17ED
          chainloader ($esp)/EFI/redhat/shimx64.efi
        }
        menuentry "macOS" --class osx --id macos-t2 {
          insmod part_gpt
          insmod fat
          search --no-floppy --fs-uuid --set=esp 5F66-17ED
          chainloader ($esp)/EFI/macos-grub/refind_x64.efi
        }
      '';
    };
    timeout = 8;
  };

  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  security.rtkit.enable = true;
  services.printing.enable = true;

  users.groups.ton.gid = 1000;
  users.users.ton = {
    isNormalUser = true;
    uid = 1000;
    group = "ton";
    home = "/home/ton";
    createHome = false;
    description = "ton";
    extraGroups = [ "wheel" "networkmanager" "dialout" ];
    # Runtime file outside this flake: the hash is never copied into /nix/store.
    hashedPasswordFile = "/etc/nixos-secrets/ton-password-hash";
    hashedPassword = null;
    openssh.authorizedKeys.keys = [ ];
  };

  # Per-user paths are configured in desktop-repair.nix; GDM keeps its own environment.
  environment.localBinInPath = false;
  environment.homeBinInPath = false;
  programs.zsh = {
    enable = true;
    histFile = "$HOME/.local/state/nixos/zsh/history";
  };
  environment.systemPackages = with pkgs; [
    guake vim curl pciutils usbutils cryptsetup chromium
  ];
  systemd.tmpfiles.rules = [
    "d /home/ton/.config/nixos 0700 ton ton -"
    "d /home/ton/.config/nixos/zsh 0700 ton ton -"
    "d /home/ton/.cache/nixos 0700 ton ton -"
    "d /home/ton/.local/share/nixos 0700 ton ton -"
    "d /home/ton/.local/state/nixos 0700 ton ton -"
    "d /home/ton/.local/state/nixos/zsh 0700 ton ton -"
  ];

  # Both installations use the same swap. Resume must stay within one OS.
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;
  systemd.targets.suspend-then-hibernate.enable = false;
  systemd.sleep.settings.Sleep = {
    AllowHibernation = false;
    AllowHybridSleep = false;
    AllowSuspendThenHibernate = false;
  };

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
    substituters = [ "https://cache.soopy.moe" ];
    trusted-public-keys = [
      "cache.soopy.moe-1:0RZVsQeR+GOh0VQI9rvnHz55nVXkFardDqfm4+afjPo="
    ];
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
}
