{ pkgs, inputs, home, ... }:
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
    scrcpy
    wget
    docker
    docker-credential-helpers
    kubernetes-helm
    docker-buildx
    kubectl
    kind
    oci-cli
    git-filter-repo
    git-lfs
    nmap
    openconnect
#    conda
    devenv
    f3
    minicom
    inetutils
  ];
  
  
}
