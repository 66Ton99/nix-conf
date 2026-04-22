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

## Platform-specific lock files
This repo now keeps separate lock files per main platform:
- `flake.lock.linux`
- `flake.lock.darwin`

`make switch`, `make test`, and `make flake/update` automatically use the right lock based on `uname`.

To update a specific platform lock from any machine:
```shell
make flake/update LOCK_PLATFORM=linux
make flake/update LOCK_PLATFORM=darwin
```

To update only one flake input instead of all of them:
```shell
make flake/update ton-unstable
make flake/update nixpkgs-unstable LOCK_PLATFORM=linux
```
