# PHP 8.4

{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  packages = with pkgs; [
  	(php84.buildEnv {
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
  shellHook = ''
    export DEBUG=1
  '';
}
