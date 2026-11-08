{ pkgs, inputs, ... }:
let
  codexPkg = pkgs.unstable.codex;
  antigravityApp =
    if pkgs.stdenv.hostPlatform.system == "x86_64-darwin" then
      # Google publishes an Intel Mac App, but the pinned nixpkgs recipe
      # only lists Apple Silicon. Reuse that recipe with the official build.
      (pkgs.unstable.callPackage
        (inputs.nixpkgs-unstable + "/pkgs/by-name/an/antigravity-hub/package.nix")
        { }).overrideAttrs (old: {
          version = "2.29.1";
          src = pkgs.fetchurl {
            name = "antigravity-app-intel.zip";
            url = "https://storage.googleapis.com/antigravity-public/antigravity-hub/2.29.1-5241471524274176/darwin-x64/Antigravity.zip";
            hash = "sha256-XtnAn6/kTootXR4JLH/g4DZIDgGVn5X4jA8ZhUlWHHQ=";
          };
          passthru = old.passthru // { buildId = "5241471524274176"; };
          meta = old.meta // {
            platforms = old.meta.platforms ++ [ "x86_64-darwin" ];
          };
        })
    else
      pkgs.unstable.antigravity-hub;
  antigravityCli = pkgs.callPackage ./antigravity-cli.nix { };
  antigravityIde =
    if pkgs.stdenv.hostPlatform.system == "x86_64-darwin" then
      # The Intel Mac pin predates the antigravity -> antigravity-ide rename.
      # Reuse the current recipe with its supported buildVscode implementation.
      (pkgs.unstable.callPackage
        (inputs.nixpkgs-unstable + "/pkgs/by-name/an/antigravity-ide/package.nix")
        { }).overrideAttrs (old: {
          version = "2.6.0";
          src = pkgs.fetchurl {
            name = "antigravity-ide-intel.zip";
            url = "https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/2.6.0-5526304964083712/darwin-x64/Antigravity%20IDE.zip";
            hash = "sha256-52/Xuh2sXqupZtKW3wS75yp3dp93FKL9fgAWiapkJPc=";
          };
          meta = old.meta // {
            platforms = old.meta.platforms ++ [ "x86_64-darwin" ];
          };
        })
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
#    rustc
#    cargo
  ];
}
