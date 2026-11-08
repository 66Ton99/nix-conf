{ config, lib, pkgs, utils, ... }:
let
  # Vendor binaries and private agent state stay outside the public Nix store.
  coreLibraries = with pkgs; [
    glibc stdenv.cc.cc.lib zlib openssl libcap elfutils libxcrypt systemd
  ];
  ciscoLibraries = coreLibraries ++ (with pkgs; [
    gtk3 glib atk pango cairo gdk-pixbuf libxml2_13
    libx11 libxext libxtst libxrender
  ]);
  makeRuntime = libraries: vendorDirectories: {
    NIX_LD = pkgs.stdenv.cc.bintools.dynamicLinker;
    NIX_LD_LIBRARY_PATH = lib.concatStringsSep ":"
      (vendorDirectories ++ [ (lib.makeLibraryPath libraries) ]);
    SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
    SSL_CERT_DIR = "/etc/ssl/certs";
  };
  mydesktopEnvironment = makeRuntime coreLibraries [ ];
  ciscoEnvironment = makeRuntime ciscoLibraries [ "/opt/cisco/secureclient/lib" ];
  falconEnvironment = makeRuntime coreLibraries [ "/opt/CrowdStrike" ];
  nativeTools = with pkgs; [
    bash coreutils findutils gnugrep gnused gawk procps iproute2
    util-linux pciutils usbutils dmidecode curl wget systemd kmod xdg-utils
    nettools iptables bind
  ];
  sharedCisco = "/home/.shared-system/cisco";
  ciscoMounts = [
    { name = "vpn"; where = "/opt/cisco/secureclient/vpn"; }
    { name = "local-policy.xml"; where = "/opt/cisco/secureclient/AnyConnectLocalPolicy.xml"; }
    { name = "certificates"; where = "/opt/.cisco/certificates"; }
  ];
  ciscoMountUnits = map (mount: "${utils.escapeSystemdPath mount.where}.mount") ciscoMounts;
  vendorCommand = name: executable: runtime: pkgs.writeShellScriptBin name ''
    if ! ${pkgs.util-linux}/bin/mountpoint -q /opt; then
      echo "Shared /opt is not mounted; start opt.mount first." >&2
      exit 69
    fi
    unset LD_LIBRARY_PATH LD_PRELOAD
    export PATH=${lib.escapeShellArg (lib.makeBinPath nativeTools + ":/run/wrappers/bin:/run/current-system/sw/bin")}
    export NIX_LD=${lib.escapeShellArg (toString runtime.NIX_LD)}
    export NIX_LD_LIBRARY_PATH=${lib.escapeShellArg runtime.NIX_LD_LIBRARY_PATH}
    export SSL_CERT_FILE=${lib.escapeShellArg runtime.SSL_CERT_FILE}
    export SSL_CERT_DIR=${lib.escapeShellArg runtime.SSL_CERT_DIR}
    exec ${lib.escapeShellArg executable} "$@"
  '';
  ciscoGui = vendorCommand "cisco-secure-client" "/opt/cisco/secureclient/bin/vpnui" ciscoEnvironment;
  ciscoCli = vendorCommand "cisco-vpn" "/opt/cisco/secureclient/bin/vpn" ciscoEnvironment;
  ciscoAgent = vendorCommand "cisco-vpn-agent" "/opt/cisco/secureclient/bin/vpnagentd" ciscoEnvironment;
  falconCtl = vendorCommand "falconctl" "/opt/CrowdStrike/falconctl" falconEnvironment;
  falconDaemon = vendorCommand "falcon-daemon" "/opt/CrowdStrike/falcond" falconEnvironment;
  mydesktopService = vendorCommand "mydesktop-service" "/opt/oracle/mydesktop/mydesktopservice" mydesktopEnvironment;

in
{
  programs.nix-ld = {
    enable = true;
    # Each wrapper/service supplies its own library closure.
    libraries = lib.mkForce [ ];
  };
  boot.kernelModules = [ "tun" ];
  # These two absolute paths occur in the vendor VPN binaries.
  systemd.tmpfiles.rules = [
    "L+ /bin/bash - - - - ${pkgs.bash}/bin/bash"
    "L+ /bin/systemctl - - - - ${pkgs.systemd}/bin/systemctl"
  ];

  environment.systemPackages = [
    ciscoGui ciscoCli falconCtl mydesktopService
    pkgs.xdg-utils
    (pkgs.makeDesktopItem {
      name = "cisco-secure-client";
      desktopName = "Cisco Secure Client";
      comment = "Connect using Cisco Secure Client VPN";
      exec = "cisco-secure-client";
      icon = "network-vpn";
      categories = [ "Network" ];
      terminal = false;
    })
  ];

  # No WantedBy/RequiredBy, activation socket, timer or restart: explicit start only.
  systemd.services.falcon-sensor = {
    description = "CrowdStrike Falcon Sensor (manual start)";
    wantedBy = lib.mkForce [ ];
    requiredBy = lib.mkForce [ ];
    restartIfChanged = false;
    after = [ "local-fs.target" ];
    before = [ "shutdown.target" ];
    conflicts = [ "shutdown.target" ];
    unitConfig = {
      DefaultDependencies = false;
      RequiresMountsFor = [ "/opt" "/var" ];
      ConditionFileIsExecutable = "/opt/CrowdStrike/falcond";
    };
    environment = falconEnvironment;
    path = nativeTools;
    serviceConfig = {
      Type = "forking";
      ExecStartPre = "${falconCtl}/bin/falconctl -g --cid";
      ExecStart = "${falconDaemon}/bin/falcon-daemon";
      PIDFile = "/run/falcond.pid";
      Restart = "no";
      TimeoutStopSec = "60s";
      KillMode = "control-group";
      KillSignal = "SIGTERM";
      Delegate = true;
    };
  };

  systemd.services.mydesktop = {
    description = "Oracle MyDesktop";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    unitConfig.ConditionFileIsExecutable = "/opt/oracle/mydesktop/mydesktopservice";
    environment = mydesktopEnvironment;
    path = nativeTools;
    serviceConfig = {
      ExecStart = "${mydesktopService}/bin/mydesktop-service --nofork";
      KillMode = "process";
      Restart = "always";
      RestartSec = "120s";
    };
  };

  # These are real bind mounts of one shared copy, not periodically synced files.
  systemd.mounts = map (mount: {
    description = "Shared Cisco Secure Client ${mount.name}";
    what = "${sharedCisco}/${mount.name}";
    inherit (mount) where;
    type = "none";
    options = "bind";
    wantedBy = [ "local-fs.target" ];
    before = [ "local-fs.target" "vpnagentd.service" ];
    unitConfig.RequiresMountsFor = "${sharedCisco}/${mount.name}";
  }) ciscoMounts;

  systemd.services.vpnagentd = {
    description = "Cisco Secure Client VPN Agent";
    wantedBy = [ "multi-user.target" ];
    requires = ciscoMountUnits;
    after = [ "network.target" ] ++ ciscoMountUnits;
    environment = ciscoEnvironment;
    path = nativeTools;
    unitConfig.ConditionFileIsExecutable = "/opt/cisco/secureclient/bin/vpnagentd";
    serviceConfig = {
      Type = "simple";
      ExecStartPre = "${pkgs.kmod}/bin/modprobe tun";
      ExecStart = "${ciscoAgent}/bin/cisco-vpn-agent -execv_instance";
      ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
      PIDFile = "/run/vpnagentd.pid";
      KillMode = "process";
      Restart = "on-failure";
    };
  };
}
