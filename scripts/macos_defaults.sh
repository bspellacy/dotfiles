#!/usr/bin/env bash
set -euo pipefail

# macOS defaults. Safe to re-run.
# Revert any single setting with:  defaults delete <domain> <key>
#
# Only settings with a concrete development justification are enabled below.
# Taste-based tweaks are listed, commented out, at the bottom — uncomment the
# ones you want rather than discovering them on a new machine.

# ---- Keyboard ----
# Caps Lock -> Escape is NOT a `defaults` setting: it's a hidutil key remap that
# resets on reboot, so it lives in a launch agent instead. See
# config/launchd/com.brennan.dotfiles.capslock-escape.plist.
#
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

# ---- Keyboard shortcuts (symbolic hotkeys) ----
# cmd-d toggles Do Not Disturb. macOS ships an unassigned shortcut for this
# (System Settings > Keyboard > Keyboard Shortcuts > Mission Control > "Do Not
# Disturb"); it's symbolic hotkey 175. Assigning it here beats going through
# Shortcuts.app + a hotkey daemon: no extra dependency, no accessibility
# permission, and it's the same slot the UI writes to.
#
# parameters = (ASCII of the key, virtual keycode, modifier mask)
#   100     = 'd'
#   2       = kVK_ANSI_D
#   1048576 = 0x100000, NSEventModifierFlagCommand
#
# NOTE: this is a system-wide hotkey, so it WINS over any app's own cmd-d —
# Chrome's Add Bookmark, Finder's Duplicate, "Don't Save" in save sheets. To
# use a different combo, change `parameters` (e.g. cmd-shift-d is
# 1048576 + 131072 = 1179648). To remove it entirely:
#   defaults delete com.apple.symbolichotkeys AppleSymbolicHotKeys 175
# followed by the activateSettings call below (or a logout).
#
# -dict-add merges into AppleSymbolicHotKeys rather than replacing the whole
# dict, so every other shortcut macOS has recorded survives.
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 175 '
<dict>
  <key>enabled</key><true/>
  <key>value</key>
  <dict>
    <key>type</key><string>standard</string>
    <key>parameters</key>
    <array>
      <integer>100</integer>
      <integer>2</integer>
      <integer>1048576</integer>
    </array>
  </dict>
</dict>'
# Reload the hotkey table so the binding works without logging out.
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u \
  >/dev/null 2>&1 || true

# ---- Finder ----
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
# Path + status bar: cheap orientation when digging through project trees
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
# Renaming a file extension is routine here; skip the confirmation
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
# Show hidden files (.git, .env, ...). cmd-shift-. still toggles ad hoc.
defaults write com.apple.finder AppleShowAllFiles -bool true
# Open new windows in list view (icnv | clmv | Flwv | Nlsv).
# Only affects folders with no remembered view of their own.
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
# Search the current folder, not the whole Mac ("SCev" = This Mac)
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
# Don't litter network volumes and USB drives with .DS_Store files
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true
killall Finder >/dev/null 2>&1 || true

# ---- Dock ----
defaults write com.apple.dock autohide -bool true
# Reveal instantly and animate quickly (these only apply when autohide is on)
defaults write com.apple.dock autohide-time-modifier -float 0.2
defaults write com.apple.dock autohide-delay -float 0
# Keep Spaces in a fixed order so ctrl+number/arrow stays predictable
defaults write com.apple.dock mru-spaces -bool false
# No recent-apps section, so pinned icons keep stable screen positions
defaults write com.apple.dock show-recents -bool false
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

echo "macOS defaults applied. Some changes need a logout/restart to fully apply."
