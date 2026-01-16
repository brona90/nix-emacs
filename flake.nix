{
  description = "Gregory's Doom Emacs via Nix – bundled Nerd Fonts (VictorMono + Symbols)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    doom-emacs = {
      url = "github:marienz/nix-doom-emacs-unstraightened";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, doom-emacs, ... }:
    let
      # Support multiple systems
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      
      # Helper to generate attrs for each system
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      
      # Check if system is Darwin
      isDarwin = system: builtins.elem system [ "x86_64-darwin" "aarch64-darwin" ];
      
      # Get pkgs for a specific system
      pkgsFor = system: import nixpkgs {
        inherit system;
        overlays = [ doom-emacs.overlays.default ];
        config = {
          allowUnfree = true;
          # Allow broken packages on Darwin since some Emacs deps don't build
          allowBroken = isDarwin system;
        };
      };
      
      # Build the emacs package for a specific system
      mkEmacsPackage = system:
        let
          pkgs = pkgsFor system;
          darwinBuild = isDarwin system;
          
          # Use different doom configs for Darwin vs Linux
          # Darwin config excludes modules that depend on wayland/X11
          doomConfigSrc = if darwinBuild 
            then ./doom.d-darwin
            else ./doom.d;
          
          # Fallback to main doom.d if darwin-specific doesn't exist
          doomConfigDir = if darwinBuild && builtins.pathExists ./doom.d-darwin
            then ./doom.d-darwin
            else ./doom.d;
          
          # Copy doom.d to the Nix store
          doomConfig = pkgs.stdenv.mkDerivation {
            name = "doom-config";
            src = doomConfigDir;
            installPhase = ''
              mkdir -p $out
              cp -r $src/* $out/
            '';
          };

          myDoomEmacs = pkgs.emacsWithDoom {
            doomDir = doomConfig;
            doomLocalDir = "~/.local/share/nix-doom";
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

          # Wrapper for doom sync
          # Note: Don't override DOOMDIR/DOOMLOCALDIR - upstream sets them correctly
          doomSync = pkgs.writeShellScriptBin "doom-sync" ''
            export PATH="${pkgs.git}/bin:${pkgs.ripgrep}/bin:$PATH"
            
            echo "Config is managed by Nix (immutable)"
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

              # Main emacs wrapper with fonts and ispell
              # Note: Do NOT override DOOMDIR - the upstream emacs-with-doom sets it correctly
              makeWrapper ${myDoomEmacs}/bin/emacs $out/bin/emacs \
                --set FONTCONFIG_FILE ${fontconfigFile} \
                --prefix XDG_DATA_DIRS : "${bundledNerdFonts}/share" \
                --prefix PATH : "${pkgs.ispell}/bin"

              # Wrap emacsclient too
              makeWrapper ${myDoomEmacs}/bin/emacsclient $out/bin/emacsclient \
                --set FONTCONFIG_FILE ${fontconfigFile} \
                --prefix XDG_DATA_DIRS : "${bundledNerdFonts}/share" \
                --prefix PATH : "${pkgs.ispell}/bin"

              runHook postInstall
            '';

            meta = {
              description = "Doom Emacs with bundled VictorMono and Symbols Nerd Font";
              mainProgram = "emacs";
            };
          };
        in
        { inherit doomWithBundledFonts myDoomEmacs testFonts doomSync; pkgs = pkgs; };

    in
    {
      packages = forAllSystems (system:
        let
          built = mkEmacsPackage system;
        in
        {
          default = built.doomWithBundledFonts;
          doom-with-fonts = built.doomWithBundledFonts;
          doom-unwrapped = built.myDoomEmacs;
          test-fonts = built.testFonts;
          doom-sync = built.doomSync;
        }
      );

      apps = forAllSystems (system:
        let
          built = mkEmacsPackage system;
        in
        {
          default = {
            type = "app";
            program = "${built.doomWithBundledFonts}/bin/emacs";
            meta = {
              description = "Doom Emacs with bundled fonts";
            };
          };

          doom-with-fonts = {
            type = "app";
            program = "${built.doomWithBundledFonts}/bin/emacs";
            meta = {
              description = "Doom Emacs with bundled fonts";
            };
          };

          doom-unwrapped = {
            type = "app";
            program = "${built.myDoomEmacs}/bin/emacs";
            meta = {
              description = "Doom Emacs without font wrapper";
            };
          };

          test-fonts = {
            type = "app";
            program = "${built.testFonts}/bin/test-fonts";
            meta = {
              description = "Test font configuration";
            };
          };

          doom-sync = {
            type = "app";
            program = "${built.doomSync}/bin/doom-sync";
            meta = {
              description = "Sync Doom Emacs packages";
            };
          };
        }
      );

      devShells = forAllSystems (system:
        let
          built = mkEmacsPackage system;
          pkgs = built.pkgs;
        in
        {
          default = pkgs.mkShell {
            packages = [ built.doomWithBundledFonts pkgs.fontconfig pkgs.ispell built.testFonts built.doomSync ];
            shellHook = ''
              echo "Doom Emacs environment (immutable config)"
              echo ""
              echo "Commands:"
              echo "  emacs      - Launch Emacs with fonts"
              echo "  doom-sync  - Install/update packages"
              echo "  test-fonts - Verify fonts"
              echo ""
              echo "Config is managed by Nix. To change config:"
              echo "  1. Edit doom.d/ or doom.d-darwin/"
              echo "  2. nix build && doom-sync"
              echo "  3. Commit and push"
            '';
          };
        }
      );
    };
}
