#!/usr/bin/env bash

# Exit on error, unset variable, or failed pipe
set -euo pipefail

usage() {
    cat <<EOF
Usage: ./mac.sh [-y|--yes] [-e|--export] [-h|--help]

macOS installer. On Linux use ./linux.sh, on Windows ./windows.ps1.

  -y, --yes     answer yes to every prompt (non-interactive)
  -e, --export  copy live configs and package lists back into the repo
  -h, --help    show this help
EOF
}

ASSUME_YES=0
EXPORT=0
for arg in "$@"; do
    case "$arg" in
        -y|--yes) ASSUME_YES=1 ;;
        -e|--export) EXPORT=1 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $arg" >&2; usage >&2; exit 1 ;;
    esac
done

print_msg() {
    printf "\n\033[1;34m%s\033[0m\n" "$1"
}

print_info() {
    printf "    %s\n" "$1"
}

# Ask the user a yes/no question (default: no)
get_confirmation() {
    local prompt=$1
    local response
    [ "$ASSUME_YES" -eq 1 ] && return 0
    printf "%s (y/N) " "$prompt"
    read -r response
    [[ "$response" =~ ^[Yy]$ ]]
}

if [ "$(uname -s)" != "Darwin" ]; then
    echo "mac.sh is the macOS installer. On Linux run ./linux.sh instead." >&2
    exit 1
fi

# Directory containing this script (works from any working directory)
REPO_DIR=$(cd "$(dirname "$0")" && pwd)
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

# Print "repo path<TAB>target path" for every config file this repo manages.
config_pairs() {
    printf '%s\t%s\n' "macos/zshrc" "$HOME/.zshrc"
    # .config/claude/settings.json is merged, not copied (merge_claude_settings)
    (cd "$REPO_DIR" && find .config .ssh -type f ! -name .DS_Store ! -path .config/claude/settings.json | sort) |
        while IFS= read -r rel; do
            printf '%s\t%s\n' "$rel" "$HOME/$rel"
        done
}

# Earlier versions symlinked whole directories (e.g. ~/.config/fish) into the
# repo. Remove those links so real files get copied in their place.
remove_old_links() {
    local path target
    for path in "$HOME/.zshrc" "$HOME/.config"/*; do
        [ -L "$path" ] || continue
        target=$(readlink "$path")
        if [[ "$target" == "$REPO_DIR"/* ]] || [ ! -e "$path" ]; then
            rm -f "$path"
            print_info "unlink  $path"
        fi
    done
}

# Copy $1 (repo path) to $2, backing up anything different that's already there.
# Safe to re-run: identical files are left alone.
install_file() {
    local src="$REPO_DIR/$1" dest=$2 backup
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        if [ ! -L "$dest" ] && cmp -s "$src" "$dest"; then
            print_info "ok      $dest"
            return
        fi
        backup="$BACKUP_DIR/${dest#"$HOME"/}"
        mkdir -p "$(dirname "$backup")"
        mv "$dest" "$backup"
        print_info "backup  $dest -> $backup"
    fi
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    print_info "copy    $1 -> $dest"
}

# Copy the live file $2 back over $1 (repo path) if it changed.
export_file() {
    local repo="$REPO_DIR/$1" live=$2
    if [ ! -f "$live" ]; then
        print_info "missing $live"
        return
    fi
    cmp -s "$live" "$repo" && return
    cp "$live" "$repo"
    print_info "updated $1"
}

# Claude Code lives in ~/.config/claude instead of ~/.claude: fish and zsh set
# CLAUDE_CONFIG_DIR to it once it exists. Move an existing ~/.claude and
# ~/.claude.json there once, so the login, history and plugins come along.
# Returns 1 when the move had to wait (Claude Code running), so the settings
# merge doesn't create an empty ~/.config/claude that the shells would switch to.
CLAUDE_DIR="$HOME/.config/claude"

migrate_claude_dir() {
    [ -d "$HOME/.claude" ] || [ -f "$HOME/.claude.json" ] || return 0
    if [ -e "$CLAUDE_DIR" ]; then
        print_info "skip    ~/.claude and ~/.claude.json ($CLAUDE_DIR already exists; merge or delete them by hand)"
        return 0
    fi
    if pgrep -x claude > /dev/null; then
        print_info "wait    ~/.claude (Claude Code is running; quit it and re-run)"
        return 1
    fi
    mkdir -p "$HOME/.config"
    if [ -d "$HOME/.claude" ]; then mv "$HOME/.claude" "$CLAUDE_DIR"; else mkdir "$CLAUDE_DIR"; fi
    if [ -f "$HOME/.claude.json" ]; then mv "$HOME/.claude.json" "$CLAUDE_DIR/.claude.json"; fi
    print_info "move    ~/.claude, ~/.claude.json -> $CLAUDE_DIR"
}

# Claude Code keeps one settings.json that mixes shared preferences with
# machine-only keys (hooks, auto mode). Merge the repo's keys into it
# instead of replacing the file, so this machine's own keys are kept.
CLAUDE_SETTINGS="$CLAUDE_DIR/settings.json"

merge_claude_settings() {
    local repo="$REPO_DIR/.config/claude/settings.json" merged backup status=0
    if ! command -v python3 &> /dev/null; then
        print_info "skip    $CLAUDE_SETTINGS (needs python3)"
        return
    fi
    # exit 3: nothing to change
    merged=$(python3 - "$repo" "$CLAUDE_SETTINGS" <<'EOF'
import json, os, sys
repo, live = sys.argv[1], sys.argv[2]
shared = json.load(open(repo))
cur = json.load(open(live)) if os.path.exists(live) else {}
merged = dict(cur)
for key, value in shared.items():
    if isinstance(value, dict) and isinstance(cur.get(key), dict):
        merged[key] = {**cur[key], **value}
    else:
        merged[key] = value
if merged == cur:
    sys.exit(3)
print(json.dumps(merged, indent=2, ensure_ascii=False))
EOF
    ) || status=$?
    case $status in
        0) ;;
        3) print_info "ok      $CLAUDE_SETTINGS"; return ;;
        *) print_info "skip    $CLAUDE_SETTINGS (couldn't read it as JSON)"; return ;;
    esac
    if [ -f "$CLAUDE_SETTINGS" ]; then
        backup="$BACKUP_DIR/.config/claude/settings.json"
        mkdir -p "$(dirname "$backup")"
        cp "$CLAUDE_SETTINGS" "$backup"
        print_info "backup  $CLAUDE_SETTINGS -> $backup"
    fi
    mkdir -p "$(dirname "$CLAUDE_SETTINGS")"
    printf '%s\n' "$merged" > "$CLAUDE_SETTINGS"
    print_info "merge   .config/claude/settings.json -> $CLAUDE_SETTINGS"
}

# Fonts ship with the repo (fonts/), so every machine gets the same versions.
install_fonts() {
    local dest="$HOME/Library/Fonts" changed=0 font
    mkdir -p "$dest"
    for font in "$REPO_DIR"/fonts/*/*.ttf; do
        cmp -s "$font" "$dest/${font##*/}" && continue
        cp "$font" "$dest/"
        changed=1
    done
    if [ "$changed" -eq 0 ]; then
        print_info "ok      $dest"
        return
    fi
    print_info "fonts   fonts/ -> $dest"
}

# Commits are signed with user.signingKey (.config/git/config). git verifies
# signatures against gpg.ssh.allowedSignersFile, so list that key there.
# Other entries in the file are kept.
add_allowed_signer() {
    local config="$REPO_DIR/.config/git/config" key file email line
    key=$(git config -f "$config" --path user.signingKey)
    file=$(git config -f "$config" --path gpg.ssh.allowedSignersFile)
    email=$(git config -f "$config" user.email)
    if [ ! -f "$key" ]; then
        print_info "skip    $file (no $key on this machine yet)"
        return
    fi
    line="$email $(cut -d' ' -f1,2 "$key")"
    if [ -f "$file" ] && grep -qxF "$line" "$file"; then
        print_info "ok      $file"
        return
    fi
    printf '%s\n' "$line" >> "$file"
    print_info "signer  $email -> $file"
}

# Copy the current values of the repo's keys from the live settings back into the repo.
export_claude_settings() {
    if [ ! -f "$CLAUDE_SETTINGS" ]; then
        print_info "missing $CLAUDE_SETTINGS"
        return
    fi
    command -v python3 &> /dev/null || { print_info "skip    .config/claude/settings.json (needs python3)"; return; }
    python3 - "$REPO_DIR/.config/claude/settings.json" "$CLAUDE_SETTINGS" <<'EOF'
import json, sys
repo, live = sys.argv[1], sys.argv[2]
shared, cur = json.load(open(repo)), json.load(open(live))
new = {key: cur[key] for key in shared if key in cur}
if new != shared:
    with open(repo, "w") as f:
        json.dump(new, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print("    updated .config/claude/settings.json")
EOF
}

# --export: pull changes from this machine into the repo, then stop
if [ "$EXPORT" -eq 1 ]; then
    print_msg "Copying live configs back into the repo..."
    config_pairs | while IFS=$'\t' read -r rel dest; do export_file "$rel" "$dest"; done
    export_claude_settings

    if command -v brew &> /dev/null; then
        print_msg "Updating macos/Brewfile..."
        brew bundle dump --force --tap --formula --cask --file="$REPO_DIR/macos/Brewfile"
    fi

    print_msg "Changes in the repo (review with git diff, then commit):"
    git -C "$REPO_DIR" status --short
    exit 0
fi

# 1. Copy configs (~/.zshrc, ~/.config/*, Claude Code settings) and fonts
print_msg "Copying configs..."
[ -d "$HOME/.ssh" ] || mkdir -m 700 "$HOME/.ssh"  # ssh refuses a ~/.ssh others can write to
remove_old_links
config_pairs | while IFS=$'\t' read -r rel dest; do install_file "$rel" "$dest"; done
if migrate_claude_dir; then merge_claude_settings; fi
install_fonts
add_allowed_signer
[ -d "$BACKUP_DIR" ] && print_info "replaced files were backed up to $BACKUP_DIR"

# 2. Install Homebrew
if ! command -v brew &> /dev/null; then
    print_msg "Installing Homebrew..."
    if [ "$ASSUME_YES" -eq 1 ]; then export NONINTERACTIVE=1; fi
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH (ARM, then Intel)
    if [ -x /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x /usr/local/bin/brew ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
else
    print_msg "Homebrew already installed, skipping..."
fi

# 3. Install Brew packages
if [ -f "$REPO_DIR/macos/Brewfile" ]; then
    print_msg "Found Brewfile"
    if get_confirmation "Install Brew packages?"; then
        print_msg "Installing Brew packages..."
        brew bundle --file="$REPO_DIR/macos/Brewfile"
    else
        print_msg "Skipping Brew packages installation..."
    fi
else
    print_msg "No macos/Brewfile found in repository, skipping..."
fi

# Claude Code: official installer, into ~/.local/bin (no sudo); it keeps itself updated
if ! command -v claude &> /dev/null && [ ! -x "$HOME/.local/bin/claude" ]; then
    if get_confirmation "Install Claude Code (curl https://claude.ai/install.sh)?"; then
        print_msg "Installing Claude Code..."
        curl -fsSL https://claude.ai/install.sh | bash || print_info "Claude Code install failed, skipping"
    else
        print_msg "Skipping Claude Code..."
    fi
else
    print_msg "Claude Code already installed, skipping..."
fi

# 4. Set fish as the default shell
if FISH_PATH=$(command -v fish); then
    if [ "${SHELL:-}" = "$FISH_PATH" ]; then
        print_msg "fish is already the default shell, skipping..."
    elif get_confirmation "Set fish ($FISH_PATH) as the default shell?"; then
        if ! grep -qx "$FISH_PATH" /etc/shells; then
            print_msg "Adding $FISH_PATH to /etc/shells..."
            echo "$FISH_PATH" | sudo tee -a /etc/shells > /dev/null
        fi
        chsh -s "$FISH_PATH"
    else
        print_msg "Skipping default shell change..."
    fi
else
    print_msg "fish not found, skipping default shell change..."
fi

# 5. macOS defaults script
if [ -f "$REPO_DIR/macos/defaults.sh" ]; then
    print_msg "Found macos/defaults.sh"
    if get_confirmation "Apply macOS defaults (macos/defaults.sh)?"; then
        print_msg "Applying macOS defaults..."
        # Run with its own bash shebang (not sourced) so its sudo keep-alive tracks the right PID
        env REPO_DIR="$REPO_DIR" bash "$REPO_DIR/macos/defaults.sh"
    else
        print_msg "Skipping macOS defaults..."
    fi
else
    print_msg "No macos/defaults.sh found in repository, skipping..."
fi

print_msg "Dotfiles installation complete!"
