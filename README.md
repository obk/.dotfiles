# obk's dotfiles

this repository contains my personal dotfiles and setup scripts for macos, linux (fedora) and windows.

| os | installer | package manager | package list |
| :--- | :--- | :--- | :--- |
| macos | `mac.sh` | homebrew | `macos/Brewfile` |
| linux | `linux.sh` | dnf (fedora) | `linux/packages.txt` |
| windows | `windows.ps1` | scoop (+ winget for zed) | `windows/packages/*.txt` |

## how it works

configs are **copied**, not symlinked, so the repo can be moved or deleted without breaking anything.

```sh
./mac.sh            # new mac: copy configs, install packages
./mac.sh --export   # after changing a config: copy it back into the repo
./linux.sh      # new linux pc
./linux.sh -e   # after changing a config
```
```powershell
./windows.ps1           # new windows pc
./windows.ps1 -Export   # after changing a config
```

- **install** skips files that already match. anything different is moved to `~/.dotfiles-backup/<timestamp>/` first, never deleted.
- **export** copies every managed config that changed on this machine back into the repo, refreshes the package lists (`brew bundle dump` / scoop) and shows `git status`. on linux `linux/packages.txt` is kept by hand (dnf can't tell your picks from the base install); export lists anything in it that's no longer installed. review with `git diff`, then commit.
- export only updates files the repo already has. to start tracking a new config, copy it into the repo once by hand (anything under `.config/` is picked up automatically on macos and linux; on windows add it to `$Files` in `windows.ps1`).

## layout

```
.dotfiles/
├── mac.sh                # macos installer (homebrew)
├── linux.sh              # linux installer (dnf on fedora)
├── windows.ps1           # windows installer (scoop)
├── .config/              # mirrors ~/.config
│   ├── btop/             # btop.conf, TTY theme: uses the terminal's colors
│   ├── fish/
│   ├── fontconfig/       # lilex nerd font mono as the default monospace (linux)
│   ├── gh/               # config.yml only (ssh); hosts.yml holds the login token and is git-ignored
│   ├── ghostty/          # config, tabs.css (macos + linux)
│   ├── git/              # shared by all three; ssh-signed commits and tags
│   ├── herdr/            # shared by all three
│   ├── oh-my-posh/       # shared by all three
│   └── zed/              # shared by all three (windows: %APPDATA%\Zed)
├── .ssh/
│   └── config            # ssh host aliases (home server on the lan); no keys
├── .claude/
│   └── settings.json     # shared claude code preferences, merged into ~/.claude/settings.json
├── macos/
│   ├── Brewfile
│   ├── defaults.sh       # system preferences
│   └── zshrc
├── linux/
│   ├── fedora-setup.sh   # upgrade, firmware, codecs, nvidia driver
│   ├── packages.txt      # dnf packages
│   └── gnome.sh          # gnome settings
├── windows/
│   ├── packages/         # scoop-buckets.txt, scoop-apps.txt
│   ├── powershell/
│   └── windows-terminal/
├── fonts/                # FiraCode and Lilex nerd fonts (+ licenses), installed by every installer
└── wallpapers/
```

zed is the default editor everywhere (`EDITOR='zed --wait'` in fish, zsh and the powershell profile). its extensions are listed in `auto_install_extensions` in `.config/zed/settings.json`; zed installs any that are missing on launch.

ghostty, windows terminal and zed use **[catppuccin](https://catppuccin.com)**: mocha (dark) and latte (light), following the system light/dark mode. the font everywhere is **lilex nerd font** (ibm plex mono with ligatures); it and firacode nerd font ship in `fonts/` (normal and mono, all weights) and every installer installs them for the current user: `~/.local/share/fonts/dotfiles` on linux, `~/Library/Fonts` on macos, the per-user fonts folder on windows. no font packages needed.

| app | where the themes come from | setting |
| :--- | :--- | :--- |
| ghostty | built in | `theme = dark:…,light:…` |
| zed | the `catppuccin` extension, auto-installed via `auto_install_extensions` | `"theme": { "mode": "system", … }` |
| windows terminal | `schemes` in `windows/windows-terminal/settings.json`, copied from ghostty's built-in files | `"colorScheme": { "dark": …, "light": … }` |

claude code uses its own `auto` theme (follows the terminal's light/dark background) rather than the terminal palette.

### commit signing (`.config/git/config`)

commits and tags are signed with an ssh key, `~/.ssh/obk.pub` (`user.signingKey`). the key itself isn't in the repo; copy it (and its private half) to `~/.ssh/` on a new machine and add it to github as a **signing key**.

git checks signatures (`git log --show-signature`) against `~/.ssh/allowed_signers`. every installer adds `<email> <key>` for the signing key to that file, keeping any other entries; if the key isn't there yet the step is skipped, so re-run the installer once it is.

### claude code (`.claude/settings.json`)

claude code keeps everything in one `~/.claude/settings.json`, mixing preferences with keys that only make sense on one machine. so this file is **merged**, not copied: install writes the repo's keys into the live file and keeps every other key (a changed file is backed up first, like the rest). export copies the current values of those same keys back, so a setting changed on one machine (say, the model) ends up in the repo.

- **shared:** `env` (subagent model), `theme` (`auto`: follows the terminal's light/dark background), `modelSettings` and the notification settings.
- **not shared:** plugins (`enabledPlugins`, `extraKnownMarketplaces`, `pluginConfigs`), `hooks` (local script paths), `autoMode` and ui state, plus everything else in `~/.claude` (login, history, sessions, caches, installed plugin files). to share another key, add it to `.claude/settings.json` once; export keeps it up to date from then on.
- needs `python3` on macos and linux (macos gets it with the xcode command line tools); without it the step is skipped.

## installation (macos)

1. install `xcode-select --install` 
    - a window will pop up asking if you want to install the command line developer tools
    - click install
    - this will give you `git`
2.  clone the repository:
    ```sh
    git clone https://github.com/obk/.dotfiles
    ```
3.  navigate to the directory:
    ```sh
    cd .dotfiles
    ```
4.  run the installation script:
    ```sh
    ./mac.sh
    ```

the script can be run from any directory and is safe to re-run.

**options:**

| flag | description |
| :--- | :--- |
| `-y`, `--yes` | answer yes to every prompt (non-interactive). this includes changing your default shell. |
| `-e`, `--export` | copy live configs and package lists back into the repo. |
| `-h`, `--help` | show usage. |

### what the installer does

  * **copy configs:** `macos/zshrc` → `~/.zshrc` and every file in `.config` → `~/.config`; `.claude/settings.json` is merged into `~/.claude/settings.json`.
  * **backups:** anything different that already exists is moved to `~/.dotfiles-backup/<timestamp>/` first. symlinks left by older versions of this repo are replaced with real files.
  * **commit signing:** adds the signing key to `~/.ssh/allowed_signers` (see [commit signing](#commit-signing-configgitconfig)).
  * **install homebrew:** installs it if missing (supporting both arm and intel macs).
  * **bundle packages:** prompts to install `macos/Brewfile` via `brew bundle`.
  * **claude code:** prompts to install it with its official installer (`curl https://claude.ai/install.sh`, into `~/.local/bin`) if it isn't installed yet.
  * **default shell:** if fish is installed, prompts to set it as your default shell (adds it to `/etc/shells` if needed, then runs `chsh`).
  * **system defaults:** prompts to run `macos/defaults.sh` to apply system-wide preferences.

## installation (linux)

made for **fedora** (workstation, gnome). on other distros it still copies the configs and skips dnf and the gnome settings.

```sh
sudo dnf install -y git   # if missing
git clone https://github.com/obk/.dotfiles ~/.dotfiles
cd ~/.dotfiles
./linux.sh
```

same flags as `mac.sh` (`-y`, `-e`, `-h`).

### what the installer does

  * **copy configs:** every file in `.config` → `~/.config`; `.claude/settings.json` is merged into `~/.claude/settings.json`. no zshrc; bash stays as the fallback shell.
  * **backups:** same as macos, to `~/.dotfiles-backup/<timestamp>/`.
  * **commit signing:** same as macos, adds the signing key to `~/.ssh/allowed_signers`.
  * **system setup:** prompts to run `linux/fedora-setup.sh` (see below).
  * **repos:** prompts, then adds the repos the package list needs (skipping any already there): [rpm fusion](https://rpmfusion.org) (steam, unrar), [terra](https://terra.fyralabs.com) (ghostty, zed, signal, discord, spotify, heroic), copr `imput/helium` (helium browser) and tailscale's repo. to add a repo, edit `add_fedora_repos` in `linux.sh`.
  * **dnf packages:** installs whatever in `linux/packages.txt` isn't installed yet (a name no repo has is skipped and listed at the end instead of failing the whole install), then enables `tailscaled`. no flatpaks.
  * **oh-my-posh:** no fedora package, so the latest release binary is downloaded to `~/.local/bin`.
  * **claude code and herdr:** prompts to install each with its official installer (`claude.ai/install.sh`, `herdr.dev/install.sh`, into `~/.local/bin`) if it isn't installed yet.
  * **default shell:** prompts to set fish as your default shell.
  * **gnome settings:** on gnome, prompts to run `linux/gnome.sh`.

the macos-only brewfile apps without a linux build (keka, iina, stats, aldente, orbstack) are left out; podman, file roller and the gnome apps cover those.

## installation (windows)

needs `git` first (`winget install --id Git.Git -e`). works from the stock windows powershell 5.1: the installer installs scoop and powershell 7 if missing and re-runs itself with `pwsh`.

```powershell
git clone https://github.com/obk/.dotfiles $HOME\.dotfiles
cd $HOME\.dotfiles
./windows.ps1 -DryRun   # preview
./windows.ps1
```

| flag | description |
| :--- | :--- |
| `-DryRun` | show what would happen, change nothing. works with `-Export` too. |
| `-SkipPackages` | only copy configs. |
| `-Export` | copy live configs and package lists back into the repo. |

| repo path | copied to |
| :--- | :--- |
| `.config/git/config`, `.config/git/ignore` | `~\.config\git\` |
| `.config/oh-my-posh/obk.toml` | `~\.config\oh-my-posh\` |
| `.config/zed/settings.json` | `%APPDATA%\Zed\` |
| `.config/gh/config.yml` | `%APPDATA%\GitHub CLI\` |
| `.config/herdr/config.toml`, `config-gpui.local.toml` | `~\.config\herdr\` |
| `.ssh/config` | `~\.ssh\` |
| `.claude/settings.json` | merged into `~\.claude\settings.json` |
| signing key from `.config/git/config` | added to `~\.ssh\allowed_signers` |
| `windows/powershell/…profile.ps1` | `$PROFILE` |
| `windows/windows-terminal/settings.json` | `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_…\LocalState\` |

packages: scoop buckets/apps from `windows/packages/`, claude code via its official installer (`claude.ai/install.ps1`), zed via winget (scoop's build warns that zed's auto-updater can install into unintended locations).

-----

## configuration details

### macos preferences (`macos/defaults.sh`)

`macos/defaults.sh` modifies system defaults to improve usability and speed. it requires `sudo` permissions at the start to update system settings.

**key changes:**

  * **finder:**
      * shows all hidden files and file extensions.
      * sets the default search scope to the current folder.
      * defaults to **list view**.
      * shows the full path bar.
  * **dock:**
      * removes all persistent app icons (starts fresh).
      * hides recent applications.
      * sets icon size to 36px.
      * enables auto-hide with **0 second delay** (instant animation).
  * **general ui/ux:**
      * expands save and print panels by default.
      * disables "smart" features: automatic dash/quote substitution and spell correction.
      * screensaver asks for a password immediately (0 delay).
      * screenshots are saved to the desktop as pngs.
  * **wallpaper:** copies `wallpapers/5.png` to `~/Pictures/obk-5.png` (so it survives the repo moving) and sets it as the desktop picture.

### fedora system setup (`linux/fedora-setup.sh`)

system-level setup that isn't a plain package. run by `linux.sh` before the package list, or on its own. safe to re-run.

  * **dnf:** 10 parallel downloads, defaults to yes.
  * **repos:** rpm fusion free + nonfree, fedora's cisco openh264 repo.
  * **upgrade:** `dnf upgrade --refresh`.
  * **firmware:** `fwupdmgr update` (uefi, ssd), amd cpu microcode, mediatek wi-fi/bt firmware.
  * **codecs:** full `ffmpeg` instead of `ffmpeg-free`, the `@multimedia` group, gstreamer and openh264 plugins.
  * **nvidia** (only if an nvidia gpu is found): `akmod-nvidia` with cuda, nvdec video decode (`nvidia-vaapi-driver`) and 32-bit libs for steam. keeps video memory across suspend. with secure boot on, it creates an akmods signing key; on the next boot choose **enroll mok → continue** and type the password you picked.
  * **monitoring:** `lm_sensors`, `fstrim.timer` (ssd trim), `smartd` (drive health).
  * **boot:** disables `NetworkManager-wait-online`.
  * **dual boot:** `LOCAL_RTC=1 ./linux/fedora-setup.sh` keeps the hardware clock in local time so windows and fedora agree.

after a reboot, check the gpu with `nvidia-smi` and video decode with `vainfo`.

### gnome settings (`linux/gnome.sh`)

the linux counterpart of `macos/defaults.sh`. keys a gnome version doesn't have are skipped, not fatal.

  * **windows:** minimize and maximize buttons.
  * **mouse:** flat acceleration profile (no acceleration).
  * **monospace font:** lilex nerd font mono 11 for gnome apps (and `.config/fontconfig/fonts.conf` makes it every app's default monospace).
  * **files (nautilus):** shows hidden files (also in file pickers), defaults to **list view**.
  * **lock screen:** locks as soon as the screen blanks (0 delay).
  * **printing:** no print job history (`cupsctl --no-preserve-job-history`, asks for sudo).
  * **wallpaper:** copies `wallpapers/5.png` to `~/.local/share/backgrounds/` and sets it for light mode, dark mode and the lock screen.

### shell configuration (`.config/fish/config.fish`, `macos/zshrc`)

fish is the primary shell. `macos/zshrc` is kept as a zsh fallback with the same setup. both:

  * add `~/.bin` to `PATH` (fish also adds `~/.local/bin`).
  * load homebrew (arm or intel path, only if present).
  * use `oh-my-posh` for prompt theming (`.config/oh-my-posh/obk.toml`).
  * set zed as `EDITOR`.
  * define the aliases below.

**useful aliases:**

| alias | command | description |
| :--- | :--- | :--- |
| `bf` | `brew update && brew upgrade...` | full homebrew maintenance: updates, upgrades, removes old deps, and cleans up. (macos) |
| `mu` | `sudo softwareupdate -i -a` | install all available macos software updates. on linux: `sudo dnf upgrade --refresh`. |
| `gp` / `gl` / `gcm`| `git push` / `git pull` / `git commit -m ` | git shortcuts. |
| `ll` | `eza -l --icons --git` | list files with icons and git status (falls back to `ls` when eza isn't installed). |
| `lal` | `eza -la --icons --git` | list all files with icons and git status (falls back to `ls` when eza isn't installed). |
| `du` | `dust` | disk usage as a readable tree (falls back to `du`; `command du` runs the original). |
| `cd..` | `cd ..` | go up one directory. |
| `claer` / `clera` / `celar`, `sl`, `gti`, `grpe`, `exti` | `clear`, `ls`, `git`, `grep`, `exit` | common typos still work. |

`bf` is macos-only and `mu` runs dnf on linux. on windows the powershell profile defines `scf` (scoop update + cleanup).
