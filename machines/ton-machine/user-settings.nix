{ lib, pkgs, ... }:
let
  configHome = "/home/ton/.config/nixos";
  backupDir = "/home/ton/.local/state/nixos/config-backups";
  legacyFiles = [
    { target = "zsh/.zshrc"; name = "zshrc"; }
    { target = "mimeapps.list"; name = "mimeapps.list"; }
    { target = "gtk-3.0/bookmarks"; name = "gtk-bookmarks"; }
  ];
in {
  # Home Manager cannot adopt foreign symlinks with backupFileExtension.
  # Move only links owned by the previous system activation script.
  system.activationScripts.ton-adopt-home-manager = lib.stringAfter [ "users" ] ''
    ${pkgs.coreutils}/bin/install -d -m 0700 -o ton -g ton ${lib.escapeShellArg backupDir}
    ${lib.concatMapStringsSep "\n" (file: ''
      destination=${lib.escapeShellArg "${configHome}/${file.target}"}
      if [ -L "$destination" ]; then
        case "$(${pkgs.coreutils}/bin/readlink "$destination")" in
          /nix/store/*-${file.name})
            ${pkgs.coreutils}/bin/mv --backup=numbered "$destination" ${lib.escapeShellArg "${backupDir}/${file.name}"}
            ;;
        esac
      fi
    '') legacyFiles}
  '';

  home-manager.backupFileExtension = "before-home-manager";
  home-manager.users.ton = { config, lib, ... }: {
    # Keep NixOS desktop and shell state separate from the shared Oracle home.
    xdg = {
      configHome = "/home/ton/.config/nixos";
      cacheHome = "/home/ton/.cache/nixos";
      dataHome = "/home/ton/.local/share/nixos";
      stateHome = "/home/ton/.local/state/nixos";
      configFile."mimeapps.list".source = ./dotfiles/mimeapps.list;
      configFile."gtk-3.0/bookmarks".source = ./dotfiles/gtk-bookmarks;
    };
    home.sessionPath = [ ];
    # These files and the default GnuPG home are shared with Oracle Linux.
    programs.bash.enable = lib.mkForce false;
    programs.gpg.enable = lib.mkForce false;
    home.file.".zshenv".enable = false;
    programs.zsh = {
      initContent = lib.mkBefore (builtins.readFile ./dotfiles/zshrc);
      history.path = "${config.xdg.configHome}/zsh/.histfile";
      envExtra = ''
        export SCREENDIR="$HOME/.local/state/screen"
      '';
    };
  };
}
