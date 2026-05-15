{ config, inputs, pkgs, programs, ... }:
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
  nixpkgs.overlays = [
    inputs.hf-nix.overlays.default
  ];

  environment.systemPackages = with pkgs; [
    android-tools
    androidSdk.androidsdk
    python3Packages.hf-transfer
    python3Packages.hf-xet
    python3Packages.huggingface-hub
  ];
  # lmstudio

}
