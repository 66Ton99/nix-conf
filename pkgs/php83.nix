# PHP 8.3
{ pkgs, ... }:
let
  php83Fast = pkgs.php83.buildEnv {
    extensions = ({ enabled, all }: enabled ++ (with all; [
      xdebug
      apcu
      xsl
    ]));
    extraConfig = ''
      xdebug.mode=debug
      apc.enable_cli=1
      memory_limit=-1
    '';
  };

  php83Oci = pkgs.php83.buildEnv {
    extensions = ({ enabled, all }: enabled ++ (with all; [
      xdebug
      apcu
      oci8
      xsl
    ]));
    extraConfig = ''
      xdebug.mode=debug
      apc.enable_cli=1
      memory_limit=-1
    '';
  };
in {
  environment.systemPackages = [
    php83Fast
    (pkgs.writeShellScriptBin "php-oci" ''
      exec ${php83Oci}/bin/php "$@"
    '')
  ];
}
