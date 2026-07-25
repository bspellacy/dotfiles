# New machine checklist

`setup.sh` handles everything that can be automated. This file covers what it
deliberately does **not**: credentials, machine-local state, and per-project
dependencies.

## 1. Before wiping the old machine

Copy these off — none of them are (or should be) in git.

| What | Where | Why it matters |
|---|---|---|
| SSH key | `~/.ssh/id_ed25519{,.pub}` | Commit signing + git auth. Restoring beats regenerating — see below. |
| Bundler credentials | `~/.bundle/config` | Contains the private gem token (Sidekiq/contribsys). Without it `bundle install` fails on private gems with a confusing 401. |
| AWS | `~/.aws/` | Profiles + SSO config. |
| gcloud | `~/.config/gcloud/` | Or just re-run `gcloud auth login`. |
| Terraform | `~/.terraform.d/` | Credentials for private module registries. |
| 1Password CLI | `~/.config/op/` | Or re-authenticate from the desktop app. |
| Docker | `~/.docker/config.json` | Registry credentials. |
| Agent credentials | `~/.claude/.credentials.json`, `~/.codex/auth.json`, `~/.gemini/` | Or just re-login in each tool. |
| Shell history | `~/.zsh_history` | Optional, but nice to keep. |

Everything above except the SSH key can also just be re-authenticated from
scratch. The SSH key is the one worth actually copying.

### Why restore the SSH key rather than generate a new one

Restoring keeps one key for both git auth and signing, and avoids churn in your
GitHub key list. `setup.sh` prompts before generating a replacement rather than
doing it silently.

Signature verification itself is resilient either way: `~/.ssh/allowed_signers`
is **generated** by `setup.sh` from your GitHub-published signing keys, not
tracked in this repo (it's a trust list, and the repo is public). Old commits
keep verifying as long as the old key stays registered on GitHub — so if you do
rotate, **add the new key without deleting the old one.**

To trust a key that is no longer on GitHub, append it to
`~/.ssh/allowed_signers` by hand; regeneration preserves manual lines.

## 2. On the new machine

```sh
xcode-select --install          # if not already prompted
git clone https://github.com/<you>/dotfiles.git ~/code/dotfiles
cd ~/code/dotfiles
./setup.sh
exec zsh
```

`setup.sh` is idempotent — re-run it any time. If Xcode CLT wasn't installed, the
first run exits early after kicking off the GUI installer; finish that and run it
again.

## 3. After setup.sh

- **Restore `~/.bundle/config`** (see table above) before touching any Ruby project.
- **Sign in to apps** that aren't CLI-driven: 1Password, Ghostty (nothing to do),
  Zed (settings are symlinked, but sign in for AI features).
- **Zed extensions** are not tracked; Zed will prompt to install per-project ones
  (ruby, prisma, sql, scss, toml, html, git-firefly) as you open files.
- **Verify signing works:**
  ```sh
  git -C ~/code/dotfiles log --show-signature -1   # expect "Good git signature"
  ```
- **Check the pager works** (catches a missing `diff-so-fancy`):
  ```sh
  git -C ~/code/dotfiles show --stat HEAD
  ```

## 4. Per-project dependencies

This repo installs machine-level tooling only. Project dependencies live in each
project's own `Brewfile` / setup script — don't add them here.

```sh
cd ~/code/patch && brew bundle && bin/setup
```

Repos to re-clone: `patch`, `ledger`, `www`, `ceo`, `publius`, `analytics_dbt`.

## 5. Known cruft — do not carry forward

These are installed on the old machine but intentionally absent from the
`Brewfile`. They were superseded and should not be reinstalled:

- `nvm`, `~/.rbenv` — replaced by `mise`
- `zplug`, `pure`, `~/.oh-my-zsh` — replaced by `starship` (the zshrc references none of them)
- `postgresql@15` — orphan; `patch` pins `postgresql@14`
- `pgvector` (the brew formula) — `patch/bin/setup` builds it from source because
  the formula won't build against `postgresql@14`
- `google-cloud-sdk` **and** `gcloud-cli` — same tool, two cask names
