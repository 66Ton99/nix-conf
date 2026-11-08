{ lib, stdenvNoCC, fetchurl, autoPatchelfHook, versionCheckHook }:
let
  # Official release manifest, including the Intel Mac build missing in nixpkgs:
  # https://storage.googleapis.com/antigravity-public/antigravity-cli/1.5.1/manifest.json
  release = lib.importJSON ./antigravity-cli-sources.json;
  source = release.sources.${stdenvNoCC.hostPlatform.system};
in
stdenvNoCC.mkDerivation {
  pname = "antigravity-cli";
  inherit (release) version;
  src = fetchurl source;
  sourceRoot = ".";
  strictDeps = true;
  nativeBuildInputs = lib.optionals stdenvNoCC.hostPlatform.isElf [ autoPatchelfHook ];
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 antigravity "$out/bin/agy"
    runHook postInstall
  '';

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;
  # Keep Google's macOS code signature intact.
  dontFixup = stdenvNoCC.hostPlatform.isDarwin;
  meta = {
    description = "Google Antigravity terminal coding agent";
    homepage = "https://antigravity.google";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = builtins.attrNames release.sources;
    mainProgram = "agy";
  };
}
