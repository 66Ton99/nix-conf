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
    sonar-scanner-cli
    nodejs
    ant
    go
    codexPkg
#    rustc
#    cargo
  ];
}
