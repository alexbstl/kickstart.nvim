#!/usr/bin/env bash
#
# Bootstrap script for this Neovim config on a fresh machine.
#
# Installs the *system-level* dependencies that Neovim can't install itself,
# then launches Neovim headless so lazy.nvim / Mason / Treesitter pull the rest.
#
# Usage:
#   ./install.sh            # core editor deps + plugin bootstrap
#   ./install.sh --latex    # also install the LaTeX toolchain (large)
#   ./install.sh --no-boot  # skip the headless plugin bootstrap
#
# Supports: macOS (Homebrew) and Debian/Ubuntu (apt).
set -euo pipefail

WITH_LATEX=0
BOOTSTRAP=1
for arg in "$@"; do
  case "$arg" in
    --latex)   WITH_LATEX=1 ;;
    --no-boot) BOOTSTRAP=0 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 1 ;;
  esac
done

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

# --- macOS -------------------------------------------------------------------
install_macos() {
  if ! command -v brew >/dev/null 2>&1; then
    log "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  log "Installing core dependencies via Homebrew..."
  brew install neovim git ripgrep fd make curl unzip node openjdk tree-sitter
  # Nerd Font (needed for icons; vim.g.have_nerd_font)
  brew install --cask font-jetbrains-mono-nerd-font || true

  if [ "$WITH_LATEX" -eq 1 ]; then
    log "Installing LaTeX toolchain (BasicTeX + latexmk/biber + Skim viewer)..."
    brew install --cask mactex-no-gui skim
    # BasicTeX ships without latexmk/biber; pull them in via tlmgr.
    eval "$(/usr/libexec/path_helper)" 2>/dev/null || true
    sudo tlmgr update --self || true
    sudo tlmgr install latexmk biber biblatex || true
  fi
}

# --- Debian / Ubuntu ---------------------------------------------------------
install_apt() {
  log "Installing core dependencies via apt..."
  sudo apt-get update
  sudo apt-get install -y \
    git ripgrep fd-find build-essential make curl unzip nodejs npm \
    default-jre fonts-jetbrains-mono
  # tree-sitter CLI (some parsers must be generated from grammar). Prefer cargo/npm if present.
  command -v tree-sitter >/dev/null 2>&1 || sudo npm install -g tree-sitter-cli || true
  # Neovim: apt versions are often old; prefer the unstable PPA for >=0.11.
  if ! command -v nvim >/dev/null 2>&1; then
    log "Installing Neovim (unstable PPA for a recent version)..."
    sudo apt-get install -y software-properties-common
    sudo add-apt-repository -y ppa:neovim-ppa/unstable
    sudo apt-get update && sudo apt-get install -y neovim
  fi
  # Debian names the binary `fdfind`; alias it to `fd` for telescope.
  if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
    sudo ln -sf "$(command -v fdfind)" /usr/local/bin/fd
  fi

  if [ "$WITH_LATEX" -eq 1 ]; then
    log "Installing LaTeX toolchain (texlive + latexmk/biber + okular)..."
    sudo apt-get install -y texlive-latex-extra latexmk biber okular
  fi
}

# --- dispatch ----------------------------------------------------------------
case "$(uname -s)" in
  Darwin) install_macos ;;
  Linux)
    if command -v apt-get >/dev/null 2>&1; then
      install_apt
    else
      echo "Unsupported Linux distro (no apt). Install manually:" >&2
      echo "  neovim(>=0.11) git ripgrep fd gcc/clang make curl unzip nodejs npm java + a Nerd Font" >&2
      exit 1
    fi
    ;;
  *) echo "Unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac

# --- plugin / LSP / parser bootstrap ----------------------------------------
if [ "$BOOTSTRAP" -eq 1 ]; then
  log "Bootstrapping plugins (lazy.nvim), LSP servers (Mason), and parsers (Treesitter)..."
  nvim --headless "+Lazy! sync" +qa
  nvim --headless "+MasonToolsUpdateSync" +qa 2>/dev/null || true
  nvim --headless "+TSUpdateSync" +qa
  if [ "$WITH_LATEX" -eq 1 ]; then
    log "Installing ltex grammar language server via Mason..."
    nvim --headless "+MasonInstall ltex-ls" +qa || true
  fi
fi

log "Done. Launch \`nvim\` — remaining parsers/servers install on first use."
