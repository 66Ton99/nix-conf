{ lib, pkgs, ... }:
let
  podman = "${pkgs.podman}/bin/podman";
  socket = "/run/user/1000/ofs-nixos-podman.sock";
  node = "ofs-control-plane";
  nodeScript = ''
    set -eu

    config=/etc/containerd/config.toml
    marker=/etc/containerd/.fuse-overlayfs-activated
    restart_containerd=0

    if grep -Eq '^[[:space:]]*snapshotter = "fuse-overlayfs"$' "$config"; then
      :
    elif grep -Eq '^[[:space:]]*snapshotter = "overlayfs"$' "$config"; then
      sed -i 's/^[[:space:]]*snapshotter = "overlayfs"$/  snapshotter = "fuse-overlayfs"/' "$config"
      restart_containerd=1
    else
      echo "Unexpected containerd snapshotter configuration in $config" >&2
      exit 1
    fi

    if ! systemctl is-active --quiet containerd-fuse-overlayfs.service || ! systemctl is-active --quiet containerd.service || [ ! -f "$marker" ]; then
      restart_containerd=1
    fi

    if [ "$restart_containerd" -eq 1 ]; then
      systemctl stop containerd.service
      systemctl start containerd-fuse-overlayfs.service
      systemctl start containerd.service
    fi

    touch "$marker"
  '';
  repair = ''
    podman="${podman}"
    socket=${lib.escapeShellArg socket}
    node=${lib.escapeShellArg node}

    if [ -S "$socket" ] && "$podman" --remote --url "unix://$socket" container exists "$node"; then
      running="$($podman --remote --url "unix://$socket" inspect --format '{{.State.Running}}' "$node")"
      if [ "$running" = true ]; then
        "$podman" --remote --url "unix://$socket" exec "$node" /bin/sh -euc ${lib.escapeShellArg nodeScript}
      fi
    fi
  '';
in
{
  # Reconcile the existing Kind node without recreating it or touching its etcd volume.
  system.activationScripts.kind-ofs-fuse-overlayfs = lib.stringAfter [ "users" ] repair;

  # Reapply after a rootless Podman node restart, which clears its /run state.
  systemd.user.services.kind-ofs-fuse-overlayfs = {
    description = "Reconcile fuse-overlayfs in the existing OFS Kind node";
    after = [ "ofs-nixos-api.service" ];
    path = [ pkgs.coreutils pkgs.gnugrep pkgs.gnused pkgs.podman ];
    serviceConfig.Type = "oneshot";
    script = repair;
  };

  systemd.user.timers.kind-ofs-fuse-overlayfs = {
    description = "Check OFS Kind runtime after container restarts";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnStartupSec = "15s";
      OnUnitActiveSec = "1min";
      Unit = "kind-ofs-fuse-overlayfs.service";
    };
  };
}
