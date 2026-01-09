# Nix Doom Emacs Flake

Declarative and reproducible Doom Emacs setup using [nix-doom-emacs-unstraightened](https://github.com/marienz/nix-doom-emacs-unstraightened).

## Features

- Configured via your local `doom.d/` directory
- Uses `emacsWithDoom` for clean integration
- Writable `doomLocalDir` for caches, undo history, etc.
- Includes basic devShell with ripgrep and fd

## Quick Start

```bash
# Run Doom Emacs
nix run .

# Build and symlink
nix build .
./result/bin/emacs
```

## Development

```bash
# Enter dev shell
nix develop

# Update inputs
nix flake update
```

Built with ❤️ using [Nix](https://nixos.org), [Doom Emacs](https://github.com/doomemacs/doomemacs), and [nix-doom-emacs-unstaightened](https://github.com/marienz/nix-doom-emacs-unstraightened).
Enjoy your perfectly reproducible Doom Emacs! ❄️
