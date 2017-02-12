#!/bin/bash

# Install Caskroom
brew tap caskroom/cask
brew install brew-cask
brew tap caskroom/versions

# Install packages
apps=(
    google-drive
    spectacle
    flux
    dash
    imagealpha
    imageoptim
    iterm2
    atom
    firefox
    google-chrome
    google-chrome-canary
    malwarebytes-anti-malware
    glimmerblocker
    hammerspoon
    kaleidoscope
    macdown
    screenflow
    spotify
    slack
    tower
    transmit
    elmedia-player
    utorrent
)

brew cask install "${apps[@]}"
