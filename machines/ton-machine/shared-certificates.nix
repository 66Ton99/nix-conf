{ config, lib, pkgs, ... }:
let
  oracle = "/mnt/oracle";
  sharedBundle = "/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem";
  # Only the updater needs different source paths. Applications retain the
  # standard NixOS p11-kit and read the shared extracted trust policy.
  sourceTrust = pkgs.p11-kit.overrideAttrs (old: {
    mesonFlags = builtins.filter
      (flag: !(lib.hasPrefix "-Dtrust_paths=" flag)) old.mesonFlags
      ++ [ "-Dtrust_paths=/etc/pki/ca-trust/source:${oracle}/usr/share/pki/ca-trust-source" ];
    doCheck = false;
  });
  updateScript = pkgs.writeText "update-ca-trust-shared.sh"
    (builtins.replaceStrings
      [ "/usr/bin/trust" "/usr/bin/mkdir" ]
      [ "${lib.getBin sourceTrust}/bin/trust" "${pkgs.coreutils}/bin/mkdir" ]
      (builtins.readFile ./shared-certificates/update-ca-trust.sh));
  updateTrust = pkgs.writeShellScriptBin "update-ca-trust" ''
    export PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.findutils pkgs.util-linux ]}
    if [ "$(id -u)" != 0 ]; then
      echo "Run update-ca-trust with sudo." >&2
      exit 1
    fi
    mountpoint -q ${oracle}
    test -d ${oracle}/usr/share/pki/ca-trust-source
    exec ${pkgs.bash}/bin/bash ${updateScript} "$@"
  '';
in {
  nixpkgs.config.allowUnfreePredicate = pkg:
    lib.getName pkg == "google-chrome";
  environment.systemPackages = [ pkgs.google-chrome pkgs.nss.tools updateTrust ];

  # Runtime links keep all trust material and private keys outside /nix/store.
  environment.etc = {
    "pki/ca-trust".source = "${oracle}/etc/pki/ca-trust";
    "pki/tls/certs".source = "${oracle}/etc/pki/tls/certs";
    "pki/tls/private".source = "${oracle}/etc/pki/tls/private";
    "pki/java".source = "${oracle}/etc/pki/java";
    "ssl/certs".source = "/etc/pki/tls/certs";
    "ssl/cert.pem".source = sharedBundle;
    "ssl/trust-source".source = lib.mkForce
      "/etc/pki/ca-trust/extracted/openssl/ca-bundle.trust.crt";
    # These files are supplied by the shared parent directory instead.
    "ssl/certs/ca-certificates.crt".enable = lib.mkForce false;
    "ssl/certs/ca-bundle.crt".enable = lib.mkForce false;
    "pki/tls/certs/ca-bundle.crt".enable = lib.mkForce false;
  };
  environment.variables = {
    SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
    SSL_CERT_DIR = "/etc/ssl/certs";
    NIX_SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
    CURL_CA_BUNDLE = "/etc/ssl/certs/ca-certificates.crt";
    JAVAX_NET_SSL_TRUSTSTORE = "/etc/pki/java/cacerts";
  };
  nix.settings.ssl-cert-file = "/etc/ssl/certs/ca-certificates.crt";
  systemd.services.nix-daemon.environment = {
    CURL_CA_BUNDLE = lib.mkForce "/etc/ssl/certs/ca-certificates.crt";
    SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
    NIX_SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
  };

  # Older Chrome uses ~/.pki/nssdb, already on the shared home. Keep its
  # newer XDG fallback shared as well, without replacing either existing DB.
  systemd.tmpfiles.rules = [
    "L /home/ton/.local/share/nixos/pki - ton ton - /home/ton/.local/share/pki"
  ];
  systemd.services.shared-certificates-ready = {
    description = "Ensure the shared Oracle certificate stores are available";
    wantedBy = [ "sysinit.target" ];
    after = [ "local-fs.target" ];
    before = [ "sysinit.target" "network-pre.target" ];
    unitConfig = {
      DefaultDependencies = false;
      RequiresMountsFor = "${oracle}/etc/pki/ca-trust";
    };
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.coreutils}/bin/test -s ${sharedBundle}";
    };
  };
  systemd.services.nix-daemon.requires = [ "shared-certificates-ready.service" ];
  systemd.services.nix-daemon.after = [ "shared-certificates-ready.service" ];
  systemd.services.vpnagentd.requires = [ "shared-certificates-ready.service" ];
  systemd.services.vpnagentd.after = [ "shared-certificates-ready.service" ];
  systemd.services.mydesktop.requires = [ "shared-certificates-ready.service" ];
  systemd.services.mydesktop.after = [ "shared-certificates-ready.service" ];
  systemd.services.display-manager.requires = [ "shared-certificates-ready.service" ];
  systemd.services.display-manager.after = [ "shared-certificates-ready.service" ];
}
