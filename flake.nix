{
  description = "Gregory's Doom Emacs via Nix – bundled Nerd Fonts (JetBrainsMono)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    doom-emacs = {
      url = "github:marienz/nix-doom-emacs-unstraightened";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    doom-config = {
      url = "path:./doom.d";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, doom-emacs, doom-config, ... }:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
        overlays = [ doom-emacs.overlays.default ];
      };

      # Base Doom Emacs with your config
      myDoomEmacs = pkgs.emacsWithDoom {
        doomDir = doom-config;
        # REQUIRED writable location (will be created on first run)
        doomLocalDir = "~/.local/share/nix-doom-local";
      };

      # Correct access in 2026 nixpkgs-unstable: kebab-case name
      bundledNerdFonts = pkgs.nerd-fonts.jetbrains-mono;

      # Wrapped Doom Emacs with bundled fonts
      doomWithBundledFonts = pkgs.stdenv.mkDerivation {
        name = "doom-emacs-with-nerd-fonts";

        nativeBuildInputs = [ pkgs.makeWrapper ];

        dontUnpack = true;
        dontBuild = true;

        installPhase = ''
          runHook preInstall

          mkdir -p $out/bin

          # Main emacs wrapper – inject fonts via XDG_DATA_DIRS + fontconfig
          makeWrapper ${myDoomEmacs}/bin/emacs $out/bin/emacs \
            --prefix XDG_DATA_DIRS : "${bundledNerdFonts}/share" \
            --prefix XDG_DATA_DIRS : "${bundledNerdFonts}/share/fonts" \
            --set-default FONTCONFIG_PATH ${pkgs.fontconfig}/etc/fonts

          # Wrap emacsclient too (highly recommended)
          makeWrapper ${myDoomEmacs}/bin/emacsclient $out/bin/emacsclient \
            --inherit-argv0

          runHook postInstall
        '';

        meta = {
          description = "Doom Emacs with bundled JetBrainsMono Nerd Font";
          mainProgram = "emacs";
        };
      };

    in
    {
      packages.${system} = {
        default = myDoomEmacs;
        doom-with-fonts = doomWithBundledFonts;
      };

      apps.${system} = {
        default = {
          type = "app";
          program = "${myDoomEmacs}/bin/emacs";
        };

        doom-with-fonts = {
          type = "app";
          program = "${doomWithBundledFonts}/bin/emacs";
        };
      };
    };
}