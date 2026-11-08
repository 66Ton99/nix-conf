{ lib, pkgs, ... }:
let
  # The host's 0.15.7 predates --validate-config. Use the repository's existing
  # pinned unstable package so validation never needs to open input devices.
  xremap = pkgs.unstable.xremap;
  extension = pkgs.gnomeExtensions.xremap;
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
        name = "Guake handles Command copy and paste natively";
        application.only = [ guake ];
        exact_match = true;
        # First matching rule wins; leave these for Guake's GTK accelerators.
        remap = { Super-c = "Super-c"; Super-v = "Super-v"; };
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
    "org/gnome/shell/keybindings" = {
      toggle-overview = [ "<Super>space" ];
      toggle-message-tray = emptyShortcuts;
    };
    "org/gnome/mutter".overlay-key = "";
    "org/guake/keybindings/local" = {
      clipboard-copy = "<Super>c";
      clipboard-paste = "<Super>v";
    };
    "org/gnome/settings-daemon/plugins/media-keys".screensaver = [ "<Control><Super>q" ];
    "org/gnome/shell" = {
      enabled-extensions = [ extension.extensionUuid ];
      disable-user-extensions = false;
    };
  };
in {
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

  environment.systemPackages = [ xremap extension ];
  hardware.uinput.enable = true;
  users.users.ton.extraGroups = [ "input" "uinput" ];
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
      ExecStart = "${lib.getExe xremap} --desktop=gnome --watch=device --no-window-logging ${keyboardConfig}";
      Restart = "on-failure";
      RestartSec = "3s";
      UMask = "0077";
    };
  };
}
