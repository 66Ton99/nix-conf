# PHP 8.3
{ pkgs, ... }: {
  environment.systemPackages = [
    (pkgs.php83.buildEnv {
      extensions = ({ enabled, all }: enabled ++ (with all; [
        xdebug
        apcu
      ]));
      extraConfig = ''
        xdebug.mode=debug
      '';
    })
  ];
}