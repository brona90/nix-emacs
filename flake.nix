{
  description = "Gregory's Doom Emacs via Nix – bundled Nerd Fonts (VictorMono + Symbols)";

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

      myDoomEmacs = pkgs.emacsWithDoom {
        doomDir = doom-config;
        doomLocalDir = "~/.local/share/doom";
      };

      # Bundle both VictorMono (for text) and Symbols Nerd Font (for icons)
      victorMono = if pkgs ? nerd-fonts 
        then pkgs.nerd-fonts.victor-mono
        else pkgs.nerdfonts.override { fonts = [ "VictorMono" ]; };

      symbolsNerdFont = if pkgs ? nerd-fonts
        then pkgs.nerd-fonts.symbols-only
        else pkgs.nerdfonts.override { fonts = [ "NerdFontsSymbolsOnly" ]; };

      # Combine both fonts
      bundledNerdFonts = pkgs.symlinkJoin {
        name = "nerd-fonts-combined";
        paths = [ victorMono symbolsNerdFont ];
      };

      # Create a fontconfig configuration that points ONLY to our fonts
      fontconfigFile = pkgs.makeFontsConf {
        fontDirectories = [ bundledNerdFonts ];
      };

      # Test script to verify fonts in isolation
      testFonts = pkgs.writeShellScriptBin "test-fonts" ''
        echo "=== Testing font isolation ==="
        echo "Font directory: ${bundledNerdFonts}"
        echo ""
        echo "Files in font package:"
        find ${bundledNerdFonts} -name "*.ttf" -o -name "*.otf" 2>/dev/null | head -20
        echo ""
        
        # Create a temporary cache directory
        TEMP_CACHE=$(mktemp -d)
        trap "rm -rf $TEMP_CACHE" EXIT
        
        echo "=== Font family names (use these in Emacs) ==="
        env -i \
          HOME="$TEMP_CACHE" \
          FONTCONFIG_FILE="${fontconfigFile}" \
          ${pkgs.fontconfig}/bin/fc-list : family 2>/dev/null | sort -u | grep -i victor
        
        echo ""
        echo "=== Symbols Nerd Font ==="
        env -i \
          HOME="$TEMP_CACHE" \
          FONTCONFIG_FILE="${fontconfigFile}" \
          ${pkgs.fontconfig}/bin/fc-list : family 2>/dev/null | sort -u | grep -i "symbols\|nerd"
      '';

      # Wrapper for doom sync that uses writable config
      doomSync = pkgs.writeShellScriptBin "doom-sync" ''
        export DOOMDIR="$HOME/.config/doom"
        export DOOMLOCALDIR="$HOME/.local/share/doom"
        
        echo "Using DOOMDIR: $DOOMDIR"
        echo "Using DOOMLOCALDIR: $DOOMLOCALDIR"
        echo ""
        
        # Use the doom binary from myDoomEmacs
        exec ${myDoomEmacs}/bin/doom sync "$@"
      '';

      doomWithBundledFonts = pkgs.stdenv.mkDerivation {
        name = "doom-emacs-with-nerd-fonts";

        nativeBuildInputs = [ pkgs.makeWrapper ];

        dontUnpack = true;
        dontBuild = true;

        installPhase = ''
          runHook preInstall

          mkdir -p $out/bin

          # Main emacs wrapper with fonts, ispell, AND writable DOOMDIR
          makeWrapper ${myDoomEmacs}/bin/emacs $out/bin/emacs \
            --set FONTCONFIG_FILE ${fontconfigFile} \
            --prefix XDG_DATA_DIRS : "${bundledNerdFonts}/share" \
            --prefix PATH : "${pkgs.ispell}/bin" \
            --run 'export DOOMDIR="''${DOOMDIR:-$HOME/.config/doom}"' \
            --run 'export DOOMLOCALDIR="''${DOOMLOCALDIR:-$HOME/.local/share/doom}"'

          # Wrap emacsclient too
          makeWrapper ${myDoomEmacs}/bin/emacsclient $out/bin/emacsclient \
            --set FONTCONFIG_FILE ${fontconfigFile} \
            --prefix XDG_DATA_DIRS : "${bundledNerdFonts}/share" \
            --prefix PATH : "${pkgs.ispell}/bin" \
            --run 'export DOOMDIR="''${DOOMDIR:-$HOME/.config/doom}"' \
            --run 'export DOOMLOCALDIR="''${DOOMLOCALDIR:-$HOME/.local/share/doom}"'

          runHook postInstall
        '';

        meta = {
          description = "Doom Emacs with bundled VictorMono and Symbols Nerd Font";
          mainProgram = "emacs";
        };
      };

    in
    {
      packages.${system} = {
        default = doomWithBundledFonts;
        doom-with-fonts = doomWithBundledFonts;
        doom-unwrapped = myDoomEmacs;
        test-fonts = testFonts;
        doom-sync = doomSync;
      };

      apps.${system} = {
        default = {
          type = "app";
          program = "${doomWithBundledFonts}/bin/emacs";
        };

        doom-with-fonts = {
          type = "app";
          program = "${doomWithBundledFonts}/bin/emacs";
        };

        doom-unwrapped = {
          type = "app";
          program = "${myDoomEmacs}/bin/emacs";
        };

        test-fonts = {
          type = "app";
          program = "${testFonts}/bin/test-fonts";
        };

        doom-sync = {
          type = "app";
          program = "${doomSync}/bin/doom-sync";
        };
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = [ doomWithBundledFonts pkgs.fontconfig pkgs.ispell testFonts doomSync ];
        shellHook = ''
          echo "Doom Emacs environment"
          echo ""
          echo "Commands:"
          echo "  emacs      - Launch Emacs with fonts"
          echo "  doom-sync  - Install/update packages"
          echo "  test-fonts - Verify fonts"
          echo ""
          
          if [ ! -d "$HOME/.config/doom" ]; then
            echo "⚠ First time setup:"
            echo "  mkdir -p ~/.config/doom"
            echo "  cp doom.d/* ~/.config/doom/"
          fi
        '';
      };
    };
}