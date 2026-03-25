# Legacy PHP 7.1 shell (pure nix-shell, no Docker).
# Note: on current macOS releases, building php71 extensions (xdebug/apcu/xsl) from old nixpkgs
# fails due Darwin toolchain incompatibility (missing /usr/lib/system/libcache.dylib during link).
{ system ? builtins.currentSystem }:

let
  pkgs = import (builtins.fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixos-19.03.tar.gz") {
    inherit system;
    config.permittedInsecurePackages = [ "php-7.1.33" ];
  };
in
pkgs.mkShell {
  buildInputs = [ pkgs.php71 ];

  shellHook = ''
    _php71_ini_dir="$(mktemp -d -t php71-ini.XXXXXX)"
    export PHPRC="$_php71_ini_dir/php.ini"
    mkdir -p "$_php71_ini_dir"

    cat > "$PHPRC" <<'INI'
xdebug.mode=debug
apc.enable_cli=1
memory_limit=-1
INI

    echo "PHP 7.1 shell loaded (pure nix-shell, no Docker)."
    echo "Extensions xdebug/apcu/xsl are not loadable on this macOS with nixpkgs-19.03 toolchain."
  '';
}
