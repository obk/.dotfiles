#!/usr/bin/env bash

# Exit on error, unset variable, or failed pipe
set -euo pipefail

usage() {
    cat <<EOF
Usage: ./linux.sh [-y|--yes] [-e|--export] [-h|--help]

Linux installer (system setup, packages and GNOME settings on Fedora;
configs on any distro).
On macOS use ./mac.sh, on Windows ./windows.ps1.

  -y, --yes     answer yes to every prompt (non-interactive)
  -e, --export  copy live configs back into the repo
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

if [ "$(uname -s)" != "Linux" ]; then
    echo "linux.sh is the Linux installer. On macOS run mac.sh instead." >&2
    exit 1
fi

# Fedora (or a Fedora derivative): packages come from dnf
IS_FEDORA=0
if [ -r /etc/os-release ] && command -v dnf &> /dev/null; then
    # shellcheck disable=SC1091
    if (. /etc/os-release && [[ "${ID:-} ${ID_LIKE:-}" == *fedora* ]]); then IS_FEDORA=1; fi
fi

# Directory containing this script (works from any working directory)
REPO_DIR=$(cd "$(dirname "$0")" && pwd)
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

# Print "repo path<TAB>target path" for every config file this repo manages.
config_pairs() {
    (cd "$REPO_DIR" && find .config .ssh -type f ! -name .DS_Store | sort) |
        while IFS= read -r rel; do
            printf '%s\t%s\n' "$rel" "$HOME/$rel"
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

# Claude Code keeps one ~/.claude/settings.json that mixes shared preferences
# with machine-only keys (hooks, auto mode). Merge the repo's keys into it
# instead of replacing the file, so this machine's own keys are kept.
CLAUDE_SETTINGS="$HOME/.claude/settings.json"

merge_claude_settings() {
    local repo="$REPO_DIR/.claude/settings.json" merged backup status=0
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
        backup="$BACKUP_DIR/.claude/settings.json"
        mkdir -p "$(dirname "$backup")"
        cp "$CLAUDE_SETTINGS" "$backup"
        print_info "backup  $CLAUDE_SETTINGS -> $backup"
    fi
    mkdir -p "$(dirname "$CLAUDE_SETTINGS")"
    printf '%s\n' "$merged" > "$CLAUDE_SETTINGS"
    print_info "merge   .claude/settings.json -> $CLAUDE_SETTINGS"
}

# Fonts ship with the repo (fonts/), so every machine gets the same versions.
install_fonts() {
    local dest="$HOME/.local/share/fonts/dotfiles" changed=0 font
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
    command -v fc-cache &> /dev/null && fc-cache -f "$dest" > /dev/null
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
    command -v python3 &> /dev/null || { print_info "skip    .claude/settings.json (needs python3)"; return; }
    python3 - "$REPO_DIR/.claude/settings.json" "$CLAUDE_SETTINGS" <<'EOF'
import json, sys
repo, live = sys.argv[1], sys.argv[2]
shared, cur = json.load(open(repo)), json.load(open(live))
new = {key: cur[key] for key in shared if key in cur}
if new != shared:
    with open(repo, "w") as f:
        json.dump(new, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print("    updated .claude/settings.json")
EOF
}

# Print the entries of a package list, without comments or blank lines.
read_list() {
    sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e 's/^[[:space:]]*//' "$1" | grep -v '^$' || true
}

# Add the third-party dnf repos linux/packages.txt needs. Skips any already set up.
add_fedora_repos() {
    # copr and config-manager are dnf5 plugins
    rpm -q dnf5-plugins &> /dev/null || sudo dnf install -y dnf5-plugins
    if ! rpm -q rpmfusion-free-release rpmfusion-nonfree-release &> /dev/null; then
        print_info "repo    rpm fusion"
        sudo dnf install -y \
            "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
            "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
    fi
    if ! rpm -q terra-release &> /dev/null; then
        print_info "repo    terra"
        sudo dnf install -y --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release
    fi
    if [ ! -f "/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:imput:helium.repo" ]; then
        print_info "repo    copr imput/helium"
        sudo dnf copr enable -y imput/helium
    fi
    if [ ! -f /etc/yum.repos.d/tailscale.repo ]; then
        print_info "repo    tailscale"
        sudo dnf config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo
    fi
}

# --export: pull changes from this machine into the repo, then stop
if [ "$EXPORT" -eq 1 ]; then
    print_msg "Copying live configs back into the repo..."
    config_pairs | while IFS=$'\t' read -r rel dest; do export_file "$rel" "$dest"; done
    export_claude_settings

    if [ "$IS_FEDORA" -eq 1 ]; then
        # dnf can't tell packages you picked from the base install, so the
        # list is kept by hand. Point out anything in it that's gone.
        print_msg "linux/packages.txt is kept by hand; listed but not installed:"
        read_list "$REPO_DIR/linux/packages.txt" | while IFS= read -r pkg; do
            rpm -q "$pkg" &> /dev/null || print_info "$pkg"
        done
    fi

    print_msg "Changes in the repo (review with git diff, then commit):"
    git -C "$REPO_DIR" status --short
    exit 0
fi

# 1. Copy configs (~/.config/*, Claude Code settings) and fonts
print_msg "Copying configs..."
[ -d "$HOME/.ssh" ] || mkdir -m 700 "$HOME/.ssh"  # ssh refuses a ~/.ssh others can write to
config_pairs | while IFS=$'\t' read -r rel dest; do install_file "$rel" "$dest"; done
merge_claude_settings
install_fonts
add_allowed_signer
[ -d "$BACKUP_DIR" ] && print_info "replaced files were backed up to $BACKUP_DIR"

# 2. System setup: updates, firmware, codecs, nvidia driver (Fedora only)
if [ "$IS_FEDORA" -eq 1 ]; then
    if get_confirmation "Run system setup (linux/fedora-setup.sh: upgrade, firmware, codecs, NVIDIA)?"; then
        print_msg "Running system setup..."
        # Run with its own bash shebang (not sourced) so its sudo keep-alive tracks the right PID
        bash "$REPO_DIR/linux/fedora-setup.sh"
    else
        print_msg "Skipping system setup..."
    fi
fi

# 3. Add repos and install dnf packages (Fedora only)
if [ "$IS_FEDORA" -eq 1 ]; then
    if get_confirmation "Install dnf packages (linux/packages.txt)?"; then
        print_msg "Adding dnf repos..."
        add_fedora_repos
        missing=()
        while IFS= read -r pkg; do
            rpm -q "$pkg" &> /dev/null || missing+=("$pkg")
        done < <(read_list "$REPO_DIR/linux/packages.txt")
        if [ "${#missing[@]}" -gt 0 ]; then
            print_msg "Installing dnf packages: ${missing[*]}"
            # One unknown name shouldn't stop every other package from installing
            sudo dnf install -y --skip-unavailable "${missing[@]}"
            not_installed=()
            for pkg in "${missing[@]}"; do
                rpm -q "$pkg" &> /dev/null || not_installed+=("$pkg")
            done
            if [ "${#not_installed[@]}" -gt 0 ]; then
                print_msg "Not installed (not found in the enabled repos): ${not_installed[*]}"
            fi
        else
            print_msg "All dnf packages already installed, skipping..."
        fi
        if rpm -q tailscale &> /dev/null && ! systemctl is-enabled --quiet tailscaled; then
            print_msg "Enabling tailscaled (log in with: sudo tailscale up)..."
            sudo systemctl enable --now tailscaled
        fi
    else
        print_msg "Skipping dnf packages installation..."
    fi
else
    print_msg "Not Fedora, skipping dnf packages (see linux/packages.txt)..."
fi

# oh-my-posh isn't packaged for Fedora: put the release binary in ~/.local/bin
if ! command -v oh-my-posh &> /dev/null && [ ! -x "$HOME/.local/bin/oh-my-posh" ]; then
    case "$(uname -m)" in
        x86_64) POSH_ARCH=amd64 ;;
        aarch64) POSH_ARCH=arm64 ;;
        *) POSH_ARCH="" ;;
    esac
    if [ -n "$POSH_ARCH" ]; then
        print_msg "Installing oh-my-posh to ~/.local/bin..."
        mkdir -p "$HOME/.local/bin"
        if curl -fsSL -o "$HOME/.local/bin/oh-my-posh" \
            "https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-linux-$POSH_ARCH"; then
            chmod +x "$HOME/.local/bin/oh-my-posh"
        else
            print_info "oh-my-posh download failed, skipping"
        fi
    fi
fi

# Install command $1 with its official script $2 (both put it in ~/.local/bin, no sudo),
# unless it's already there
install_from_script() {
    if command -v "$1" &> /dev/null || [ -x "$HOME/.local/bin/$1" ]; then
        print_msg "$1 already installed, skipping..."
    elif get_confirmation "Install $1 (curl $2)?"; then
        print_msg "Installing $1..."
        curl -fsSL "$2" | bash || print_info "$1 install failed, skipping"
    else
        print_msg "Skipping $1..."
    fi
}
install_from_script claude https://claude.ai/install.sh # Claude Code; keeps itself updated
install_from_script herdr https://herdr.dev/install.sh  # not packaged for Fedora; `herdr update` updates it

# 4. Set fish as the default shell
if FISH_PATH=$(command -v fish); then
    # /usr/sbin is merged into /usr/bin on Fedora; prefer the path /etc/shells lists
    [ -x /usr/bin/fish ] && FISH_PATH=/usr/bin/fish
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

# 5. GNOME settings (linux counterpart of macos/defaults.sh)
if [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]] && command -v gsettings &> /dev/null; then
    if get_confirmation "Apply GNOME settings (linux/gnome.sh)?"; then
        print_msg "Applying GNOME settings..."
        env REPO_DIR="$REPO_DIR" bash "$REPO_DIR/linux/gnome.sh"
    else
        print_msg "Skipping GNOME settings..."
    fi
else
    print_msg "Not running GNOME, skipping linux/gnome.sh..."
fi

print_msg "Dotfiles installation complete!"
