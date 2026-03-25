# PHP 7.1 shell with required extensions on modern macOS.
# Uses Docker because native nixpkgs-19.03 PHP extension builds fail on current Darwin toolchains.
{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  packages = with pkgs; [
    docker-client
  ];

  shellHook = ''
    export PHP71_IMAGE="local/php71-ext:latest"

    if ! command -v docker >/dev/null 2>&1; then
      echo "docker is required for this shell" >&2
      return
    fi

    if ! docker image inspect "$PHP71_IMAGE" >/dev/null 2>&1; then
      tmpdir="$(mktemp -d -t php71-image.XXXXXX)"
      cat > "$tmpdir/Dockerfile" <<'DOCKERFILE'
FROM webdevops/php:7.1
RUN set -eux; \
    pecl install xdebug-2.9.8; \
    extdir="$(php-config --extension-dir)"; \
    echo "zend_extension=''${extdir}/xdebug.so" > /usr/local/etc/php/conf.d/zz-xdebug.ini
DOCKERFILE
      docker build -t "$PHP71_IMAGE" "$tmpdir"
      rm -rf "$tmpdir"
    fi

    mkdir -p .nix-php71/bin
    cat > .nix-php71/bin/php <<'SH'
#!/usr/bin/env bash
set -euo pipefail

tty_args=()
if [ -t 0 ] && [ -t 1 ]; then
  tty_args+=("-t")
fi

exec docker run --rm -i "''${tty_args[@]}" \
  -u "$(id -u):$(id -g)" \
  -v "$PWD:/work" \
  -w /work \
  "$PHP71_IMAGE" php \
  -d xdebug.mode=debug \
  -d apc.enable_cli=1 \
  -d memory_limit=-1 \
  "$@"
SH
    chmod +x .nix-php71/bin/php
    export PATH="$PWD/.nix-php71/bin:$PATH"

    echo "PHP 7.1 ready (Docker image: $PHP71_IMAGE)"
  '';
}
