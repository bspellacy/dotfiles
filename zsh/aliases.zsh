# Ruby
alias be='bundle exec'
alias bi='bundle install'

# Shell
alias la='ls -a'
alias oc='opencode'

uq() {
  local target resolved prefix
  target="${1:?usage: uq <path>}"

  echo "uq: resolving $target"

  if ! command -v brew >/dev/null; then
    echo "brew not found" >&2
    return 1
  fi

  if [[ "$target" == */* ]]; then
    resolved="$target"
  else
    resolved="$(command -v "$target" 2>/dev/null)" || {
      echo "command not found: $target" >&2
      return 1
    }
  fi

  if [[ ! -e "$resolved" ]]; then
    echo "path not found: $resolved" >&2
    return 1
  fi

  echo "uq: target $resolved"

  if command -v /usr/bin/realpath >/dev/null; then
    resolved="$(/usr/bin/realpath "$resolved" 2>/dev/null)" || true
  else
    resolved="$(/usr/bin/python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$resolved" 2>/dev/null)" || true
  fi

  prefix="$(brew --prefix 2>/dev/null)" || {
    echo "brew prefix not found" >&2
    return 1
  }

  if [[ "$resolved" != "$prefix"* ]]; then
    if ! brew list --cask --verbose 2>/dev/null | /usr/bin/grep -F -- "$resolved" >/dev/null; then
      echo "refusing: target not from Homebrew" >&2
      return 1
    fi
  fi

  echo "uq: verified Homebrew install"

  if [[ -d "$resolved" ]]; then
    if ! /usr/bin/xattr -r -p com.apple.quarantine -- "$resolved" >/dev/null 2>&1; then
      echo "uq: already marked safe"
      return 0
    fi
    echo "uq: removing quarantine recursively"
    /usr/bin/xattr -dr com.apple.quarantine -- "$resolved"
  else
    if ! /usr/bin/xattr -p com.apple.quarantine -- "$resolved" >/dev/null 2>&1; then
      echo "uq: already marked safe"
      return 0
    fi
    echo "uq: removing quarantine"
    /usr/bin/xattr -d com.apple.quarantine -- "$resolved"
  fi

  echo "uq: done"
}
