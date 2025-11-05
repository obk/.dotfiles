#!/bin/bash

# Exit immediately if any command fails
set -e

print_msg() {
    printf "\n\033[1;34m%s\033[0m\n" "$1"
}

# Function to get user confirmation
get_confirmation() {
    local prompt=$1
    local response
    printf "%s (y/N) " "$prompt"
    read -r response
    [[ "$response" =~ ^[Yy]$ ]]
}

# Get current directory
REPO_DIR=$(pwd)

# 1. Replace .bashrc
if [ -f "$REPO_DIR/.bashrc" ]; then
    print_msg "Updating .bashrc..."
    rm -f "$HOME/.bashrc"
    ln -sf "$REPO_DIR/.bashrc" "$HOME/.bashrc"
else
    print_msg "No .bashrc found in repository, skipping..."
fi

# 2. Symlink contents of .config directory
if [ -d "$REPO_DIR/.config" ]; then
    print_msg "Symlinking .config contents..."
    mkdir -p "$HOME/.config"
    for item in "$REPO_DIR/.config"/*; do
        [ -e "$item" ] || continue  # Handle empty directory
        item_name=$(basename "$item")
        # Remove existing item to avoid conflicts
        rm -rf "$HOME/.config/$item_name"
        ln -s "$item" "$HOME/.config/$item_name"
        print_msg "Linked: $item_name"
    done
else
    print_msg "No .config directory found in repository, skipping..."
fi


# 3. Snap install
if get_confirmation "Run snap install script?"; then
    sudo snap install discord
    sudo snap install spotify
    sudo snap install tailscale
    sudo snap install code --classic
    sudo snap install ghostty --classic
else
    print_msg "Skipping snap install..."
fi

print_msg "Dotfiles installation complete!"