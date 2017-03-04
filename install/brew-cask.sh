#!/bin/bash

# Install Caskroom
brew tap caskroom/cask
brew tap caskroom/versions

# Install packages
declare -a apps=(
  atom
  flux
  dash
  iterm2
  atom
  firefox
  google-chrome
  malwarebytes-anti-malware
  spotify
  slack
  vlc
  bittorrent
)

for app in ${apps[@]}; do
  echo "Installing for $app..."
  brew cask install $app
done
