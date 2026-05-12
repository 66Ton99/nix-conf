{ config, pkgs, programs, ... }:
let
  androidSdk = pkgs.androidenv.composeAndroidPackages {
    includeEmulator = false;
    includeSystemImages = false;
    includeNDK = false;
    includeCmake = false;
    platformVersions = [ ];
    buildToolsVersions = [ ];
  };
in {
  imports = [
    ../pkgs/dev.nix
  ];

  nixpkgs.config.android_sdk.accept_license = true;
  
  environment.systemPackages = with pkgs; [
    android-tools
    androidSdk.androidsdk
  ];
  # lmstudio

}
