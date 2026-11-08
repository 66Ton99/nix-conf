{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  wrapGAppsHook3,
  makeWrapper,
  asar,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  gdk-pixbuf,
  glib,
  glibc,
  gtk3,
  libgbm,
  libGL,
  libnotify,
  libayatana-appindicator,
  libpulseaudio,
  libsecret,
  libusb1,
  libxkbcommon,
  nspr,
  nss,
  openssl,
  pango,
  pipewire,
  systemd,
  tpm2-tss,
  vulkan-loader,
  wayland,
  xdg-utils,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxrandr,
  libxtst,
}:
let
  # Follow the native .deb packaging approach in:
  # https://git.thomasave.be/thomasave/nix-codex
  runtimeLibraries = [
    libGL libnotify libayatana-appindicator libpulseaudio libsecret
    pipewire systemd vulkan-loader wayland libxtst
  ];
in
stdenv.mkDerivation rec {
  pname = "codex-desktop";
  version = "26.1103.60933";

  # The official Linux desktop app now ships as ChatGPT, including Codex.
  src = fetchurl {
    url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/pool/main/c/chatgpt/chatgpt_${version}_amd64.deb";
    hash = "sha256-B0bpuldRgvXb4yYXuCpkXrk61XyliOWpNYaVprZa7nE=";
  };

  nativeBuildInputs = [ dpkg autoPatchelfHook wrapGAppsHook3 makeWrapper asar ];
  buildInputs = [
    alsa-lib at-spi2-atk at-spi2-core atk cairo cups dbus expat
    gdk-pixbuf glib gtk3 libgbm libGL libnotify libsecret libusb1
    libxkbcommon nspr nss openssl pango stdenv.cc.cc.lib systemd tpm2-tss
    vulkan-loader libx11 libxcb libxcomposite libxdamage
    libxext libxfixes libxrandr
  ];
  runtimeDependencies = map lib.getLib runtimeLibraries;
  # Chromium's optional Qt file-dialog shims are unused with the GTK backend.
  autoPatchelfIgnoreMissingDeps = [
    "libQt5Core.so.5" "libQt5Gui.so.5" "libQt5Widgets.so.5"
    "libQt6Core.so.6" "libQt6Gui.so.6" "libQt6Widgets.so.6"
  ];

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x "$src" .
    runHook postUnpack
  '';
  dontBuild = true;
  dontStrip = true;
  dontWrapGApps = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib" "$out/bin"
    cp -a usr/lib/chatgpt "$out/lib/chatgpt"
    cp -a usr/share "$out/share"

    # detect-libc otherwise falls back to process.report in Electron workers,
    # which can crash on NixOS after the ELF interpreter has been patched.
    asar extract "$out/lib/chatgpt/resources/app.asar" asar-content
    substituteInPlace asar-content/node_modules/@parcel/watcher/node_modules/detect-libc/lib/filesystem.js \
      --replace-fail "'/usr/bin/ldd'" "'${lib.getBin glibc}/bin/ldd'"
    asar pack asar-content "$out/lib/chatgpt/resources/app.asar" --unpack '**/*.node'
    substituteInPlace "$out/lib/chatgpt/resources/cua_node/lib/node_modules/detect-libc/lib/filesystem.js" \
      --replace-fail "'/usr/bin/ldd'" "'${lib.getBin glibc}/bin/ldd'"

    # Upstream includes native Node modules for other platforms and musl.
    find "$out/lib/chatgpt/resources/app.asar.unpacked" -type d \
      \( -name 'android-*' -o -name 'linux-arm*' -o -name '*-linux-arm*' \
      -o -name '*musl*' \) -prune -exec rm -rf {} +
    find "$out/lib/chatgpt/resources/app.asar.unpacked" -name '*.musl.node' -delete
    runHook postInstall
  '';

  postFixup = ''
    makeWrapper "$out/lib/chatgpt/ChatGPT" "$out/bin/chatgpt" \
      "''${gappsWrapperArgs[@]}" \
      --prefix PATH : ${lib.makeBinPath [ xdg-utils ]} \
      --set NIX_LD ${stdenv.cc.bintools.dynamicLinker} \
      --set NIX_LD_LIBRARY_PATH ${lib.makeLibraryPath (buildInputs ++ runtimeLibraries)} \
      --add-flags --password-store=gnome-libsecret
    ln -s chatgpt "$out/bin/codex-desktop"
  '';

  meta = {
    description = "Official OpenAI desktop app with Codex";
    homepage = "https://learn.chatgpt.com/docs/linux/linux-app";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "chatgpt";
  };
}
