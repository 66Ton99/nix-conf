{ pkgs, inputs, ... }:
{
  environment.systemPackages = with pkgs; [
#    gcc
    cmake
    sonar-scanner-cli
    nodejs_20
    ant
  ];
}
