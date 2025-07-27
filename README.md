# NixOS System Configurations

This is clone of https://github.com/mitchellh/nixos-config all basic documentation there.

I made some changes for my cases.

## Run on MacOS
```shell
nix --extra-experimental-features 'nix-command flakes' build ".#darwinConfigurations.mac-i9.system"
```


