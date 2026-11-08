{ lib, pkgs, ... }:
let
  configHome = "/home/ton/.config/nixos";
  backupDir = "/home/ton/.local/state/nixos/config-backups";
  files = [
    { name = "zshrc"; target = "zsh/.zshrc"; source = ./dotfiles/zshrc; }
    { name = "mimeapps.list"; target = "mimeapps.list"; source = ./dotfiles/mimeapps.list; }
    { name = "gtk-bookmarks"; target = "gtk-3.0/bookmarks"; source = ./dotfiles/gtk-bookmarks; }
  ];
  linkFile = file: ''
    destination=${lib.escapeShellArg "${configHome}/${file.target}"}
    ${pkgs.coreutils}/bin/install -d -m 0700 -o ton -g ton "$(dirname "$destination")"
    if [ ! -L "$destination" ] || [ "$(readlink "$destination")" != ${lib.escapeShellArg "${file.source}"} ]; then
      if [ -e "$destination" ] || [ -L "$destination" ]; then
        ${pkgs.coreutils}/bin/cp -a --backup=numbered "$destination" ${lib.escapeShellArg "${backupDir}/${file.name}"}
      fi
      ${pkgs.coreutils}/bin/ln -sfn ${lib.escapeShellArg "${file.source}"} "$destination"
      ${pkgs.coreutils}/bin/chown -h ton:ton "$destination"
    fi
  '';
in {
  # Capture preferences from the running desktop; window history stays mutable.
  programs.dconf.profiles.user.databases = [ {
    # Keep the declared layout authoritative over previously saved GNOME sources.
    locks = [ "/org/gnome/desktop/input-sources/sources" ];
    settings."org/gnome/desktop/input-sources" = {
      sources = with lib.gvariant; [ (mkTuple [ "xkb" "us" ]) (mkTuple [ "xkb" "ua_mac" ]) ];
      xkb-options = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
    };
  } ];

  # Manage only selected configuration files, preserving the originals on adoption.
  system.activationScripts.ton-user-settings = lib.stringAfter [ "users" ] ''
    ${pkgs.coreutils}/bin/install -d -m 0700 -o ton -g ton ${lib.escapeShellArg backupDir}
    ${lib.concatMapStringsSep "\n" linkFile files}
  '';
}
