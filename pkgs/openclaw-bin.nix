{
  lib,
  stdenv,
  importNpmLock,
  makeWrapper,
  nodejs_22,
  nodejs-slim_22,
  openclawSrc,
}:

let
  package = builtins.fromJSON (builtins.readFile "${openclawSrc}/package.json");
  packageLock = builtins.fromJSON (builtins.readFile "${openclawSrc}/npm-shrinkwrap.json");

  package' = removeAttrs package [ "devDependencies" ] // {
    dependencies = removeAttrs package.dependencies [ "tar" ];
  };

  packageLock' = packageLock // {
    packages = packageLock.packages // {
      "" = removeAttrs packageLock.packages."" [ "devDependencies" ] // {
        dependencies = removeAttrs packageLock.packages."".dependencies [ "tar" ];
      };

      "node_modules/@google/genai" = packageLock.packages."node_modules/@google/genai" // {
        dependencies = packageLock.packages."node_modules/@google/genai".dependencies // {
          protobufjs = "8.4.0";
        };
      };

      "node_modules/p-retry" = packageLock.packages."node_modules/p-retry" // {
        dependencies = packageLock.packages."node_modules/p-retry".dependencies // {
          "@types/retry" = "0.12.5";
        };
      };
    };
  };

  nodeModules = importNpmLock.buildNodeModules {
    npmRoot = openclawSrc;
    package = package';
    packageLock = packageLock';
    nodejs = nodejs_22;
    derivationArgs = {
      pname = "openclaw-node-modules";
      version = package.version;
      npmFlags = [ "--legacy-peer-deps" ];
      npmRebuildFlags = [ "--ignore-scripts" ];
    };
  };
in
stdenv.mkDerivation {
  pname = "openclaw";
  version = package.version;

  src = openclawSrc;

  dontBuild = true;

  nativeBuildInputs = [
    makeWrapper
  ];

  installPhase = ''
    runHook preInstall

    libdir=$out/lib/openclaw
    mkdir -p "$libdir" "$out/bin"
    cp -R . "$libdir/"
    cp -R ${nodeModules}/node_modules "$libdir/node_modules"

    makeWrapper ${lib.getExe nodejs-slim_22} "$out/bin/openclaw" \
      --add-flags "$libdir/openclaw.mjs" \
      --set NODE_PATH "$libdir/node_modules"

    ln -s "$out/bin/openclaw" "$out/bin/moltbot"
    ln -s "$out/bin/openclaw" "$out/bin/clawdbot"

    runHook postInstall
  '';

  meta = {
    description = "Self-hosted, open-source AI assistant/agent";
    homepage = "https://openclaw.ai";
    license = lib.licenses.mit;
    mainProgram = "openclaw";
    platforms = lib.platforms.darwin;
  };
}
