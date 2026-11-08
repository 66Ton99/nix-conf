{ config, lib, pkgs, ... }:
let
  tonEnvironment = {
    DCONF_PROFILE = "user";
    XDG_CONFIG_HOME = "/home/ton/.config/nixos";
    XDG_CACHE_HOME = "/home/ton/.cache/nixos";
    XDG_DATA_HOME = "/home/ton/.local/share/nixos";
    XDG_STATE_HOME = "/home/ton/.local/state/nixos";
    ZDOTDIR = "/home/ton/.config/nixos/zsh";
    CARGO_HOME = "/home/ton/.local/share/nixos/cargo";
    RUSTUP_HOME = "/home/ton/.local/share/nixos/rustup";
    NPM_CONFIG_USERCONFIG = "/home/ton/.config/nixos/npm/npmrc";
    NPM_CONFIG_CACHE = "/home/ton/.cache/nixos/npm";
    PYTHONUSERBASE = "/home/ton/.local/share/nixos/python";
    GTK2_RC_FILES = "/home/ton/.config/nixos/gtk-2.0/gtkrc";
    GIT_CONFIG_GLOBAL = "/home/ton/.config/nixos/git/config";
  };
  exports = lib.concatStringsSep "\n" (lib.mapAttrsToList
    (name: value: "export ${name}=${lib.escapeShellArg value}") tonEnvironment);
  generator = pkgs.writeShellScript "ton-session-environment" ''
    if [ "$(${pkgs.coreutils}/bin/id -u)" = 1000 ]; then
      printf '%s\n' ${lib.concatStringsSep " " (lib.mapAttrsToList
        (name: value: lib.escapeShellArg "${name}=${value}") tonEnvironment)}
    fi
  '';
  greeterEnvironment = pkgs.writeText "gdm-greeter-profile.env" ''
    XDG_CONFIG_HOME OVERRIDE="@{HOME}/.config"
    XDG_CACHE_HOME OVERRIDE="@{HOME}/.cache"
    XDG_DATA_HOME OVERRIDE="@{HOME}/.local/share"
    XDG_STATE_HOME OVERRIDE="@{HOME}/.local/state"
    DCONF_PROFILE OVERRIDE="gdm"
  '';
  shortcut = "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/nixos-guake/";
in {
  # GDM 50 writes its environment.d/gdm.conf into its default .config.
  # Applying ton's XDG paths to the greeter hides that file and its DCONF_PROFILE.
  environment.extraInit = lib.mkAfter ''
    if [ "$(${pkgs.coreutils}/bin/id -u)" = 1000 ]; then
      ${exports}
    fi
  '';
  environment.etc."systemd/user-environment-generators/10-ton-session".source = generator;

  services.displayManager.autoLogin.enable = lib.mkForce false;
  services.displayManager.defaultSession = "gnome";
  security.pam.services.gdm-launch-environment.rules.session.greeter-profile = {
    order = config.security.pam.services.gdm-launch-environment.rules.session.env-greeter.order + 10;
    control = "required";
    modulePath = "${config.security.pam.package}/lib/security/pam_env.so";
    settings = {
      conffile = greeterEnvironment;
      readenv = 0;
    };
  };
  programs.dconf.profiles.gdm.databases = lib.mkBefore [ {
    settings."org/gnome/desktop/session".session-name = "gnome-login";
    locks = [ "/org/gnome/desktop/session/session-name" ];
  } ];

  # On Wayland the compositor owns global shortcuts.
  programs.dconf.profiles.user.databases = [ {
    settings = {
      "org/gnome/settings-daemon/plugins/media-keys".custom-keybindings = [ shortcut ];
      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/nixos-guake" = {
        name = "Guake";
        command = "${pkgs.guake}/bin/guake-toggle";
        binding = "F1";
      };
      "org/guake/general" = {
        default-shell = "${pkgs.zsh}/bin/zsh";
        use-login-shell = true;
        restore-tabs-startup = false;
      };
      "org/guake/keybindings/global".show-hide = "F1";
    };
  } ];
  environment.systemPackages = [ pkgs.gnome-console ];
  systemd.user.services.guake = {
    description = "Guake terminal for ton";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session-pre.target" ];
    unitConfig.ConditionUser = "ton";
    # Terminal children need system programs and privileged wrappers, rather
    # than only systemd's small default service PATH.
    path = lib.mkBefore [ "/run/wrappers" "/run/current-system/sw" ];
    serviceConfig = {
      ExecStart = "${pkgs.guake}/bin/guake";
      Restart = "on-failure";
      RestartSec = "3s";
    };
  };
}
