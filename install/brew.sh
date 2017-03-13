#!/bin/bash

# Installs Homebrew and some of the common dependencies needed/desired for software development

# Ask for the administrator password upfront
sudo -v

# Check for Homebrew and install it if missing
if test ! $(which brew); then
  echo "Installing Homebrew..."
  ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

brew tap homebrew/versions
brew tap homebrew/dupes
brew tap Goles/battery

# Make sure we’re using the latest Homebrew
brew update

# Upgrade any already-installed formulae
brew upgrade --all

apps=(
    rvm
    pyenv
    nvm
    coreutils
    moreutils
    findutils
    ffmpeg
    fortune
    ponysay
    git
    git-extras
    gnu-sed --with-default-names
    grep --with-default-names
    go
    homebrew/completions/brew-cask-completion
    homebrew/dupes/grep
    homebrew/dupes/openssh
    mtr
    autojump
    imagemagick --with-webp
    python
    source-highlight
    tree
    ffmpeg --with-libvpx
    wget
)

brew install "${apps[@]}"

# Remove outdated versions from the cellar
brew cleanup
