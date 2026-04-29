{ pkgs, inputs, ... }:
{
  environment.systemPackages = with pkgs; [
    gcc
    cmake
    oci-cli
    sonar-scanner-cli
    nodejs
    ant
    go
    unstable.codex
#    rustc
#    cargo
  ];
}
