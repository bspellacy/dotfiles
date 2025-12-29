#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${HOME}/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"

is_command() { command -v "$1" >/dev/null 2>&1; }

log() { printf "\n==> %s\n" "$1"; }

ensure_xcode_clt() {
  if xcode-select -p >/dev/null 2>&1; then
    return 0
  fi
  log "Installing Xcode Command Line Tools..."
  xcode-select --install || true
  log "If a GUI prompt appeared, finish it, then re-run ./install.sh"
  exit 0
}

ensure_homebrew() {
  if is_command brew; then return 0; fi
  log "Installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # shellenv for Apple Silicon vs Intel
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

brew_bundle() {
  log "Installing/updating Homebrew bundle..."
  brew update
  brew bundle --file "${DOTFILES_DIR}/Brewfile"
}

backup_path_if_conflict() {
  local target="$1"
  if [[ -e "$target" || -L "$target" ]]; then
    mkdir -p "$BACKUP_DIR"
    log "Backing up existing: $target -> $BACKUP_DIR"
    mv "$target" "$BACKUP_DIR/"
  fi
}

link_file() {
  local src="$1"
  local dest="$2"
  local dest_dir
  dest_dir="$(dirname "$dest")"

  mkdir -p "$dest_dir"

  # If already linked correctly, do nothing (idempotent)
  if [[ -L "$dest" ]]; then
    local current
    current="$(readlink "$dest")"
    if [[ "$current" == "$src" ]]; then
      return 0
    fi
  fi

  # If a real file exists, back it up once
  if [[ -e "$dest" && ! -L "$dest" ]]; then
    backup_path_if_conflict "$dest"
  fi

  ln -sfn "$src" "$dest"
}

ensure_zsh_default_shell() {
  # Ensure brew zsh is in /etc/shells
  local brew_zsh=""
  if [[ -x /opt/homebrew/bin/zsh ]]; then brew_zsh="/opt/homebrew/bin/zsh"; fi
  if [[ -x /usr/local/bin/zsh ]]; then brew_zsh="/usr/local/bin/zsh"; fi

  if [[ -n "$brew_zsh" ]]; then
    if ! grep -q "$brew_zsh" /etc/shells; then
      log "Adding Homebrew zsh to /etc/shells (requires sudo)..."
      echo "$brew_zsh" | sudo tee -a /etc/shells >/dev/null
    fi
    if [[ "$SHELL" != "$brew_zsh" ]]; then
      log "Setting default shell to Homebrew zsh (requires sudo)..."
      sudo chsh -s "$brew_zsh" "$USER" || true
    fi
  fi
}

install_dotfiles() {
  log "Linking dotfiles..."
  # Zsh
  link_file "${DOTFILES_DIR}/zsh/zshenv"    "${HOME}/.zshenv"
  link_file "${DOTFILES_DIR}/zsh/zprofile"  "${HOME}/.zprofile"
  link_file "${DOTFILES_DIR}/zsh/zshrc"     "${HOME}/.zshrc"

  # Git
  link_file "${DOTFILES_DIR}/git/gitconfig"        "${HOME}/.gitconfig"
  link_file "${DOTFILES_DIR}/git/gitignore_global" "${HOME}/.gitignore_global"

  # Starship + Ghostty (XDG config)
  link_file "${DOTFILES_DIR}/config/starship.toml" "${HOME}/.config/starship.toml"
  link_file "${DOTFILES_DIR}/config/ghostty/config" "${HOME}/.config/ghostty/config"

  # mise toolchain config
  link_file "${DOTFILES_DIR}/toolchains/mise.toml" "${HOME}/.config/mise/config.toml"
}

run_macos_defaults() {
  log "Applying macOS defaults (safe to re-run)..."
  bash "${DOTFILES_DIR}/scripts/macos_defaults.sh"
}

ensure_mise_activated() {
  # We’ll rely on .zshrc to activate it; this just ensures it exists.
  if is_command mise; then
    mise --version >/dev/null 2>&1 || true
  fi
}

link_agents_configuration() {
  # --- Global agent instructions (Codex + Claude) ---

  mkdir -p "$HOME/.codex" "$HOME/.claude"

 # canonical source file in your dotfiles repo
  AGENTS_SRC="${DOTFILES_DIR}/ai/AGENTS.global.md"

  # Codex reads ~/.codex/AGENTS.md (unless overridden)
  ln -sfn "$AGENTS_SRC" "$HOME/.codex/AGENTS.md"

  # Claude Code reads ~/.claude/CLAUDE.md
  ln -sfn "$AGENTS_SRC" "$HOME/.claude/CLAUDE.md"
}

main() {
  ensure_xcode_clt
  ensure_homebrew
  brew_bundle
  ensure_zsh_default_shell
  install_dotfiles
  run_macos_defaults
  ensure_mise_activated
  link_agents_configuration

  log "Done."
  echo "Restart your terminal (or run: exec zsh)."
}

main "$@"