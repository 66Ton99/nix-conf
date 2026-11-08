{ lib, ... }:
{
  # The same mutable application files are used by both Linux installations.
  # This is a normal boot mount, with the Oracle root mounted first.
  systemd.mounts = [ {
    description = "Shared Oracle Linux application directory";
    what = "/mnt/oracle/opt";
    where = "/opt";
    type = "none";
    options = "bind,rw,nosuid,nodev";
    wantedBy = [ "local-fs.target" ];
    before = [ "local-fs.target" ];
    unitConfig.RequiresMountsFor = "/mnt/oracle/opt";
  } ];

  # Requiring a mount here does not enable a service. Falcon stays manual.
  systemd.services = lib.genAttrs
    [ "falcon-sensor" "mydesktop" "vpnagentd" ]
    (_: {
      requires = [ "opt.mount" ];
      after = [ "opt.mount" ];
    });
}
