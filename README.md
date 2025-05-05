# macOS Dotfiles

This repository contains my personal dotfiles and an installation script to quickly set up a macOS development environment.

## Features

- **Zsh configuration:**  A customized `.zshrc` file for an enhanced shell experience.
- **Configuration files:**  Includes various configuration files within the `.config` directory.
- **Homebrew:** Leverages Homebrew for easy installation and management of packages.
- **Brew Bundle:**  Uses Brew Bundle to manage and install packages from a `Brewfile`.
- **System Preferences:**  Optionally configures macOS system preferences, such as Dock behavior and hidden file visibility.

## Prerequisites

- **Zsh:** This is the default shell in modern macOS versions.
- **Xcode Command Line Tools:** Install these with `xcode-select --install`.
- **Git:** Required for cloning the repository.

## Installation

1. **Clone the repository:** 
   ```bash
   git clone https://github.com/obk/.dotfiles
   ```

2. **Navigate to the directory:**
   ```bash
   cd .dotfiles
   ```

3. **Make the installation script executable:**
   ```bash
   chmod +x install.sh
   ```

4. **Run the installation script:**
   ```bash
    ./install.sh
   ```
   - The script will prompt you to confirm the installation of Brew packages from the `Brewfile`.
   - The script will prompt you to confirm the change macOS system preferences during the installation process.

**Note:** The installation script will overwrite existing `.zshrc` and `.config` files. Please back up any important files before running the script.

## Post-Installation

- Restart your terminal or run `exec zsh` to load the new Zsh configuration.

## Customization

Feel free to fork this repository and modify the dotfiles to suit your own preferences.

## Disclaimer

This repository is primarily for personal use. While you are welcome to use and adapt the dotfiles, I may not be able to provide extensive support or accept pull requests.
