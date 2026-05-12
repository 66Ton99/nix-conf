{ pkgs, inputs, ... }:
let
  codexPkg = pkgs.unstable.codex;
in
{
  _module.args.codexPkg = codexPkg;

  environment.systemPackages = with pkgs; [
    gcc
    cmake
    oci-cli
    google-cloud-sdk
    sonar-scanner-cli
    nodejs
    bun
    ant
    go
    codexPkg
#    rustc
#    cargo
  ];
}
