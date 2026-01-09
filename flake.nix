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
        doomLocalDir = "~/.local/share/nix-doom-local";
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
        
        echo "=== Fonts visible with isolated fontconfig ==="
        echo "VictorMono fonts:"
        env -i \
          HOME="$TEMP_CACHE" \
          FONTCONFIG_FILE="${fontconfigFile}" \
          ${pkgs.fontconfig}/bin/fc-list 2>/dev/null | grep -i victor
        
        echo ""
        echo "Symbols Nerd Font:"
        env -i \
          HOME="$TEMP_CACHE" \
          FONTCONFIG_FILE="${fontconfigFile}" \
          ${pkgs.fontconfig}/bin/fc-list 2>/dev/null | grep -i "symbols nerd"
        
        echo ""
        if env -i HOME="$TEMP_CACHE" FONTCONFIG_FILE="${fontconfigFile}" ${pkgs.fontconfig}/bin/fc-list 2>/dev/null | grep -qi victor && \
           env -i HOME="$TEMP_CACHE" FONTCONFIG_FILE="${fontconfigFile}" ${pkgs.fontconfig}/bin/fc-list 2>/dev/null | grep -qi "symbols nerd"; then
          echo "✓ Both VictorMono and Symbols Nerd Font are properly isolated and accessible!"
        else
          echo "✗ Some fonts not found. Debugging info:"
          echo "FONTCONFIG_FILE=${fontconfigFile}"
          echo ""
          echo "Fontconfig contents:"
          cat ${fontconfigFile}
          echo ""
          echo "All fonts found:"
          env -i HOME="$TEMP_CACHE" FONTCONFIG_FILE="${fontconfigFile}" ${pkgs.fontconfig}/bin/fc-list 2>/dev/null
        fi
      '';

      doomWithBundledFonts = pkgs.stdenv.mkDerivation {
        name = "doom-emacs-with-nerd-fonts";

        nativeBuildInputs = [ pkgs.makeWrapper ];

        dontUnpack = true;
        dontBuild = true;

        installPhase = ''
          runHook preInstall

          mkdir -p $out/bin

          # Main emacs wrapper with proper font environment
          makeWrapper ${myDoomEmacs}/bin/emacs $out/bin/emacs \
            --set FONTCONFIG_FILE ${fontconfigFile} \
            --prefix XDG_DATA_DIRS : "${bundledNerdFonts}/share"

          # Wrap emacsclient too
          makeWrapper ${myDoomEmacs}/bin/emacsclient $out/bin/emacsclient \
            --set FONTCONFIG_FILE ${fontconfigFile} \
            --prefix XDG_DATA_DIRS : "${bundledNerdFonts}/share"

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
        default = myDoomEmacs;
        doom-with-fonts = doomWithBundledFonts;
        test-fonts = testFonts;
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

        test-fonts = {
          type = "app";
          program = "${testFonts}/bin/test-fonts";
        };
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = [ doomWithBundledFonts pkgs.fontconfig testFonts ];
        shellHook = ''
          echo "Wrapped Doom Emacs available."
          echo "Run 'test-fonts' to verify font isolation."
          echo "Run 'emacs' to launch with bundled fonts."
        '';
      };
    };
}