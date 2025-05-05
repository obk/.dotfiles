#!/bin/zsh

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

# 1. Replace .zshrc
if [ -f "$REPO_DIR/.zshrc" ]; then
    print_msg "Updating .zshrc..."
    rm -f "$HOME/.zshrc"
    ln -sf "$REPO_DIR/.zshrc" "$HOME/.zshrc"
else
    print_msg "No .zshrc found in repository, skipping..."
fi

if [ -f "$REPO_DIR/.gitconfig" ]; then
    print_msg "Updating .gitconfig..."
    rm -f "$HOME/.gitconfig"
    ln -sf "$REPO_DIR/.gitconfig" "$HOME/.gitconfig"
else
    print_msg "No .gitconfig found in repository, skipping..."
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

# 3. Install Homebrew if not exists
if ! command -v brew &> /dev/null; then
    print_msg "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH for ARM Macs
    if [ -f /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    # For Intel Macs
    elif [ -f /usr/local/bin/brew ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
else
    print_msg "Homebrew already installed, skipping..."
fi

# 4. Install Brew packages from backup (with confirmation)
if [ -f "$REPO_DIR/Brewfile" ]; then
    print_msg "Found Brewfile"
    if get_confirmation "Install Brew packages?"; then
        print_msg "Installing Brew packages..."
        brew bundle --file="$REPO_DIR/Brewfile"
    else
        print_msg "Skipping Brew packages installation..."
    fi
else
    print_msg "No Brewfile found in repository, skipping..."
fi

# 5. .macos script
if [ -f "$REPO_DIR/.macos" ]; then
    print_msg "Found .macos script"
    if get_confirmation "Run .macos script?"; then
        print_msg "Running .macos script..."
        source "$REPO_DIR/.macos"
    else
        print_msg "Skipping .macos script..."
    fi
else
    print_msg "No .macos script found in repository, skipping..."
fi
print_msg "Dotfiles installation complete!"
