{
  description = "Gregory's Doom Emacs via Nix – with Nerd Fonts bundled";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    doom-emacs = {
      url = "github:marienz/nix-doom-emacs-unstraightened";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    doom-config = {
      url = "path:./doom.d";  # config files directly inside
      flake = false;
    };
  };

  outputs = { self, nixpkgs, doom-emacs, doom-config, ... }: let
    system = "x86_64-linux";

    pkgs = import nixpkgs {
      inherit system;
      overlays = [ doom-emacs.overlays.default ];
    };

    myDoomEmacs = pkgs.emacsWithDoom {
      doomDir = doom-config;
      doomLocalDir = "~/.local/share/doom";
    };

    # Your chosen Nerd Fonts (add/remove as you like)
    myNerdFonts = pkgs.nerdfonts.override {
      fonts = [ "JetBrainsMono" "FiraCode" "Hack" "Meslo" ];
    };

    # Critical for nerd-icons package
    mySymbolsFont = pkgs.nerdfonts.symbols-only;

  in {
    # Main Doom Emacs package & app
    packages.${system} = {
      default = myDoomEmacs;

      # Fonts exposed as separate packages for easy consumption
      nerdFonts = myNerdFonts;
      nerdSymbols = mySymbolsFont;
      allNerdFonts = pkgs.symlinkJoin {
        name = "all-nerd-fonts";
        paths = [ myNerdFonts mySymbolsFont ];
      };
    };

    apps.${system} = {
      emacs = {
        type = "app";
        program = "${myDoomEmacs}/bin/emacs";
      };
      default = self.apps.${system}.emacs;
    };
  };
}