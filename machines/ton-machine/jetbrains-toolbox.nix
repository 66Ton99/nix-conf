{ lib, pkgs, ... }:
let
  runtimeLibraries = with pkgs; [
    glibc
    stdenv.cc.cc.lib
    zlib
    alsa-lib
    atk
    cairo
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    libglvnd
    libx11
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxinerama
    libxkbcommon
    libxrandr
    libxrender
    libxtst
    pango
  ];
  vendorLibraryDirectories = [
    "/home/ton/bin/ToolBox/jre/lib"
    "/home/ton/bin/ToolBox/jre/lib/server"
    "/home/ton/.local/share/JetBrains/Toolbox/apps/intellij-idea/jbr/lib"
    "/home/ton/.local/share/JetBrains/Toolbox/apps/intellij-idea/jbr/lib/server"
  ];
  runtimeLibraryPath = lib.concatStringsSep ":"
    (vendorLibraryDirectories ++ [ (lib.makeLibraryPath runtimeLibraries) ]);
  makeLauncher = name: executable: pkgs.writeShellScriptBin name ''
    unset LD_LIBRARY_PATH LD_PRELOAD
    export NIX_LD=${lib.escapeShellArg (toString pkgs.stdenv.cc.bintools.dynamicLinker)}
    export NIX_LD_LIBRARY_PATH=${lib.escapeShellArg runtimeLibraryPath}
    export FONTCONFIG_FILE=/etc/fonts/fonts.conf
    export FONTCONFIG_PATH=/etc/fonts
    exec ${lib.escapeShellArg executable} "$@"
  '';
  jetbrainsToolbox = makeLauncher
    "jetbrains-toolbox"
    "/home/ton/bin/ToolBox/jetbrains-toolbox";
  intellijIdea = makeLauncher
    "intellij-idea"
    "/home/ton/.local/share/JetBrains/Toolbox/apps/intellij-idea/bin/idea";
  desktopIcons = pkgs.runCommand "jetbrains-desktop-icons" { } ''
    install -Dm644 ${./icons/jetbrains-toolbox.svg} \
      "$out/share/icons/hicolor/scalable/apps/jetbrains-toolbox.svg"
    install -Dm644 ${./icons/intellij-idea.svg} \
      "$out/share/icons/hicolor/scalable/apps/intellij-idea.svg"
  '';
  toolboxDesktopEntry = pkgs.makeDesktopItem {
    name = "jetbrains-toolbox";
    desktopName = "JetBrains Toolbox";
    comment = "Manage JetBrains IDEs";
    exec = "${jetbrainsToolbox}/bin/jetbrains-toolbox %u";
    icon = "jetbrains-toolbox";
    categories = [ "Development" ];
    terminal = false;
  };
  intellijDesktopEntry = pkgs.makeDesktopItem {
    name = "intellij-idea";
    desktopName = "IntelliJ IDEA 2026.3";
    comment = "The IDE for Java and Kotlin development";
    exec = "${intellijIdea}/bin/intellij-idea %u";
    icon = "intellij-idea";
    categories = [ "Development" "IDE" ];
    terminal = false;
  };
in
{
  environment.systemPackages = [
    desktopIcons
    intellijDesktopEntry
    intellijIdea
    jetbrainsToolbox
    toolboxDesktopEntry
  ];
}
