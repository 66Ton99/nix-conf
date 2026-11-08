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
  home-manager.sharedModules = [
    ({ lib, pkgs, ... }: {
      # Home Manager 25.11 still uses pkgs.xorg.lndir for home-files.
      # Use its canonical dependency with this host's newer nixpkgs.
      options.home-files = lib.mkOption {
        apply = files: files.overrideAttrs { nativeBuildInputs = [ pkgs.lndir ]; };
      };
    })
  ];
  home-manager.users.ton = { config, lib, ... }: {
    dconf.settings."org/gnome/shell".favorite-apps = [
      "google-chrome.desktop"
      "org.gnome.Calendar.desktop"
      "org.gnome.Music.desktop"
      "org.gnome.TextEditor.desktop"
      "org.gnome.Nautilus.desktop"
      "chatgpt.desktop"
      "antigravity-hub.desktop"
      "antigravity-ide.desktop"
    ];
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
