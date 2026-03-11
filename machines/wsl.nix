{ pkgs, currentSystemUser, ... }: {
  imports = [];

  wsl = {
    enable = true;
    wslConf.automount.root = "/mnt";
    defaultUser = currentSystemUser;
    startMenuLaunchers = true;
  };

  nix = {
#    package = pkgs.nixUnstable;
    extraOptions = ''
      experimental-features = nix-command flakes
      keep-outputs = true
      keep-derivations = true
    '';
  };

  networking.hostName = "wsl";

  fileSystems."/mnt/e" = {
    device = "E:";
    fsType = "drvfs";
  };
  

  system.stateVersion = "25.11";
}
