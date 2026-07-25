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
- `ai/` — agent instructions and configs (`AGENTS.global.md`, `codex.config.toml`, `conductor.settings.toml`, `opencode.json`).
  - User-level files are symlinked into `$HOME` by `setup.sh` (e.g. `claude-settings.json` → `~/.claude/settings.json`).
  - Repo-level files for this repo live here too and are symlinked back to the root: `claude-settings.local.json` → `.claude/settings.local.json`, `claude-skills/` → `.claude/skills/`, `conductor.settings.local.toml` → `.conductor/settings.local.toml`.

## Helpers

- `uq` — unquarantine a Homebrew-installed app or binary.
  - Examples: `uq chromedriver` or `uq /Applications/SomeApp.app`
