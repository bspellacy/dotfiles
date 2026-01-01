# Brennan Spellacy's Dotfiles

## Structure

- `setup.sh` — installs core tooling (via Homebrew + `Brewfile`) and symlinks configs into your home directory.
- `Brewfile` — Homebrew bundle for CLI tools (includes `gh` for GitHub auth).
- `git/`
  - `gitconfig` — Git defaults + aliases; includes `~/.gitconfig.local` for machine-specific overrides.
  - `gitignore_global` — global ignores.
- `zsh/` — Zsh config (`.zshenv`, `.zshrc`).
- `config/` — XDG-style app configs (e.g. `starship.toml`, `ghostty/config`).
- `toolchains/` — tool/runtime config (currently `mise.toml`).
- `scripts/` — one-off scripts (e.g. macOS defaults).
- `ai/` — agent instructions and Codex config (`AGENTS.global.md`, `codex.config.toml`).
