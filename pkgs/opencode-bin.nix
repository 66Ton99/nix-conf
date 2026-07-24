{
  lib,
  stdenv,
  fetchzip,
}:

let
  version = "1.17.9";
  sources = {
    aarch64-darwin = {
      url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-darwin-arm64.zip";
      hash = "sha256-eqnTUs1WEgrQaO+dVuF6xYv6VfPd2/XXHufrjiJnhas=";
    };
  };
  source = sources.${stdenv.hostPlatform.system} or (throw "opencode-bin is not packaged for ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "opencode-bin";
  inherit version;

  src = fetchzip {
    inherit (source) url hash;
    stripRoot = false;
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 opencode "$out/bin/opencode"

    runHook postInstall
  '';

  meta = {
    description = "AI coding agent, packaged from upstream prebuilt binary";
    homepage = "https://github.com/anomalyco/opencode";
    license = lib.licenses.mit;
    mainProgram = "opencode";
    platforms = builtins.attrNames sources;
  };
}
