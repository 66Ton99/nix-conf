# NixOS System Configurations

This is clone of https://github.com/mitchellh/nixos-config all basic documentation there.

I made some changes for my cases.

## This NixOS machine

`ton-machine` is the Apple T2 MacBook running NixOS. Its configuration and
reinstallation prerequisites are documented in [machines/ton-machine](machines/ton-machine/README.md).

```sh
cd ~/nix
make build
make switch
```

`ton-machine` uses the same `lib/mksystem.nix` builder as the other hosts:
`users/default.nix` supplies shared packages and fonts, `users/ton/nixos.nix`
supplies Linux user defaults, and `users/ton/home-manager.nix` manages the
shared user environment. `machines/ton-machine.nix` imports the machine's
modules in `machines/ton-machine/` and the shared `pkgs/dev.nix` tools.
The working NixOS 26.05 and hardware inputs remain pinned separately from
the other hosts.

The shared `pkgs/dev.nix` installs Google Antigravity App (`antigravity`),
Antigravity IDE (`antigravity-ide`), and Antigravity CLI (`agy`)
on every configured host, including WSL and
both Intel and Apple Silicon Macs. Antigravity CLI replaces Gemini CLI.
The CLI and Intel Mac GUI builds use pinned official Google releases; the other
GUI builds follow the existing unstable lock. Run `make switch` on each
machine to apply the shared configuration.

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
