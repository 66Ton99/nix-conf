{ pkgs, ... }:
let
  python = pkgs.python3.withPackages (p: [ p.dbus-python p.pygobject3 ]);
in {
  # Let tiny-dfr remain the sole writer of Touch Bar brightness.
  hardware.apple.touchBar.package = pkgs.tiny-dfr.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace src/backlight.rs \
        --replace-fail 'if self.lid_state == SwitchState::On {' \
        'if self.lid_state == SwitchState::On || Path::new("/run/touchbar-lock/locked").exists() {'
      # The power key is exclusively grabbed by xremap, so it cannot wake
      # tiny-dfr's input loop. Bound lock-state refresh independently of input
      # without changing TIMEOUT_MS, which also defines its idle timeouts.
      substituteInPlace src/main.rs \
        --replace-fail 'let mut next_timeout_ms = min(ms_left, TIMEOUT_MS);' \
        'let mut next_timeout_ms = min(ms_left, 250);'
    '';
  });

  systemd.services.touchbar-lock = {
    description = "Synchronize Touch Bar with the graphical session lock";
    wantedBy = [ "multi-user.target" ];
    requires = [ "systemd-logind.service" ];
    after = [ "systemd-logind.service" ];
    before = [ "tiny-dfr.service" ];
    serviceConfig = {
      ExecStart = "${python}/bin/python3 ${./touchbar-lock.py}";
      RuntimeDirectory = "touchbar-lock";
      Restart = "on-failure";
      RestartSec = 2;
      ProtectSystem = "strict";
      ProtectHome = true;
      NoNewPrivileges = true;
    };
  };
}
