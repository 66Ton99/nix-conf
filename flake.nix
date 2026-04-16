{
  description = "NixOS systems and tools by 66Ton99";

  inputs = {
    # Pin our primary nixpkgs repository. This is the main nixpkgs repository
    # we'll use for our configurations. Be very careful changing this because
    # it'll impact your entire system.
    nixpkgs.url = "github:66Ton99/nixpkgs";

    # We use the unstable nixpkgs repo for some packages.
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    # My unstable fork for packages I want ahead of the main pin.
    ton-unstable.url = "github:66Ton99/nixpkgs/nixos-unstable";

    # Master nixpkgs is used for really bleeding edge packages. Warning
    # that this is extremely unstable and shouldn't be relied on. Its
    # mostly for testing.
    nixpkgs-master.url = "github:nixos/nixpkgs";
    ton.url = "github:66Ton99/nixpkgs";

    # Build a custom WSL installer
    nixos-wsl.url = "github:nix-community/NixOS-WSL";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";

    # snapd
    nix-snapd.url = "github:nix-community/nix-snapd";
    nix-snapd.inputs.nixpkgs.follows = "nixpkgs";

    home-manager = {
      # We need to use nightly home-manager because it contains this
      # fix we need for nushell nightly:
      # https://github.com/nix-community/home-manager/commit/a69ebd97025969679de9f930958accbe39b4c705
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # I think technically you're not supposed to override the nixpkgs
    # used by neovim but recently I had failures if I didn't pin to my
    # own. We can always try to remove that anytime.
#    neovim-nightly-overlay = {
#      url = "github:nix-community/neovim-nightly-overlay";
#    };

    # Other packages
#    jujutsu.url = "github:martinvonz/jj";
#    zig.url = "github:ton/zig-overlay";

    # Non-flakes
#    theme-bobthefish.url = "github:oh-my-fish/theme-bobthefish/e3b4d4eafc23516e35f162686f08a42edf844e40";
#    theme-bobthefish.flake = false;
#    fish-fzf.url = "github:jethrokuan/fzf/24f4739fc1dffafcc0da3ccfbbd14d9c7d31827a";
#    fish-fzf.flake = false;
#    fish-foreign-env.url = "github:oh-my-fish/plugin-foreign-env/dddd9213272a0ab848d474d0cbde12ad034e65bc";
#    fish-foreign-env.flake = false;
  };

  outputs = { self, nixpkgs, home-manager, darwin, ... }@inputs: let
    # Overlays is the list of overlays we want to apply from flake inputs.
    overlays = [
#      inputs.jujutsu.overlays.default
#      inputs.zig.overlays.default
      (final: prev: let
        hostSystem = prev.stdenv.hostPlatform.system;

        tonUnstableBase = import inputs.ton-unstable {
          system = hostSystem;
          config.allowUnfree = true;
        };
      in rec {
        # Want the latest version of these
        claude-code = inputs.nixpkgs-unstable.legacyPackages.${hostSystem}.claude-code;
        nushell = inputs.nixpkgs-unstable.legacyPackages.${hostSystem}.nushell;

        unstable = import inputs.nixpkgs-unstable {
          system = hostSystem;
          # To use Chrome, we need to allow the
          # installation of non-free software.
          config.allowUnfree = true;
        };

        ton = import inputs.ton {
          system = hostSystem;
          config.allowUnfree = true;
        };

        # codex 0.121.0 downloads a prebuilt WebRTC archive during build via
        # reqwest/rustls. On Darwin inside the Nix sandbox it needs an explicit
        # CA bundle to trust GitHub Releases.
        ton-unstable = prev.lib.recursiveUpdate tonUnstableBase {
          codex = tonUnstableBase.codex.overrideAttrs (old: {
            nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.cacert ];
            env = (old.env or { }) // {
              SSL_CERT_FILE = "${prev.cacert}/etc/ssl/certs/ca-bundle.crt";
              NIX_SSL_CERT_FILE = "${prev.cacert}/etc/ssl/certs/ca-bundle.crt";
            };
          });
        };
      })
    ];

  mkSystem = import ./lib/mksystem.nix {
    inherit overlays nixpkgs inputs;
  };

  in {
#    nixosConfigurations.vm-aarch64 = mkSystem "vm-aarch64" {
#      system = "aarch64-linux";
#      user   = "ton";
#    };
#
#    nixosConfigurations.vm-intel = mkSystem "vm-intel" rec {
#      system = "x86_64-linux";
#      user   = "ton";
#    };

    nixosConfigurations.wsl = mkSystem "wsl" {
      system = "x86_64-linux";
      user   = "ton";
      wsl    = true;
    };

    darwinConfigurations.mac-i9 = mkSystem "mac-i9" {
      system = "x86_64-darwin";
      user   = "ton";
      darwin = true;
    };

    darwinConfigurations.mac-m4 = mkSystem "mac-m4" {
      system = "aarch64-darwin";
      user   = "ton";
      darwin = true;
    };
  };
}
