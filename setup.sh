#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${HOME}/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"

is_command() { command -v "$1" >/dev/null 2>&1; }

log() { printf "\n==> %s\n" "$1"; }

confirm() {
  local prompt="${1:-Continue?}"
  local reply=""
  read -r -p "${prompt} [Y/n] " reply
  [[ -z "$reply" || "$reply" =~ ^([Yy]([Ee][Ss])?)$ ]]
}

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

trust_third_party_taps() {
  # Homebrew refuses to load formulae from untrusted third-party taps, which
  # aborts `brew bundle` (and therefore this whole script, under `set -e`).
  # Tap + trust them up front so the bundle can resolve them.
  local taps=("anomalyco/tap")
  local tap
  for tap in "${taps[@]}"; do
    brew tap "$tap" >/dev/null 2>&1 || true
    # `brew trust` only exists on newer Homebrew; ignore if unavailable.
    brew trust "$tap" >/dev/null 2>&1 || true
  done
}

brew_bundle() {
  log "Installing/updating Homebrew bundle..."
  brew update
  trust_third_party_taps
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

remove_stale_symlink() {
  # Drop a symlink whose target no longer exists (e.g. a config we deleted from
  # the repo). Leaves real files and healthy links alone.
  local path="$1"
  if [[ -L "$path" && ! -e "$path" ]]; then
    log "Removing stale symlink: $path -> $(readlink "$path")"
    rm -f "$path"
  fi
}

install_dotfiles() {
  log "Linking dotfiles..."
  # Zsh
  link_file "${DOTFILES_DIR}/zsh/zshenv"    "${HOME}/.zshenv"
  link_file "${DOTFILES_DIR}/zsh/zshrc"     "${HOME}/.zshrc"
  # We don't ship a zprofile; clean up links left by older versions of this repo.
  remove_stale_symlink "${HOME}/.zprofile"

  # Git
  link_file "${DOTFILES_DIR}/git/gitconfig"        "${HOME}/.gitconfig"
  link_file "${DOTFILES_DIR}/git/gitignore_global" "${HOME}/.gitignore_global"
  # gitconfig sets core.attributesfile = ~/.gitattributes
  link_file "${DOTFILES_DIR}/git/gitattributes"    "${HOME}/.gitattributes"

  # SSH signing trust list (public keys only; gitconfig points at this)
  link_file "${DOTFILES_DIR}/ssh/allowed_signers" "${HOME}/.ssh/allowed_signers"

  # Starship + Ghostty (XDG config)
  link_file "${DOTFILES_DIR}/config/starship.toml" "${HOME}/.config/starship.toml"
  link_file "${DOTFILES_DIR}/config/ghostty/config" "${HOME}/.config/ghostty/config"

  # Zed (primary editor — $EDITOR)
  link_file "${DOTFILES_DIR}/config/zed/settings.json" "${HOME}/.config/zed/settings.json"

  # mise toolchain config + global npm packages
  link_file "${DOTFILES_DIR}/toolchains/mise.toml" "${HOME}/.config/mise/config.toml"
  link_file "${DOTFILES_DIR}/toolchains/default-npm-packages" "${HOME}/.default-npm-packages"
}

ensure_github_auth() {
  if ! is_command gh; then
    return 0
  fi

  local required_scopes="admin:ssh_signing_key"

  # Already authenticated — just ensure we have the required scopes
  if gh auth status --hostname github.com >/dev/null 2>&1; then
    local token_scopes
    token_scopes="$(gh auth status --hostname github.com 2>&1 | grep "Token scopes" || true)"
    if echo "$token_scopes" | grep -q "$required_scopes"; then
      return 0
    fi
    log "GitHub token missing scope: ${required_scopes}. Refreshing..."
    gh auth refresh -h github.com -s "$required_scopes" || {
      log "Scope refresh failed. Run manually: gh auth refresh -h github.com -s ${required_scopes}"
      return 0
    }
    return 0
  fi

  if [[ ! -t 0 ]]; then
    log "GitHub auth not configured (non-interactive shell). Run: gh auth login"
    return 0
  fi

  log "GitHub auth (gh) is required for git/GitHub operations."
  if ! confirm "Authenticate GitHub now with gh?"; then
    log "Skipping GitHub auth. You can run later: gh auth login"
    return 0
  fi

  if [[ -n "${GH_TOKEN:-}" ]]; then
    gh auth login --hostname github.com --git-protocol https --with-token <<<"${GH_TOKEN}" || {
      log "GitHub auth failed or was cancelled. You can run later: gh auth login"
      return 0
    }
    return 0
  fi

  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    gh auth login --hostname github.com --git-protocol https --with-token <<<"${GITHUB_TOKEN}" || {
      log "GitHub auth failed or was cancelled. You can run later: gh auth login"
      return 0
    }
    return 0
  fi

  gh auth login --hostname github.com --git-protocol https -s "$required_scopes" || {
    log "GitHub auth failed or was cancelled. You can run later: gh auth login"
    return 0
  }
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
  ln -sfn "${DOTFILES_DIR}/ai/codex.config.toml" "$HOME/.codex/config.toml"

  # OpenCode reads ~/.config/opencode/.opencode.json
  link_file "${DOTFILES_DIR}/ai/opencode.json" "$HOME/.config/opencode/.opencode.json"

  # Claude Code reads ~/.claude/CLAUDE.md
  ln -sfn "$AGENTS_SRC" "$HOME/.claude/CLAUDE.md"

  # Claude Code user settings
  link_file "${DOTFILES_DIR}/ai/claude-settings.json" "$HOME/.claude/settings.json"

  # Conductor user settings
  link_file "${DOTFILES_DIR}/ai/conductor.settings.toml" "$HOME/.conductor/settings.toml"
}

ensure_ssh_signing() {
  local key_path="${HOME}/.ssh/id_ed25519"
  local signers_file="${DOTFILES_DIR}/ssh/allowed_signers"
  local email
  email="$(git config user.email 2>/dev/null || echo "brennanspellacy@gmail.com")"

  mkdir -p "${HOME}/.ssh"
  chmod 700 "${HOME}/.ssh"

  if [[ ! -f "$key_path" ]]; then
    log "No signing key at ${key_path}."
    echo "  Prefer RESTORING your existing key (1Password / backup) over generating"
    echo "  a new one — a new key means previously signed commits no longer verify"
    echo "  unless you keep the old public key in ssh/allowed_signers."
    echo
    if [[ ! -t 0 ]]; then
      log "Non-interactive shell; skipping key generation. Restore the key, then re-run."
      return 0
    fi
    if ! confirm "Generate a NEW ed25519 signing key now?"; then
      log "Skipped. Restore ~/.ssh/id_ed25519 and re-run ./setup.sh"
      return 0
    fi
    ssh-keygen -t ed25519 -C "$email" -f "$key_path" -N ""
  fi

  chmod 600 "$key_path"

  # Point gitconfig.local at the signing key (idempotent)
  local current_key
  current_key="$(git config --file "${HOME}/.gitconfig.local" user.signingkey 2>/dev/null || true)"
  if [[ "$current_key" != "${key_path}.pub" ]]; then
    git config --file "${HOME}/.gitconfig.local" user.signingkey "${key_path}.pub"
  fi

  # allowed_signers is tracked in the repo (and symlinked by install_dotfiles) so
  # that old keys stay trusted. Warn — don't overwrite — if this key isn't listed.
  local pub_key_body
  pub_key_body="$(awk '{print $1" "$2}' "${key_path}.pub")"
  if ! grep -qF "$pub_key_body" "$signers_file" 2>/dev/null; then
    log "WARNING: this machine's signing key is not in ssh/allowed_signers."
    echo "  Your own signatures will show as untrusted until you add it:"
    echo "    echo \"${email} ${pub_key_body}\" >> ${signers_file}"
    echo "  Then commit it to the dotfiles repo."
  fi

  # Upload signing key to GitHub if gh is authenticated
  if is_command gh && gh auth status --hostname github.com >/dev/null 2>&1; then
    log "Ensuring SSH signing key is on GitHub..."
    gh ssh-key add "${key_path}.pub" --type signing --title "$(hostname)" 2>/dev/null || true
  else
    log "GitHub CLI not authenticated. Add signing key manually:"
    log "  gh ssh-key add ~/.ssh/id_ed25519.pub --type signing"
  fi
}

ensure_gh_config() {
  # gh rewrites ~/.config/gh/config.yml itself, so we set preferences through
  # the CLI rather than symlinking the file.
  is_command gh || return 0
  log "Configuring gh..."
  gh config set git_protocol https >/dev/null 2>&1 || true
  gh alias set co 'pr checkout' --clobber >/dev/null 2>&1 || true
}

install_bun() {
  if is_command bun || [[ -x "${HOME}/.bun/bin/bun" ]]; then
    log "Bun already installed; skipping (run 'bun upgrade' to update)."
    return 0
  fi
  log "Installing Bun..."
  curl -fsSL https://bun.sh/install | bash
}

main() {
  ensure_xcode_clt
  ensure_homebrew
  brew_bundle
  ensure_github_auth
  ensure_gh_config
  ensure_zsh_default_shell
  install_bun
  # Link before signing so ~/.ssh/allowed_signers exists when we check it.
  install_dotfiles
  ensure_ssh_signing
  run_macos_defaults
  ensure_mise_activated
  link_agents_configuration

  log "Done."
  echo "Restart your terminal (or run: exec zsh)."
  echo "Then see MIGRATION.md for the credentials that must be moved by hand."
}

main "$@"
