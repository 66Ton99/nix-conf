{ pkgs, inputs, ... }:
{
  environment.systemPackages = with pkgs; [
#    gcc
    cmake
    sonar-scanner-cli
  ];
}
