# ton-machine (MacBookPro16,1 / Apple T2)

This directory owns the NixOS configuration migrated from `/etc/nixos`.
It keeps the working NixOS 26.05 input, nixos-hardware revision, T2 patches,
Wi-Fi firmware, disks, boot entries, enterprise services, and shared Oracle
Linux mounts. Other hosts keep their existing inputs and modules.

From `~/nix` on this machine:

```sh
make build          # evaluate and build without activation
make dry-activate   # inspect activation changes
make switch         # build, activate, and set the boot generation
```

The hostname selects `ton-machine` automatically. `ton-nixos` remains an alias.
Use `make` from this repository for rebuilds; `/etc/nixos` is retained as the
pre-migration fallback. The lock wrapper selects `flake.lock.linux`.
To update this machine's packages separately, run
`make flake/update nixpkgs-ton-machine nixos-hardware LOCK_PLATFORM=linux`;
change the pinned URLs in `flake.nix` when intentionally upgrading them.

`user-settings.nix` manages the existing Zsh configuration, Chrome default
associations, GTK bookmarks, and US/Ukrainian input sources. The custom
`ua_mac` layout in `xkb/ua_mac` keeps macOS punctuation with І on S, И on B,
Ґ/ґ on the backtick key, and apostrophe/tilde on the backslash key. GNOME input
sources are locked to the declared list so saved desktop settings cannot override it.
After first applying this custom layout, log out and back in so GNOME loads
the configured XKB directory. Switch
between input sources in GNOME with Super+Space (Command+Space on the Mac keyboard).
Change the files in
`dotfiles/` and rebuild to apply edits. Replaced configuration files are backed
up under `~/.local/state/nixos/config-backups/` during activation.

## Existing machine data required

These private or mutable files are intentionally referenced at runtime. Back
them up separately before reinstalling; this repository does not recreate them:

- `/etc/nixos-secrets/ton-password-hash` (root-only user password hash)
- The existing encrypted disks and their unlock passphrases
- `/mnt/oracle/opt` (shared vendor application installations)
- `/mnt/oracle/etc/pki` and the Oracle Linux trust sources
- `/home/.shared-system/cisco` (VPN state, policy, and certificates)
- Browser profiles, keyrings, SSH keys, and other private home-directory data

Disk UUIDs in `hardware-configuration.nix` identify this installation. For a
replacement disk or another machine, regenerate that file and provision the
runtime data before switching. Nothing in these instructions repartitions disks.

To roll back activation, use `sudo nixos-rebuild switch --rollback`.
The original `/etc/nixos` remains available for an explicit fallback rebuild:
`sudo nixos-rebuild switch --flake /etc/nixos#ton-machine`.
