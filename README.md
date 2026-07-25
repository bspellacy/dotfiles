# Brennan Spellacy's Dotfiles

## Bootstrap a new machine

```sh
xcode-select --install          # if not already prompted
git clone https://github.com/<you>/dotfiles.git ~/code/dotfiles
cd ~/code/dotfiles
./setup.sh
exec zsh
```

`setup.sh` is idempotent — re-run it any time. See **[MIGRATION.md](MIGRATION.md)**
for the credentials and machine-local state that must be moved by hand.

## Scope

This repo installs **machine-level** tooling and config only. Project
dependencies (postgres, redis, docker, cloud CLIs, browser drivers, ...) belong
in each project's own `Brewfile` — e.g. `~/code/patch/Brewfile` — not here.

## Structure

- `setup.sh` — installs core tooling (via Homebrew + `Brewfile`) and symlinks configs into your home directory.
- `Brewfile` — Homebrew bundle for CLI tools and casks.
- `MIGRATION.md` — new-machine checklist for everything `setup.sh` can't automate.
- `git/`
  - `gitconfig` — Git defaults + aliases; includes `~/.gitconfig.local` for machine-specific overrides.
  - `gitignore_global` — global ignores.
  - `gitattributes` — global attributes (line-ending normalization).
- `zsh/` — Zsh config (`zshenv`, `zshrc`, `aliases.zsh`, `functions.zsh`).
- `config/` — XDG-style app configs (`starship.toml`, `ghostty/config`, `zed/settings.json`).
- `toolchains/` — tool/runtime config (`mise.toml`, `default-npm-packages`).
- `scripts/` — one-off scripts (e.g. macOS defaults).
- `ai/` — agent instructions and configs (`AGENTS.global.md`, `codex.config.toml`, `conductor.settings.toml`, `opencode.json`).
  - User-level files are symlinked into `$HOME` by `setup.sh` (e.g. `claude-settings.json` → `~/.claude/settings.json`).
  - Repo-level files for this repo live here too and are symlinked back to the root: `claude-settings.local.json` → `.claude/settings.local.json`, `claude-skills/` → `.claude/skills/`, `conductor.settings.local.toml` → `.conductor/settings.local.toml`.

## Notes

- **Ruby is not pinned globally.** `toolchains/mise.toml` pins only Node; each
  project's `.ruby-version` drives the Ruby version via mise.
- **`opencode` comes from `anomalyco/tap`**, which Homebrew treats as untrusted.
  `setup.sh` taps and trusts it before running `brew bundle`.
- **Global npm packages** go in `toolchains/default-npm-packages` (symlinked to
  `~/.default-npm-packages`) so they survive a Node version change.
- **`~/.ssh/allowed_signers` is generated, not tracked.** It is a trust list —
  it decides which keys git accepts as valid signers — and this repo is public,
  so it should not be editable by pull request. `setup.sh` rebuilds it from
  your GitHub-published signing keys (a public, unauthenticated endpoint),
  falling back to the local key when offline. Old keys keep verifying as long
  as they stay registered on GitHub; any manually added lines are preserved
  across regeneration.

## Helpers

- `uq` — unquarantine a Homebrew-installed app or binary.
  - Examples: `uq chromedriver` or `uq /Applications/SomeApp.app`
