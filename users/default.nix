{ pkgs, currentSystemName ? null, ... }:
let
  # This host exposes Podman through the Docker-compatible CLI. Keep the
  # Docker CLI and its buildx plugin on other hosts only.
  dockerCliPackages = pkgs.lib.optionals (currentSystemName != "ton-machine") [
    pkgs.unstable.docker
    pkgs.unstable.docker-buildx
  ];
in
{
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    liberation_ttf
    fira-code
    fira-code-symbols
    mplus-outline-fonts.githubRelease
    dina-font
    proggyfonts
  ];

  environment.systemPackages = with pkgs; [
    direnv
    gnumake
    gitFull
    git-filter-repo
    git-lfs
    gh
    glab
    go-passbolt-cli
    scrcpy
    wget
    ripgrep
    docker-credential-helpers
    ton.nerdctl
    kubernetes-helm
    kubectl
    kind
    oci-cli
    flarectl
    nmap
    openconnect
    xmlstarlet
#    conda
    devenv
    f3
    minicom
    inetutils
    ack
    gedit
    screen
    bind
  ] ++ dockerCliPackages;
  
  
}
