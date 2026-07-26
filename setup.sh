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

  # Homebrew's installer needs root to create its prefix, and it checks that
  # up front via have_sudo_access(). Under NONINTERACTIVE=1 it invokes
  # `sudo -n`, which by design NEVER prompts — so on a fresh machine with no
  # cached sudo timestamp the check fails instantly and it aborts with:
  #   Need sudo access on macOS (e.g. the user <you> needs to be an Administrator)!
  # even for an account that *is* an admin.
  #
  # Prime the sudo timestamp first (this is what actually prompts for the
  # password), then the installer's non-interactive check succeeds.
  if [[ -t 0 ]]; then
    echo "Homebrew's installer needs administrator access to create its prefix."
    if ! sudo -v; then
      log "Could not obtain sudo access."
      echo "  Homebrew requires an Administrator account on macOS."
      echo "  Check: System Settings > Users & Groups (your user must be 'Administrator')."
      exit 1
    fi
  fi

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
  # Derive the path from the active Homebrew prefix rather than guessing
  # Apple Silicon vs Intel (the old version preferred /usr/local when both existed).
  local brew_prefix brew_zsh
  brew_prefix="$(brew --prefix 2>/dev/null || true)"
  [[ -n "$brew_prefix" ]] || return 0
  brew_zsh="${brew_prefix}/bin/zsh"
  [[ -x "$brew_zsh" ]] || return 0

  local needs_shells_entry=false needs_chsh=false
  grep -qxF "$brew_zsh" /etc/shells || needs_shells_entry=true
  [[ "$SHELL" != "$brew_zsh" ]] && needs_chsh=true
  if [[ "$needs_shells_entry" == false && "$needs_chsh" == false ]]; then
    return 0
  fi

  # This is the only part of setup.sh that needs root. Check up front and skip
  # cleanly if sudo isn't usable — a failure here used to abort the entire run
  # under `set -euo pipefail`, before any dotfiles were linked.
  if ! sudo -v >/dev/null 2>&1; then
    log "Skipping default-shell change: sudo is unavailable or was declined."
    echo "  Everything else will still be set up. To finish this step later:"
    echo "    echo '${brew_zsh}' | sudo tee -a /etc/shells"
    echo "    chsh -s '${brew_zsh}'"
    return 0
  fi

  if [[ "$needs_shells_entry" == true ]]; then
    log "Adding Homebrew zsh to /etc/shells (requires sudo)..."
    if ! echo "$brew_zsh" | sudo tee -a /etc/shells >/dev/null; then
      log "Could not write /etc/shells; skipping default-shell change."
      return 0
    fi
  fi

  if [[ "$needs_chsh" == true ]]; then
    log "Setting default shell to Homebrew zsh..."
    # chsh for your own user doesn't need root; fall back to sudo if it does.
    chsh -s "$brew_zsh" 2>/dev/null \
      || sudo chsh -s "$brew_zsh" "$USER" 2>/dev/null \
      || log "chsh failed. Run manually: chsh -s ${brew_zsh}"
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

  # NOTE: ~/.ssh/allowed_signers is deliberately NOT linked from this repo.
  # It is a trust list, and this repo is public. See ensure_allowed_signers().

  # Starship + Ghostty (XDG config)
  link_file "${DOTFILES_DIR}/config/starship.toml" "${HOME}/.config/starship.toml"
  link_file "${DOTFILES_DIR}/config/ghostty/config" "${HOME}/.config/ghostty/config"

  # Zed (primary editor — $EDITOR)
  link_file "${DOTFILES_DIR}/config/zed/settings.json" "${HOME}/.config/zed/settings.json"

  # mise toolchain config + global npm packages
  link_file "${DOTFILES_DIR}/toolchains/mise.toml" "${HOME}/.config/mise/config.toml"
  link_file "${DOTFILES_DIR}/toolchains/default-npm-packages" "${HOME}/.default-npm-packages"
}

install_launch_agents() {
  # launchd is unreliable with symlinked plists, so these are copied rather than
  # linked. Re-running setup.sh refreshes and reloads any that changed.
  local agents_dir="${HOME}/Library/LaunchAgents"
  local uid domain src label dest
  uid="$(id -u)"
  domain="gui/${uid}"
  mkdir -p "$agents_dir"

  for src in "${DOTFILES_DIR}"/config/launchd/*.plist; do
    [[ -e "$src" ]] || continue
    label="$(basename "$src" .plist)"
    dest="${agents_dir}/${label}.plist"

    # -L check first: an older version of this repo may have symlinked the plist,
    # and cp through a symlink would write back into the repo.
    if [[ -L "$dest" || ! -f "$dest" ]] || ! cmp -s "$src" "$dest"; then
      log "Installing launch agent: ${label}"
      rm -f "$dest"
      cp "$src" "$dest"
      launchctl bootout "${domain}/${label}" >/dev/null 2>&1 || true
    elif launchctl print "${domain}/${label}" >/dev/null 2>&1; then
      continue # up to date and already loaded
    fi

    launchctl bootstrap "$domain" "$dest" >/dev/null 2>&1 \
      || log "Could not load ${label}. Run manually: launchctl bootstrap ${domain} ${dest}"
  done
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

  # Upload signing key to GitHub if gh is authenticated
  if is_command gh && gh auth status --hostname github.com >/dev/null 2>&1; then
    log "Ensuring SSH signing key is on GitHub..."
    gh ssh-key add "${key_path}.pub" --type signing --title "$(hostname)" 2>/dev/null || true
  else
    log "GitHub CLI not authenticated. Add signing key manually:"
    log "  gh ssh-key add ~/.ssh/id_ed25519.pub --type signing"
  fi
}

ensure_allowed_signers() {
  # ~/.ssh/allowed_signers is the trust list git checks commit signatures
  # against (git/gitconfig -> [gpg "ssh"] allowedSignersFile).
  #
  # It is generated here rather than tracked in the repo. This repo is public,
  # and a trust list is the wrong thing to make editable by pull request. The
  # key material is fetched from GitHub, which is already the authoritative
  # public record of your signing keys and keeps old keys around across a
  # rotation — so historical commits keep verifying without us pinning
  # anything in git.
  local signers="${HOME}/.ssh/allowed_signers"
  local identities_file="${HOME}/.config/dotfiles/signing-identities"
  local -a principals=() keys=()
  local email line joined key tmp login

  mkdir -p "${HOME}/.ssh"
  chmod 700 "${HOME}/.ssh"

  email="$(git config --global user.email 2>/dev/null || true)"
  [[ -n "$email" ]] && principals+=("$email")

  # Optional extra principals, one per line. Not normally needed: git resolves
  # the principal from the key, so a commit authored under a different email
  # still verifies against the global identity. Useful only if you want a
  # second identity named explicitly in the trust list.
  if [[ -f "$identities_file" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      line="${line%%#*}"
      line="$(echo "$line" | tr -d '[:space:]')"
      [[ -n "$line" ]] && principals+=("$line")
    done < "$identities_file"
  fi

  if [[ ${#principals[@]} -eq 0 ]]; then
    log "No git user.email configured; skipping allowed_signers."
    return 0
  fi

  # Prefer GitHub's published signing keys (public endpoint, no scope needed).
  if is_command gh; then
    login="$(gh api user --jq .login 2>/dev/null || true)"
    if [[ -n "$login" ]]; then
      while IFS= read -r key; do
        [[ -n "$key" ]] && keys+=("$key")
      done < <(gh api "users/${login}/ssh_signing_keys" --jq '.[].key' 2>/dev/null || true)
    fi
  fi

  # Fall back to the local key when offline or gh isn't set up yet.
  if [[ ${#keys[@]} -eq 0 && -f "${HOME}/.ssh/id_ed25519.pub" ]]; then
    keys+=("$(awk '{print $1" "$2}' "${HOME}/.ssh/id_ed25519.pub")")
  fi

  if [[ ${#keys[@]} -eq 0 ]]; then
    log "No signing keys found (GitHub or local); skipping allowed_signers."
    return 0
  fi

  log "Rebuilding ~/.ssh/allowed_signers (${#keys[@]} key(s), ${#principals[@]} identity/identities)..."
  joined="$(IFS=,; echo "${principals[*]}")"

  tmp="$(mktemp)"
  {
    echo "# Generated by dotfiles/setup.sh — do not edit by hand."
    echo "# Keys come from https://api.github.com/users/${login:-<you>}/ssh_signing_keys"
    echo "# Extra identities come from ${identities_file}"
    for key in "${keys[@]}"; do
      echo "${joined} ${key}"
    done
    # Preserve any manually added lines from a previous file (e.g. a retired
    # key that is no longer registered on GitHub).
    if [[ -f "$signers" ]]; then
      grep -v '^#' "$signers" 2>/dev/null || true
    fi
  } | awk 'NF && !seen[$0]++' > "$tmp"

  mv "$tmp" "$signers"
  chmod 644 "$signers"
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
  install_dotfiles
  install_launch_agents
  ensure_ssh_signing
  ensure_allowed_signers
  run_macos_defaults
  ensure_mise_activated
  link_agents_configuration

  log "Done."
  echo "Restart your terminal (or run: exec zsh)."
  echo "Then see MIGRATION.md for the credentials that must be moved by hand."
}

main "$@"
