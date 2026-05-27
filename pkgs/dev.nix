{ pkgs, inputs, ... }:
let
  codexPkg = pkgs.unstable.codex;
  antWithJdk = pkgs.writeShellScriptBin "ant" ''
    export JAVA_HOME=${pkgs.jdk}
    export NIX_JVM=${pkgs.jdk}/bin/java
    exec ${pkgs.ant}/bin/ant "$@"
  '';
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
    antWithJdk
    go
    codexPkg
#    rustc
#    cargo
  ];
}
