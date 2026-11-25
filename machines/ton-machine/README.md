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

## Rootless Podman and kind

Podman stores rootless container data below `/var/lib/containers/ton`, backed
by `/mnt/oracle/var/lib/containers/ton`. The Oracle filesystem keeps its
`nosuid,nodev` flags; the dedicated container-storage bind mount enables
`suid,dev`. The checked-in `kind-ofs.yaml` pins the tested node image and
preserves the existing OFS node's port mapping and data/source mounts. Kind
uses this image only when creating a node; it does not change an existing
node's image. The active OFS cluster is managed by
`/mnt/src/OFS/docker/kind/start.sh` and must not be recreated without an etcd
data recovery plan. `kind-ofs-runtime.nix` switches the existing node's CRI
snapshotter to its bundled `fuse-overlayfs` service in place, preserving the
node image and etcd volume. A user systemd timer reapplies the runtime repair
after node restarts.


## Touch ID and Biometric Unlock

This machine is configured with Touch ID via the `KaiT2en` bridge and `fprintd`:
- Biometric verification: PAM is configured with `fprintAuth = true` for `sudo`.
- Manual SEP unlock: `t2-touchid-unlock`, `t2-keybag-unlock`, `sks-lock-state`, and the signed `t2sep.ko` module are installed and provisioned automatically.
- Commands:
  - `sudo t2-touchid-unlock --check-only` (read-only precheck)
  - `sudo t2-touchid-unlock --accept-risk` (manual keybag unlock with macOS password)

The official OpenAI GUI with Codex is installed only on this host through
`pkgs/codex-desktop.nix`. Upstream now names the Linux app ChatGPT: launch
**ChatGPT** from the applications menu, or run `chatgpt` / `codex-desktop`.
The package pins the official Debian download by version and SHA-256 and
adapts its native libraries for NixOS; updates go through a rebuild.
NixOS is not an officially supported distribution for the Linux preview.
Home Manager pins ChatGPT, Antigravity App, and IntelliJ IDEA to GNOME's favorites alongside
the existing Chrome, Calendar, Music, Text Editor, and Files launchers.

`user-settings.nix` adds host-specific Home Manager settings for Zsh, Chrome
default associations, and GTK bookmarks. `keyboard.nix` declares US/Ukrainian
input sources and macOS shortcuts through the system dconf profile and xremap.
Home Manager keeps the existing
NixOS-specific XDG directories, uses the shared Git and Oh My Zsh configuration,
and leaves Oracle Linux's shared Bash startup files, `~/.zshenv`, and default
GnuPG directory unmanaged. The custom
`ua_mac` layout in `xkb/ua_mac` puts `?` on Shift+7 and `.`/`,` on one key
(comma with Shift), with І on S, И on B, Ґ/ґ on the backtick key, and
apostrophe/tilde on the backslash key. GNOME input sources and keyboard
preferences are locked so saved desktop settings cannot override them. After
first applying these settings, log out and back in so GNOME
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
| Command+Left/Right (Guake) | Previous / next tab |
| Command+K (Guake) | Reset terminal and clear its scrollback |
| Command+left-click (Guake) | Open the link under the pointer |
| Option/Alt+click-drag | Move GNOME windows |
| Command+Left/Right (other terminals) | Start / end of line |
| Command+Up/Down; Shift to select | Start / end of document |
| Option+Left/Right; Shift to select | Move by word |
| Option+Backspace/Delete | Delete previous / next word |
| Command+Backspace | Delete to start of line |
| Command+M / Command+H | Minimize current window |
| Control+Command+Q | Lock screen |
| Power button (short press) | Lock screen; when already locked, wake the display |

`touchbar-lock.nix` follows logind's active local session lock state. A small
tiny-dfr patch turns the Touch Bar off while the session is locked and restores
its normal brightness and idle behavior after unlocking. This also applies to
locking through Control+Command+Q or GNOME, without suspending the laptop.
The daemon refreshes the lock state at least every 250 ms, even without input;
its normal dimming and idle timeouts are preserved.

The ACPI `Power Button` is grabbed by the system `power-button-lock` service
before GDM starts. On an unlocked desktop, `KEY_POWER` calls GNOME's
`org.gnome.ScreenSaver.Lock` method on ton's session bus directly. If the screen
shield is already active, it sends Esc through the persistent ydotool virtual
keyboard to wake GNOME and reveal the login UI, preserving authentication.
Setting display power alone left GNOME's fade overlay visible.
Before locking with the power button, a user unit saves the actual internal
panel brightness. The `lock-brightness` user service restores it through
Mutter's `SetBacklight` after unlocking, updating GNOME and the driver together.
It then explicitly reapplies the same value through logind's session
`SetBrightness` method, so an unchanged cached value cannot skip the hardware
write after the panel wakes.
Ambient-light adjustment and idle dimming are disabled declaratively so GNOME
keeps the manually chosen brightness across lock and wake transitions.
GNOME 49 moved brightness hotkeys from Settings Daemon into GNOME Shell, so
GNOME Shell handles the Apple brightness keys and its native OSD. The bundled
`macos-osd` extension applies an approximate gamma 2.2 curve between the
normalized Shell slider and the backlight value, making slider and key changes
more even across the range. It also styles brightness and volume indicators as
translucent dark pills with a white level bar. GNOME Shell keeps ownership of
the backlight, slider, and OSD.
Virtual `KEY_COFFEE` events reached the
session but did not activate GNOME's lock shortcut on this host. The button is
not included in xremap's automatic keyboard selection. logind also locks on power presses if the service is
unavailable. Firmware-enforced emergency power-off on a prolonged hold remains
outside the operating system's control.

The conflicting kernel module `tiny_power_button` is blacklisted both through
modprobe and the kernel command line. On Linux 6.18.57 it can take ownership of
the ACPI power button and send signal 38 (`SIGRTMIN+4`) directly to PID 1,
bypassing GNOME, logind and xremap. This blacklist requires a reboot after
`make switch`; the regular `button` module must remain enabled.

The kernel also includes upstream fix `ab06eb920401` to register platform
devices for fixed-event buttons. Linux 6.18.57 omitted this prerequisite when
converting the button driver to a platform driver, leaving `LNXPWRBN:00`
without an input device. The patched kernel disables `ACPI_TINY_POWER_BUTTON`
and restores fixed-event input through the regular `button` driver. Kernel
changes require rebooting into the newly built generation.

Guake handles Command+C/V natively. xremap recognizes its Nix-wrapped window
class (`.guake-wrapped`); GNOME reserves Command+Left/Right for window tiling,
so xremap translates those keys inside Guake to its previous/next-tab
accelerators. It routes Command+K to Guake's reset accelerator, which clears
the terminal and its scrollback but does not erase Zsh's saved command history.
GNOME's window-drag modifier is Option/Alt, freeing Command+left-click for
Guake. The Guake package accepts Super+left-click for URL matching, and its
quick-open feature is enabled. Other terminals map Command+C/V to
Ctrl+Shift+C/V. Command+T/W uses Ctrl+Shift+T/W, and physical Ctrl+C still
interrupts commands. In other terminals, Command+Left/Right and
Command+Backspace use shell editing shortcuts; Option arrows move by word.
Other application shortcuts depend on the application's Linux defaults. The
mappings do not emulate all macOS application behavior or the Option
special-character layer. The existing Ukrainian Mac punctuation and corrected
letter positions remain in `xkb/ua_mac`.

IntelliJ IDEA uses the custom `macOS — Complete` keymap, based on its `Default
for GNOME` keymap (shown as `GNOME` in the menu) because the macOS preset is not
offered in the Linux keymap list. Its profile restores macOS Command bindings,
and xremap passes Command through to IDEA.
The selected map and shortcut profile are managed from `intellij-idea/` for the
existing IntelliJ IDEA 2026.2 and 2026.3 config directories. Add the new config
path when Toolbox moves to another IDEA config version.

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
