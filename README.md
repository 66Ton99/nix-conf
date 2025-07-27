# NixOS System Configurations

This is clone of https://github.com/mitchellh/nixos-config all basic documentation there.

I made some changes for my cases.

## Install Nix
```shell
curl -fsSL https://install.determinate.systems/nix | sh -s -- install --determinate
# OR
make install
```

## Install nix-darwin
```shell
sudo nix run nix-darwin -- switch --flake /Volumes/SRC/nix-conf#mac-m4 --show-trace
# OR
make setup
```

## Switch
```shell
sudo darwin-rebuild switch --flake /Volumes/SRC/nix-conf#mac-m4 --show-trace
# OR
make switch
# OR
make
```
