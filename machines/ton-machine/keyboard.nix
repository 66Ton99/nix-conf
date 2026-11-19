{ lib, pkgs, ... }:
let
  # The host's 0.15.7 predates --validate-config. Use the repository's existing
  # pinned unstable package so validation never needs to open input devices.
  xremap = pkgs.unstable.xremap;
  extension = pkgs.gnomeExtensions.xremap;
  macosOsd = pkgs.stdenvNoCC.mkDerivation {
    pname = "ton-macos-osd";
    version = "1.0.0";
    src = ./macos-osd;
    installPhase = ''
      runHook preInstall
      install -d "$out/share/gnome-shell/extensions/macos-osd@ton"
      install -m644 metadata.json extension.js stylesheet.css \
        "$out/share/gnome-shell/extensions/macos-osd@ton/"
      runHook postInstall
    '';
  };
  sessionPython = pkgs.python3.withPackages (p: [ p.dbus-python p.pygobject3 ]);
  emptyShortcuts = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
  # Nix's executable wrapper is also Guake's actual WM_CLASS on this host.
  guake = "/(?i)^\\.?guake(-wrapped)?$/";
  terminals = [
    guake
    "/(?i)^(org\\.gnome\\.(Console|Terminal)|gnome-terminal(-server)?|kgx|kitty|Alacritty|com\\.mitchellh\\.ghostty|ghostty|konsole|org\\.kde\\.konsole|wezterm|org\\.wezfurlong\\.wezterm|foot|xterm)(\\..*)?$/"
  ];
  # Declare Shift variants explicitly so Ctrl+Command and Option+Command
  # combinations keep their own meaning (in particular Ctrl+Command+Q).
  withShift = bindings: bindings // lib.mapAttrs'
    (key: value: lib.nameValuePair "Shift-${key}" "Shift-${value}") bindings;
  commandKeys = [
    "a" "b" "c" "d" "e" "f" "g" "i" "j" "k" "l" "n" "o" "p"
    "q" "r" "s" "t" "u" "v" "w" "x" "y" "z"
    "0" "1" "2" "3" "4" "5" "6" "7" "8" "9"
    "Comma" "Dot" "Slash" "Minus" "Equal" "LeftBrace" "RightBrace"
  ];
  rawConfig = (pkgs.formats.yaml { }).generate "macos-keyboard.yaml" {
    keymap = [
      {
        name = "Guake handles Command shortcuts natively";
        application.only = [ guake ];
        exact_match = true;
        # Route arrows to Guake's tab accelerators because Mutter grabs
        # Super+Left/Right globally for window tiling.
        remap = {
          Super-c = "Super-c";
          Super-v = "Super-v";
          Super-Left = "Ctrl-PageUp";
          Super-Right = "Ctrl-PageDown";
          Super-k = "Ctrl-Shift-F12";
        };
      }
      {
        name = "macOS terminal shortcuts; physical Control stays Control";
        application.only = terminals;
        exact_match = true;
        remap = {
          Super-c = "Ctrl-Shift-c";
          Super-v = "Ctrl-Shift-v";
          Super-a = "Ctrl-Shift-a";
          Super-t = "Ctrl-Shift-t";
          Super-w = "Ctrl-Shift-w";
          Super-n = "Ctrl-Shift-n";
          Super-f = "Ctrl-Shift-f";
          Super-q = "Ctrl-Shift-q";
          Super-k = "Ctrl-l";
          Super-Left = "Ctrl-a";
          Super-Right = "Ctrl-e";
          Super-BackSpace = "Ctrl-u";
          Alt-Left = "Alt-b";
          Alt-Right = "Alt-f";
          Alt-BackSpace = "Ctrl-w";
        };
      }
      {
        name = "macOS browser quit";
        application.only = [ "/(?i)^(firefox|chromium|google-chrome|chrome|brave-browser)(-.*)?$/" ];
        exact_match = true;
        remap.Super-q = "Ctrl-Shift-q";
      }
      {
        name = "macOS application shortcuts";
        application.not = terminals;
        exact_match = true;
        remap = withShift (lib.listToAttrs (map
          (key: lib.nameValuePair "Super-${key}" "Ctrl-${key}") commandKeys));
      }
      {
        name = "macOS text navigation and deletion";
        application.not = terminals;
        exact_match = true;
        remap = withShift {
          Super-Left = "Home";
          Super-Right = "End";
          Super-Up = "Ctrl-Home";
          Super-Down = "Ctrl-End";
          Alt-Left = "Ctrl-Left";
          Alt-Right = "Ctrl-Right";
        } // {
          Alt-BackSpace = "Ctrl-BackSpace";
          Alt-Delete = "Ctrl-Delete";
          Super-BackSpace = [ "Shift-Home" "BackSpace" ];
        };
      }
    ];
  };
  # Validate with the same pinned binary that will run in the session.
  keyboardConfig = pkgs.runCommand "macos-keyboard.yaml" { } ''
    ${lib.getExe xremap} --validate-config ${rawConfig}
    cp ${rawConfig} "$out"
  '';
  lockScreen = pkgs.writeShellScript "power-button-lock-screen" ''
    set -eu
    bus() {
      ${pkgs.systemd}/bin/busctl \
        --address="unix:path=/run/power-button-users/$(${pkgs.coreutils}/bin/id -u)/bus" "$@"
    }
    active=$(bus call org.gnome.ScreenSaver /org/gnome/ScreenSaver org.gnome.ScreenSaver GetActive)
    if [ "$active" = "b true" ]; then
      # Real input wakes GNOME's shield as well as the physical display.
      # Merely setting PowerSaveMode leaves its fade overlay visible.
      YDOTOOL_SOCKET=/run/ydotoold/socket ${pkgs.ydotool}/bin/ydotool key 1:1 1:0
    else
      DBUS_SESSION_BUS_ADDRESS="unix:path=/run/power-button-users/$(${pkgs.coreutils}/bin/id -u)/bus" \
      XDG_RUNTIME_DIR="/run/power-button-users/$(${pkgs.coreutils}/bin/id -u)" \
        ${pkgs.systemd}/bin/systemctl --user start lock-brightness-capture.service || true
      bus call org.gnome.ScreenSaver /org/gnome/ScreenSaver org.gnome.ScreenSaver Lock
    fi
  '';
  rawPowerButtonConfig = (pkgs.formats.yaml { }).generate "power-button.yaml" {
    keymap = [ {
      name = "Physical power button locks or wakes the locked screen";
      # Invoke GNOME directly: the virtual KEY_COFFEE events reach the session
      # but GNOME does not activate its screen-lock accelerator on this host.
      # xremap discards launched commands' stderr; preserve D-Bus failures.
      remap.KEY_POWER.launch = [ "${pkgs.systemd}/bin/systemd-cat" "-t" "power-button-lock-screen" "${lockScreen}" ];
    } ];
  };
  powerButtonConfig = pkgs.runCommand "power-button.yaml" { } ''
    ${lib.getExe xremap} --validate-config ${rawPowerButtonConfig}
    cp ${rawPowerButtonConfig} "$out"
  '';
  settings = {
    "org/gnome/desktop/input-sources" = {
      sources = with lib.gvariant; [ (mkTuple [ "xkb" "us" ]) (mkTuple [ "xkb" "ua_mac" ]) ];
      # GNOME handles Ctrl+Space itself; an XKB toggle here would switch twice.
      xkb-options = emptyShortcuts;
      per-window = false;
    };
    "org/gnome/desktop/wm/keybindings" = {
      switch-input-source = [ "<Control>space" ];
      switch-input-source-backward = [ "<Shift><Control>space" ];
      switch-applications = [ "<Super>Tab" "<Alt>Tab" ];
      switch-applications-backward = [ "<Shift><Super>Tab" "<Shift><Alt>Tab" ];
      switch-group = [ "<Super>Above_Tab" ];
      switch-group-backward = [ "<Shift><Super>Above_Tab" ];
      minimize = [ "<Super>m" "<Super>h" ];
    };
    "org/gnome/desktop/wm/preferences".mouse-button-modifier = "<Alt>";
    "org/gnome/shell/keybindings" = {
      toggle-overview = [ "<Super>space" ];
      toggle-message-tray = emptyShortcuts;
    };
    "org/gnome/mutter".overlay-key = "";
    "org/guake/keybindings/local" = {
      clipboard-copy = "<Super>c";
      clipboard-paste = "<Super>v";
      previous-tab = "<Control>Page_Up";
      next-tab = "<Control>Page_Down";
      reset-terminal = "<Control><Shift>F12";
    };
    "org/gnome/settings-daemon/plugins/media-keys" = {
      screensaver = [ "<Control><Super>q" "XF86PowerOff" ];
      screensaver-static = [ "XF86ScreenSaver" ];
      # Release GNOME's built-in power action so the lock binding owns the key.
      power = emptyShortcuts;
      power-static = emptyShortcuts;
    };
    "org/gnome/settings-daemon/plugins/power" = {
      power-button-action = "nothing";
      # Keep the manually selected level stable across idle/lock transitions.
      ambient-enabled = false;
      idle-dim = false;
    };
    "org/gnome/shell" = {
      enabled-extensions = [ extension.extensionUuid "macos-osd@ton" ];
      disable-user-extensions = false;
    };
  };
in {
  # Fallback when GNOME is not handling power keys (for example on a TTY).
  services.logind.settings.Login = {
    HandlePowerKey = "lock";
    HandlePowerKeyLongPress = "lock";
  };

  # ACPI's Power Button is not a keyboard and is skipped by xremap's default
  # device selection. Grab it separately, before GDM, so neither GNOME nor
  # logind receives a physical KEY_POWER event. No desktop connection is needed.
  systemd.services.power-button-lock = {
    description = "Lock GNOME directly on ACPI power button presses";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-udev-trigger.service" "ydotoold.service" ];
    requires = [ "ydotoold.service" ];
    before = [ "display-manager.service" ];
    serviceConfig = {
      ExecStart = "${lib.getExe xremap} --desktop=none --allow-launch=true --device 'Power Button' --output-device-name 'xremap power-button' --watch=device ${powerButtonConfig}";
      User = "ton";
      SupplementaryGroups = [ "input" "uinput" "ydotool" ];
      Restart = "always";
      RestartSec = "1s";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      # Keep home directories hidden. Expose only runtime session sockets at
      # a separate mount point; uid permissions still restrict access to ton.
      BindReadOnlyPaths = [ "/run/user:/run/power-button-users" ];
      UMask = "0077";
    };
  };

  services.xserver.xkb = {
    layout = "us,ua_mac";
    variant = "";
    # Fallback for the greeter and X11 clients outside the GNOME session.
    options = "grp:ctrl_space_toggle";
    extraLayouts.ua_mac = {
      description = "Ukrainian (Mac, corrected)";
      languages = [ "ukr" ];
      symbolsFile = ./xkb/ua_mac;
    };
  };

  programs.dconf.profiles.user.databases = [ {
    inherit settings;
    # Saved settings must not mask these declared keyboard preferences.
    locks = lib.concatLists (lib.mapAttrsToList (schema: values:
      map (key: "/${schema}/${key}") (builtins.attrNames values)) settings);
  } ];

  # xremap grabs the built-in keyboard and emits its keystrokes through a
  # virtual device. Mark that output as internal so libinput pairs it with
  # the built-in touchpad for disable-while-typing.
  environment.etc."libinput/local-overrides.quirks".text = ''
    [xremap]
    MatchName=xremap
    MatchUdevType=keyboard
    AttrKeyboardIntegration=internal
  '';

  environment.systemPackages = [ xremap extension macosOsd ];
  hardware.uinput.enable = true;
  programs.ydotool.enable = true;
  users.users.ton.extraGroups = [ "input" "uinput" ];
  systemd.user.services.lock-brightness-capture = {
    description = "Save actual panel brightness before locking GNOME";
    wants = [ "lock-brightness.service" ];
    after = [ "lock-brightness.service" ];
    unitConfig.ConditionUser = "ton";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${sessionPython}/bin/python3 ${./lock-brightness.py} capture";
      UMask = "0077";
    };
  };
  systemd.user.services.lock-brightness = {
    description = "Restore panel brightness after unlocking GNOME";
    wantedBy = [ "gnome-session.target" ];
    after = [ "gnome-session.target" ];
    partOf = [ "graphical-session.target" ];
    unitConfig.ConditionUser = "ton";
    serviceConfig = {
      ExecStart = "${sessionPython}/bin/python3 ${./lock-brightness.py} watch";
      Restart = "on-failure";
      RestartSec = 2;
      UMask = "0077";
    };
  };
  # Follow xremap's upstream user-service setup, using the existing nixpkgs pin:
  # https://github.com/xremap/nix-flake/blob/master/modules/user-service.nix
  systemd.user.services.xremap = {
    description = "macOS keyboard shortcuts for ton";
    wantedBy = [ "gnome-session.target" ];
    after = [ "gnome-session.target" ];
    partOf = [ "graphical-session.target" ];
    unitConfig.ConditionUser = "ton";
    serviceConfig = {
      # The first switch adds group membership; it takes effect at next login.
      ExecCondition = "${pkgs.coreutils}/bin/test -w /dev/uinput";
      ExecStart = "${lib.getExe xremap} --desktop=gnome --ignore 'xremap power-button' --output-device-name 'xremap' --watch=device --no-window-logging ${keyboardConfig}";
      Restart = "on-failure";
      RestartSec = "3s";
      UMask = "0077";
    };
  };
}
