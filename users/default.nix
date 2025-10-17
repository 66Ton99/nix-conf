{ pkgs, inputs, home, ... }:
{
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-emoji
    liberation_ttf
    fira-code
    fira-code-symbols
    mplus-outline-fonts.githubRelease
    dina-font
    proggyfonts
  ];

  environment.systemPackages = with pkgs; [
    docker
    docker-credential-helpers
    kubernetes-helm
    docker-buildx
    kubectl
    oci-cli
    git-filter-repo
    git-lfs
    nmap
    openconnect
    xdg-utils
    automake
    autoconf
    pkg-config
    pcsclite
    om4
    libtool
    nls
    gettext
    gnutls
  ];
  
}
