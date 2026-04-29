{ isWSL, inputs, ... }:

{ config, lib, pkgs, ... }:

let
#  sources = import ../../nix/sources.nix;
  isDarwin = pkgs.stdenv.isDarwin;
  isLinux = pkgs.stdenv.isLinux;
  codexPkg = pkgs."ton-unstable".codex;
  codexZshAsset = pkgs.fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v0.122.0/codex-zsh";
    sha256 = "0ijv8s4x7qini9z4n92fz1wz6wvysxml6g6s1r142rap4fgd10pj";
  };
  codexZshCompletion = pkgs.runCommand "codex-zsh-completion" {
    nativeBuildInputs = [ codexPkg ];
  } ''
    mkdir -p "$out/share/zsh/site-functions"
    ${codexPkg}/bin/codex completion zsh > "$out/share/zsh/site-functions/_codex"
  '';

  shellAliases = {
  } // (if isLinux then {
    # Two decades of using a Mac has made this such a strong memory
    # that I'm just going to keep it consistent.
    pbcopy = "xclip";
    pbpaste = "xclip -o";
    nc = "ncat";
  } else {});

  gitIgnores = [
    ".DS_Store"
    ".idea"
    ".codex"
    ".agents"
  ];

  # For our MANPAGER env var
  # https://github.com/sharkdp/bat/issues/1145
  manpager = (pkgs.writeShellScriptBin "manpager" (if isDarwin then ''
    sh -c 'col -bx | bat -l man -p'
    '' else ''
    cat "$1" | col -bx | bat --language man --style plain
  ''));
in {
  # Home-manager 22.11 requires this be set. We never set it so we have
  # to use the old state version.
  home.stateVersion = "25.11";

  # Disabled for now since we mismatch our versions. See flake.nix for details.
  home.enableNixpkgsReleaseCheck = false;

  # We manage our own Nushell config via Chezmoi
#  home.shell.enableNushellIntegration = false;

  xdg.enable = true;

  #---------------------------------------------------------------------
  # Packages
  #---------------------------------------------------------------------

  # Packages I always want installed. Most packages I install using
  # per-project flakes sourced with direnv and nix-shell, so this is
  # not a huge list.
#  home.packages = [
#
#  ] ++ (lib.optionals isDarwin [
#    # This is automatically setup on Linux
#    pk
#  ]) ++ (lib.optionals (isLinux && !isWSL) [
#    pkgs.chromium
#  ]);

  #---------------------------------------------------------------------
  # Env vars and dotfiles
  #---------------------------------------------------------------------

  home.sessionVariables = {
    LANG = "en_US.UTF-8";
    LC_CTYPE = "en_US.UTF-8";
    LC_ALL = "en_US.UTF-8";
#    EDITOR = "nvim";
    PAGER = "less -FirSwX";
    MANPAGER = "${manpager}/bin/manpager";

#    AMP_API_KEY = "op://Private/Amp_API/credential";
#    OPENAI_API_KEY = "op://Private/OpenAPI_Personal/credential";

  	LM_STUDIO_API_KEY = "dummy-api-key";
    LM_STUDIO_API_BASE = "http://localhost:1234/v1";
    PATH=(if isDarwin then "/Users/ton/bin:$PATH" else "/home/ton/bin:$PATH");
  } // (if isDarwin then {
    # See: https://github.com/NixOS/nixpkgs/issues/390751
    DISPLAY = "nixpkgs-390751";
  } else {});

#  home.file = {
#    ".gdbinit".source = ./gdbinit;
#    ".inputrc".source = ./inputrc;
#  };

#  xdg.configFile = {
#    "i3/config".text = builtins.readFile ./i3;
#    "rofi/config.rasi".text = builtins.readFile ./rofi;
#  } // (if isDarwin then {
#    # Rectangle.app. This has to be imported manually using the app.
#    "rectangle/RectangleConfig.json".text = builtins.readFile ./RectangleConfig.json;
#  } else {}) // (if isLinux then {
#    "ghostty/config".text = builtins.readFile ./ghostty.linux;
#  } else {});

  xdg.configFile."codex/codex-zsh".source = codexZshAsset;
  home.file.".gitignore".text = lib.concatStringsSep "\n" (gitIgnores ++ [ "" ]);

  #---------------------------------------------------------------------
  # Programs
  #---------------------------------------------------------------------

  programs.gpg.enable = !isDarwin;

  programs.bash = {
    enable = true;
    shellOptions = [];
    historyControl = [ "ignoredups" "ignorespace" ];
#    initExtra = builtins.readFile ./bashrc;
    shellAliases = shellAliases;
  };
  
  programs.zsh = {
    enable = true;
    dotDir = "${config.xdg.configHome}/zsh";
    initContent = ''
      fpath=(${codexZshCompletion}/share/zsh/site-functions $fpath)
      autoload -Uz compinit
      compinit -i
    '';
    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "docker" "docker-compose"];
      theme = "robbyrussell";
    };
  };

  # Avoid Home Manager options-doc generation path that emits
  # builtins.derivation context warnings on current pins.
  manual.manpages.enable = false;
  
#  programs.chromium.enable = true;

#  programs.direnv= {
#    enable = true;
#
#    config = {
#      whitelist = {
#        prefix= [
#          "$HOME/code/go/src/github.com/hashicorp"
#          "$HOME/code/go/src/github.com/mitchellh"
#        ];
#
#        exact = ["$HOME/.envrc"];
#      };
#    };
#  };

#  programs.fish = {
#    enable = true;
#    shellAliases = shellAliases;
#    interactiveShellInit = lib.strings.concatStrings (lib.strings.intersperse "\n" ([
#      "source ${inputs.theme-bobthefish}/functions/fish_prompt.fish"
#      "source ${inputs.theme-bobthefish}/functions/fish_right_prompt.fish"
#      "source ${inputs.theme-bobthefish}/functions/fish_title.fish"
#      (builtins.readFile ./config.fish)
#      "set -g SHELL ${pkgs.fish}/bin/fish"
#    ]));
#
#    plugins = map (n: {
#      name = n;
#      src  = inputs.${n};
#    }) [
#      "fish-fzf"
#      "fish-foreign-env"
#      "theme-bobthefish"
#    ];
#  };

  programs.git = {
    enable = true;
    ignores = gitIgnores;
    includes = [
      {
        condition = "hasconfig:remote.*.url:git@github.com:**";
        path = "${config.xdg.configHome}/git/config-github";
      }
      {
        condition = "hasconfig:remote.*.url:https://github.com/**";
        path = "${config.xdg.configHome}/git/config-github";
      }
      {
        condition = "hasconfig:remote.*.url:git@orahub.oci.oraclecorp.com:**";
        path = "${config.xdg.configHome}/git/config-orahub";
      }
      {
        condition = "hasconfig:remote.*.url:https://orahub.oci.oraclecorp.com/**";
        path = "${config.xdg.configHome}/git/config-orahub";
      }
    ];
    settings = {
      user.name = "Ton Sharp";
      user.email = "github@66ton99.org.ua";
      branch.autosetuprebase = "always";
      color.ui = true;
      core.askPass = ""; # needs to be empty to use terminal for ask pass
      credential.helper = "store"; # want to make this more secure
      github.user = "66Ton99";
      push.default = "tracking";
      init.defaultBranch = "main";
      pull.rebase = true;
    };
  };

  xdg.configFile."git/config-github".text = ''
    [user]
      name = Ton Sharp
      email = 45160296+66Ton99@users.noreply.github.com
  '';

  xdg.configFile."git/config-orahub".text = ''
    [user]
      name = Anton Shapka
      email = anton.shapka@oracle.com
  '';

#  programs.go = {
#    enable = true;
#    goPath = "code/go";
#    goPrivate = [ "github.com/mitchellh" "github.com/hashicorp" "rfc822.mx" ];
#  };

#  programs.jujutsu = {
#    enable = true;
#
#    # I don't use "settings" because the path is wrong on macOS at
#    # the time of writing this.
#  };

#  programs.alacritty = {
#    enable = !isWSL;
#
#    settings = {
#      env.TERM = "xterm-256color";
#
#      key_bindings = [
#        { key = "K"; mods = "Command"; chars = "ClearHistory"; }
#        { key = "V"; mods = "Command"; action = "Paste"; }
#        { key = "C"; mods = "Command"; action = "Copy"; }
#        { key = "Key0"; mods = "Command"; action = "ResetFontSize"; }
#        { key = "Equals"; mods = "Command"; action = "IncreaseFontSize"; }
#        { key = "Subtract"; mods = "Command"; action = "DecreaseFontSize"; }
#      ];
#    };
#  };

#  programs.kitty = {
#    enable = !isWSL;
#    extraConfig = builtins.readFile ./kitty;
#  };

#  programs.i3status = {
#    enable = isLinux && !isWSL;
#
#    general = {
#      colors = true;
#      color_good = "#8C9440";
#      color_bad = "#A54242";
#      color_degraded = "#DE935F";
#    };
#
#    modules = {
#      ipv6.enable = false;
#      "wireless _first_".enable = false;
#      "battery all".enable = false;
#    };
#  };

#  programs.neovim = {
#    enable = true;
#    package = inputs.neovim-nightly-overlay.packages.${pkgs.system}.default;
#  };

#  programs.atuin = {
#    enable = true;
#  };
#
#  programs.nushell = {
#    enable = true;
#  };

#  programs.oh-my-posh = {
#    enable = true;
#  };

#  services.gpg-agent = {
#    enable = isLinux;
#    pinentry.package = pkgs.pinentry-tty;
#
#    # cache the keys forever so we don't get asked for a password
#    defaultCacheTtl = 31536000;
#    maxCacheTtl = 31536000;
#  };

#  xresources.extraConfig = builtins.readFile ./Xresources;

  # Make cursor not tiny on HiDPI screens
#  home.pointerCursor = lib.mkIf (isLinux && !isWSL) {
#    name = "Vanilla-DMZ";
#    package = pkgs.vanilla-dmz;
#    size = 128;
#    x11.enable = true;
#  };
}
