#!/usr/bin/env bash
set -euo pipefail

# Finder: show all filename extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Dock: speed up animations a bit
defaults write com.apple.dock autohide-time-modifier -float 0.2
defaults write com.apple.dock autohide-delay -float 0
killall Dock >/dev/null 2>&1 || true

# Screenshot location
mkdir -p "$HOME/Screenshots"
defaults write com.apple.screencapture location -string "$HOME/Screenshots"
killall SystemUIServer >/dev/null 2>&1 || true