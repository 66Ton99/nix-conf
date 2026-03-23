{ config, pkgs, programs, ... }: {
  imports = [
    ../pkgs/dev.nix
  ];
  
  environment.systemPackages = with pkgs; [
  	android-tools
  ];
  # lmstudio

}
