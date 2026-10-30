#!/usr/bin/env bash

# GNOME settings, the linux counterpart of macos/defaults.sh.
# Run by linux.sh (REPO_DIR is passed in), or on its own from the repo.

REPO_DIR="${REPO_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"

# Set a key only if this GNOME version has it, so one renamed key
# doesn't stop the rest from applying.
set_key() {
    if gsettings writable "$1" "$2" &> /dev/null; then
        gsettings set "$1" "$2" "$3"
    else
        echo "    skip    $1 $2 (not available)"
    fi
}

# Show hidden files in Files (nautilus) and in file pickers.
set_key org.gnome.nautilus.preferences show-hidden-files true
set_key org.gtk.gtk4.Settings.FileChooser show-hidden true
set_key org.gtk.Settings.FileChooser show-hidden true

# Default to list view in Files.
set_key org.gnome.nautilus.preferences default-folder-viewer "'list-view'"

# Lock the screen as soon as it blanks (no grace period).
set_key org.gnome.desktop.screensaver lock-enabled true
set_key org.gnome.desktop.screensaver lock-delay 0

# Monospace font (Lilex, shipped in fonts/) for GNOME apps like Text Editor.
set_key org.gnome.desktop.interface monospace-font-name "'Lilex Nerd Font Mono 11'"

# Minimize and maximize buttons on windows.
set_key org.gnome.desktop.wm.preferences button-layout "'appmenu:minimize,maximize,close'"

# No mouse acceleration.
set_key org.gnome.desktop.peripherals.mouse accel-profile "'flat'"

# Don't keep print job history.
if command -v cupsctl &> /dev/null; then
    sudo cupsctl --no-preserve-job-history
fi

# Wallpaper: copy wallpapers/5.png out of the repo so it survives the repo
# being moved or deleted.
WALLPAPER="$HOME/.local/share/backgrounds/obk-5.png"
mkdir -p "$(dirname "$WALLPAPER")"
cp "$REPO_DIR/wallpapers/5.png" "$WALLPAPER"
set_key org.gnome.desktop.background picture-uri "'file://$WALLPAPER'"
set_key org.gnome.desktop.background picture-uri-dark "'file://$WALLPAPER'"
set_key org.gnome.desktop.screensaver picture-uri "'file://$WALLPAPER'"

echo " Some changes need Files to be reopened (nautilus -q)."
