# PHP 8.4
{ pkgs, ... }: {
  environment.systemPackages = [
    (pkgs.php84.buildEnv {
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