{ lib, pkgs, inputs, ... }:
let
  codexPkg = pkgs.unstable.codex;
  hostSystem = pkgs.stdenv.hostPlatform.system;

  antigravityAppRelease = {
    version = "2.34.0";
    buildId = "5887025308631040";
    sources = {
      x86_64-linux = {
        name = "antigravity-app-x86_64-linux.tar.gz";
        url = "https://storage.googleapis.com/antigravity-public/antigravity-hub/2.34.0-5887025308631040/linux-x64/Antigravity.tar.gz";
        hash = "sha256-R4xo+Gye9hpQIYWjnpzuxmsSdqalOxkaGbDZzoaYNts=";
      };
      aarch64-linux = {
        name = "antigravity-app-aarch64-linux.tar.gz";
        url = "https://storage.googleapis.com/antigravity-public/antigravity-hub/2.34.0-5887025308631040/linux-arm/Antigravity.tar.gz";
        hash = "sha256-kfMc5Qx5XgVx55IlERGf8+evwu5PZAqX1p260gY8GGY=";
      };
      aarch64-darwin = {
        name = "antigravity-app-aarch64-darwin.zip";
        url = "https://storage.googleapis.com/antigravity-public/antigravity-hub/2.34.0-5887025308631040/darwin-arm/Antigravity.zip";
        hash = "sha512-4mY3QkbpWxuru5gPvJrabdr3tMH/mnQDtallcA5m6bZQ6g3AClqU5N6gryt0eml7mrLtm7Vkb+iIQdDRB3wCFw==";
      };
      x86_64-darwin = {
        name = "antigravity-app-intel.zip";
        url = "https://storage.googleapis.com/antigravity-public/antigravity-hub/2.34.0-5887025308631040/darwin-x64/Antigravity.zip";
        hash = "sha512-ovrm7s8YGNURw6n41DrL2K6kIZHvwalVFWaCSVRQy0rjLF5uSTyQigm5w4dEPb4Y7unEcDi+Fbl49j9HYreCkw==";
      };
    };
  };

  overrideAntigravityApp = pkg:
    pkg.overrideAttrs (old: {
      inherit (antigravityAppRelease) version;
      src = pkgs.fetchurl antigravityAppRelease.sources.${hostSystem};
      passthru = (old.passthru or { }) // {
        inherit (antigravityAppRelease) buildId;
      };
      meta = old.meta // {
        platforms = lib.unique ((old.meta.platforms or [ ]) ++ [ hostSystem ]);
      };
    });

  antigravityApp =
    if hostSystem == "x86_64-darwin" then
      # Google publishes an Intel Mac App, but the pinned nixpkgs recipe
      # only lists Apple Silicon. Reuse that recipe with the official build.
      overrideAntigravityApp (pkgs.unstable.callPackage
        (inputs.nixpkgs-unstable + "/pkgs/by-name/an/antigravity-hub/package.nix")
        { })
    else if lib.versionOlder pkgs.unstable.antigravity-hub.version antigravityAppRelease.version then
      overrideAntigravityApp pkgs.unstable.antigravity-hub
    else
      pkgs.unstable.antigravity-hub;

  antigravityCli = pkgs.callPackage ./antigravity-cli.nix { };

  antigravityIdeRelease = {
    version = "2.8.0";
    sources = {
      x86_64-linux = {
        name = "antigravity-ide-x86_64-linux.tar.gz";
        url = "https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/2.8.0-6733682917113856/linux-x64/Antigravity%20IDE.tar.gz";
        hash = "sha256-e6o2uqsoXLRhAa+Vi4975jBUWNuaRNiz0JONYfOFl9c=";
      };
      aarch64-linux = {
        name = "antigravity-ide-aarch64-linux.tar.gz";
        url = "https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/2.8.0-6733682917113856/linux-arm/Antigravity%20IDE.tar.gz";
        hash = "sha256-2Phc5AMGWHqAp0eK9N6FyxC4PPJt2RebkCr6mTP8+fI=";
      };
      aarch64-darwin = {
        name = "antigravity-ide-aarch64-darwin.zip";
        url = "https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/2.8.0-6733682917113856/darwin-arm/Antigravity%20IDE.zip";
        hash = "sha256-VeMT9VBa7vXaIbeeYr91XiNDkevhIwRrWC/zbzfA6rg=";
      };
      x86_64-darwin = {
        name = "antigravity-ide-intel.zip";
        url = "https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/2.8.0-6733682917113856/darwin-x64/Antigravity%20IDE.zip";
        hash = "sha256-B/gpxitpJOcQudrR5pCO28MvMSoTcj0gm1rMTNCnpiA=";
      };
    };
  };

  overrideAntigravityIde = pkg:
    pkg.overrideAttrs (old: {
      inherit (antigravityIdeRelease) version;
      src = pkgs.fetchurl antigravityIdeRelease.sources.${hostSystem};
      meta = old.meta // {
        platforms = lib.unique ((old.meta.platforms or [ ]) ++ [ hostSystem ]);
      };
    });

  antigravityIde =
    if hostSystem == "x86_64-darwin" then
      # The Intel Mac pin predates the antigravity -> antigravity-ide rename.
      # Reuse the current recipe with its supported buildVscode implementation.
      overrideAntigravityIde (pkgs.unstable.callPackage
        (inputs.nixpkgs-unstable + "/pkgs/by-name/an/antigravity-ide/package.nix")
        { })
    else if lib.versionOlder pkgs.unstable.antigravity-ide.version antigravityIdeRelease.version then
      overrideAntigravityIde pkgs.unstable.antigravity-ide
    else
      pkgs.unstable.antigravity-ide;
  antWithJdk = pkgs.writeShellScriptBin "ant" ''
    export JAVA_HOME=${pkgs.jdk}
    export NIX_JVM=${pkgs.jdk}/bin/java
    exec ${pkgs.ant}/bin/ant "$@"
  '';
in
{
  _module.args.codexPkg = codexPkg;

  environment.systemPackages = with pkgs; [
    gcc
    cmake
    ffmpeg
    oci-cli
    google-cloud-sdk
    sonar-scanner-cli
    nodejs
    bun
    antWithJdk
    go
    codexPkg
    unstable.claude-code
    antigravityApp
    antigravityIde
    antigravityCli
    kind
    podman
#    rustc
#    cargo
  ];
}
