# ton-machine (MacBookPro16,1 / Apple T2)

This directory owns the NixOS configuration migrated from `/etc/nixos`.
It keeps the working NixOS 26.05 input, nixos-hardware revision, T2 patches,
Wi-Fi firmware, disks, boot entries, enterprise services, and shared Oracle
Linux mounts. Other hosts keep their existing inputs and modules.

`flake.nix` creates this host through `lib/mksystem.nix`, using the separately
pinned `nixpkgs-ton-machine` input. `machines/ton-machine.nix` imports this
directory and `pkgs/dev.nix`. The builder also loads shared overlays,
`users/default.nix`, `users/ton/nixos.nix`, and `users/ton/home-manager.nix`.
The host overrides the legacy VM authentication defaults with its runtime
password-hash file and an empty declared SSH authorized-key list.

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

`user-settings.nix` adds host-specific Home Manager settings for Zsh, Chrome
default associations, and GTK bookmarks. `keyboard.nix` declares US/Ukrainian
input sources and macOS shortcuts through the system dconf profile and xremap.
Home Manager keeps the existing
NixOS-specific XDG directories, uses the shared Git and Oh My Zsh configuration,
and leaves Oracle Linux's shared Bash startup files, `~/.zshenv`, and default
GnuPG directory unmanaged. The custom
`ua_mac` layout in `xkb/ua_mac` keeps macOS punctuation with І on S, И on B,
Ґ/ґ on the backtick key, and apostrophe/tilde on the backslash key. GNOME input
sources and keyboard preferences are locked so saved desktop settings cannot
override them. After first applying these settings, log out and back in so GNOME
loads the XKB directory, the xremap extension, and the new input/uinput groups.
The xremap user service runs only in ton's GNOME session and watches for newly
connected keyboards. Physical Control and Option/Alt retain their modifier
roles; Command is the existing Super key on the Apple keyboard.

| Shortcut | Action |
| --- | --- |
| Control+Space / Control+Shift+Space | Next / previous input source |
| Command+Space | Overview and application search |
| Command+Tab / Command+Shift+Tab | Next / previous application |
| Command+backtick | Next window of the same application |
| Command+C/V/X/A/Z, Shift+Command+Z | Copy, paste, cut, select all, undo, redo |
| Command+T/W/N/Q/S/F/L | Tabs, windows, quit, save, find, location (where supported) |
| Command+Left/Right; Shift to select | Start / end of line |
| Command+Up/Down; Shift to select | Start / end of document |
| Option+Left/Right; Shift to select | Move by word |
| Option+Backspace/Delete | Delete previous / next word |
| Command+Backspace | Delete to start of line |
| Command+M / Command+H | Minimize current window |
| Control+Command+Q | Lock screen |

Guake binds Command+C/V natively through its declared GTK accelerators, so
clipboard shortcuts also work before xremap starts. xremap recognizes its
Nix-wrapped window class (`.guake-wrapped`) and passes these two shortcuts
through unchanged. Other terminals map Command+C/V to Ctrl+Shift+C/V.
Command+T/W uses Ctrl+Shift+T/W, and physical Ctrl+C still interrupts commands.
Command+Left/Right and Command+Backspace use shell editing shortcuts; Option
arrows move by word. Other application shortcuts depend on the application's
Linux defaults. The mappings do not emulate all macOS application behavior or
the Option special-character layer. The existing Ukrainian Mac punctuation
and corrected letter positions remain in `xkb/ua_mac`.

The setup uses the existing unstable pin for the standard xremap package (with
`--desktop=gnome` and `--validate-config`) and the host pin for the GNOME extension,
following the [upstream user service](https://github.com/xremap/nix-flake/blob/master/modules/user-service.nix).
Its generated configuration is validated by xremap during every build.
Change the shared user modules or files in `dotfiles/` and rebuild to apply
edits. On adoption, Home Manager backs up replaced files with the suffix
`.before-home-manager`. Backups from the previous activation script remain
under `~/.local/state/nixos/config-backups/`.

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
