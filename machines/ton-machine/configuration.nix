{ config, lib, pkgs, ... }:
let
  sudoFingerprintSuccess = pkgs.writeShellScript "sudo-fingerprint-success" ''
    printf '%s\n' 'Fingerprint scan successful.'
  '';
in
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
      default = "0";
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

  # Use rootless Podman for kind rather than kind's Docker auto-detection.
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
  };
  environment.variables.KIND_EXPERIMENTAL_PROVIDER = "podman";

  # Start Podman's rootless Docker-compatible API socket for Compose clients.
  systemd.user.sockets.podman = {
    description = "Podman API Socket";
    wantedBy = [ "sockets.target" ];
    listenStreams = [ "%t/podman/podman.sock" ];
    socketConfig.SocketMode = "0660";
  };

  security.pam.services = {
    sudo = {
      fprintAuth = true;

      # Keep fprintd's password fallback while allowing a success message
      # to run only after fingerprint authentication succeeds.
      rules.auth.fprintd.control = lib.mkForce "[success=ok default=1]";
      rules.auth.fingerprint-success = {
        order = config.security.pam.services.sudo.rules.auth.fprintd.order + 10;
        control = "[success=done default=ignore]";
        modulePath = "${config.security.pam.package}/lib/security/pam_exec.so";
        args = [ "stdout" "${sudoFingerprintSuccess}" ];
      };
    };
    su.fprintAuth = true;
    gdm-fingerprint.rules.auth.systemd_loadkey = {
      enable = true;
      order = 10650;
      control = "optional";
      modulePath = "${config.systemd.package}/lib/security/pam_systemd_loadkey.so";
      settings = {
        keyname = "cryptsetup";
      };
    };
    gdm-autologin.rules.auth.systemd_loadkey = {
      enable = true;
      order = 10350;
      control = "optional";
      modulePath = "${config.systemd.package}/lib/security/pam_systemd_loadkey.so";
      settings = {
        keyname = "cryptsetup";
      };
    };
  };

  # Allow GDM to inherit root's kernel keyring where systemd-cryptsetup caches the LUKS passphrase
  systemd.services.display-manager.serviceConfig.KeyringMode = lib.mkForce "inherit";

  # Ensure GDM greeter enables Touch ID authentication explicitly
  programs.dconf.profiles.gdm.databases = [
    {
      settings = {
        "org/gnome/login-screen" = {
          enable-fingerprint-authentication = true;
        };
      };
    }
  ];
  services.printing.enable = true;

  # Allow user access to /dev/uhid for the virtual Touch ID FIDO2 / WebAuthn token
  services.udev.extraRules = ''
    KERNEL=="uhid", SUBSYSTEM=="misc", GROUP="ton", MODE="0660", TAG+="uaccess"
  '';

  # Touch ID Virtual FIDO2 token daemon for WebAuthn in Chrome / browsers
  systemd.user.services.touchid-fido2 = {
    description = "Touch ID Virtual FIDO2 / WebAuthn Token";
    wantedBy = [ "default.target" ];
    path = with pkgs; [ coreutils fprintd libnotify ];
    environment = {
      RUST_LOG = "info";
    };
    serviceConfig = {
      ExecStart = "/home/ton/.local/bin/touchid-fido2";
      Restart = "always";
      RestartSec = 2;
    };
  };

  # Keep the Apple T2 SMC charge limit at the requested 80% after boot.
  systemd.services.battery-charge-limit = {
    description = "Set Apple T2 battery charge limit to 80%";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-udev-trigger.service" ];
    path = with pkgs; [ coreutils findutils ];
    serviceConfig.Type = "oneshot";
    script = ''
      for attempt in $(seq 1 30); do
        attribute="$(find /sys/devices -type f -name battery_charge_limit -print -quit)"
        if [ -n "$attribute" ]; then
          printf '80\n' > "$attribute"
          exit 0
        fi
        sleep 1
      done

      echo "Apple SMC battery_charge_limit sysfs attribute was not found" >&2
      exit 1
    '';
  };

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
    guake vim curl pciutils usbutils cryptsetup chromium libnotify unstable.docker-compose
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
