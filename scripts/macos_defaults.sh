#!/usr/bin/env bash
set -euo pipefail

# macOS defaults. Safe to re-run.
# Revert any single setting with:  defaults delete <domain> <key>
#
# Only settings with a concrete development justification are enabled below.
# Taste-based tweaks are listed, commented out, at the bottom — uncomment the
# ones you want rather than discovering them on a new machine.

# ---- Keyboard ----
# Hold a key to repeat instead of showing the accent picker. Required for
# usable vim navigation (config/zed/settings.json sets "vim_mode": true).
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
# Fast key repeat. 2 / 15 is quick but not twitchy; 1 / 10 is the fastest the UI offers.
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# Text substitutions that corrupt code, commit messages and config files.
# Smart quotes in particular silently break shell and JSON snippets.
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false

# ---- Finder ----
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
# Path + status bar: cheap orientation when digging through project trees
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
# Renaming a file extension is routine here; skip the confirmation
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
# Don't litter network volumes and USB drives with .DS_Store files
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true
killall Finder >/dev/null 2>&1 || true

# ---- Dock ----
# Animation timing only — these are no-ops unless you turn on autohide yourself.
defaults write com.apple.dock autohide-time-modifier -float 0.2
defaults write com.apple.dock autohide-delay -float 0
killall Dock >/dev/null 2>&1 || true

# ---- Save / print panels ----
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true
# Save to disk, not iCloud, by default
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

# ---- Screenshots ----
mkdir -p "$HOME/Screenshots"
defaults write com.apple.screencapture location -string "$HOME/Screenshots"
defaults write com.apple.screencapture type -string "png"
killall SystemUIServer >/dev/null 2>&1 || true

# ---- Opt-in: uncomment what you actually want ----
# As of this writing all of these are unset on the current machine, i.e. you are
# running the macOS stock behaviour. Left off so this script reproduces your
# setup rather than imposing one.
#
# Dock autohide
# defaults write com.apple.dock autohide -bool true
# Don't reorder Spaces by recent use (keeps window muscle memory stable)
# defaults write com.apple.dock mru-spaces -bool false
# Hide recently-used apps in the Dock
# defaults write com.apple.dock show-recents -bool false
# Show hidden files in Finder (cmd-shift-. toggles this ad hoc anyway)
# defaults write com.apple.finder AppleShowAllFiles -bool true
# Default Finder to list view (icnv | clmv | Flwv | Nlsv)
# defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
# Search the current folder rather than the whole Mac
# defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
# Sort folders above files
# defaults write com.apple.finder _FXSortFoldersFirst -bool true
# Tap to click
# defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
# defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
# defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
# Drop the drop-shadow on window screenshots
# defaults write com.apple.screencapture disable-shadow -bool true

echo "macOS defaults applied. Some changes need a logout/restart to fully apply."
