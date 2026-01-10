# Nix Doom Emacs Flake

Declarative and reproducible Doom Emacs setup using [nix-doom-emacs-unstraightened](https://github.com/marienz/nix-doom-emacs-unstraightened).

## Features

- Configured via your local `doom.d/` directory
- Uses `emacsWithDoom` for clean integration
- Writable `doomLocalDir` for caches, undo history, etc.
- Includes basic devShell with ripgrep and fd
- Pre-configured for modern development workflows

## Enabled Modules

### Completion & UI

- **vertico** - Modern search and completion
- **company** - Code completion backend
- **treemacs** - Project file explorer
- **minimap** - Code overview sidebar
- **tabs** & **workspaces** - Tab-based workflow with persistence

### Language Support

- **Nix** - Native Nix language support
- **Go, Rust, Haskell, Python** - With LSP integration
- **JavaScript, JSON, YAML, TOML** - Web and config formats
- **Markdown, LaTeX, Org** - Documentation and writing
- **Shell scripting** - Bash/Zsh support
- **Common Lisp, Emacs Lisp, Lua** - Lisp family languages

### Development Tools

- **LSP** - Language Server Protocol integration
- **Magit** - Git porcelain with Forge (GitHub/GitLab)
- **tree-sitter** - Advanced syntax parsing
- **direnv** - Per-project environment management
- **Docker & Terraform** - Infrastructure tooling
- **vterm** - Superior terminal emulation

### Productivity

- **org-mode** - Task management and note-taking
- **org-roam** - Zettelkasten note system
- **org-journal** - Daily journaling
- **deft** - Fast note search
- **pdf-tools** - Enhanced PDF viewing

### Editor Enhancements

- **Evil mode** - Vim keybindings everywhere
- **Snippets** - Code templates
- **Multiple cursors** - Multi-point editing
- **Spell checking** - Flyspell integration
- **Syntax highlighting** - Tree-sitter powered

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

## Configuration

Your Doom configuration lives in `doom.d/` with three key files:

- `init.el` - Module selection and flags
- `packages.el` - Package declarations
- `config.el` - Personal configuration and customization

After modifying your configuration, rebuild with `nix build`.

Built with ❤️ using [Nix](https://nixos.org), [Doom Emacs](https://github.com/doomemacs/doomemacs), and [nix-doom-emacs-unstraightened](https://github.com/marienz/nix-doom-emacs-unstraightened).

Enjoy your perfectly reproducible Doom Emacs! ❄️