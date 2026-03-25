# Legacy PHP 7.3
{ system ? builtins.currentSystem }:

let
  pkgs = import (builtins.fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixos-21.05.tar.gz") {
    inherit system;
    config.permittedInsecurePackages = [ "php-7.3.32" ];
  };
in
pkgs.mkShell {
  buildInputs = [
    pkgs.php73
    pkgs.php73Packages.composer
  ];

  shellHook = ''
    _php73_ini_dir="$(mktemp -d -t php73-ini.XXXXXX)"
    export PHPRC="$_php73_ini_dir/php.ini"
    mkdir -p "$_php73_ini_dir"

    cat > "$PHPRC" <<'INI'
xdebug.mode=debug
apc.enable_cli=1
memory_limit=-1
INI
  '';
}
