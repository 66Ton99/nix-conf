# PHP 8.3
{ pkgs, ... }: {
  environment.systemPackages = [
    (pkgs.php83.buildEnv {
      extensions = ({ enabled, all }: enabled ++ (with all; [
        xdebug
        apcu
        oci8
        xsl
      ]));
      extraConfig = ''
        xdebug.mode=debug
        apc.enable_cli=1
      '';
    })
  ];
}