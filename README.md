# obk's dotfiles

this repository contains my personal dotfiles and setup scripts for macos and linux environments.

## installation

### macos

1.  clone the repository:
    ```sh
    git clone https://github.com/obk/.dotfiles.git
    ```
2.  navigate to the directory:
    ```sh
    cd .dotfiles
    ```
3.  run the installation script:
    ```sh
    ./install-mac.sh
    ```
the script will guide you through:
* symlinking the `.zshrc` and `.config` directory.
* installing homebrew (if not already present).
* installing all applications and tools from the `brewfile` (with confirmation).
* running the `.macos` script to set system defaults (with confirmation).

### linux (debian/ubuntu)

1.  clone the repository:
    ```sh
    git clone https://github.com/obk/.dotfiles.git
    ```
2.  navigate to the directory:
    ```sh
    cd .dotfiles
    ```
3.  run the installation script:
    ```sh
    ./install-linux.sh
    ```
the script will guide you through:
* symlinking the `.bashrc` and `.config` directory.
* installing a set of snap packages (with confirmation).

---

## what's included?

### cross-platform

* **prompt:** configuration for `oh-my-posh`.
* **editor aliases:** `vi` is aliased to `nvim`, and `vim` is aliased to `vnim`.
* **git aliases:**
    * `gp`: `git push`
    * `gl`: `git pull`
    * `gcm`: `git commit -m`
* **navigation & listing aliases:**
    * `cd..`: `cd ..`
    * `ll`: `ls -l --color=auto`
    * `lal`: `ls -a -l --color=auto`
* **ollama:** an alias `ou` to pull updates for all installed ollama models.

### macos specific

* **shell:** configured for `zsh` (`.zshrc`).
* **package management:** includes a `brewfile` that installs a curated list of cli tools, gui applications, and fonts.
* **system defaults:** a comprehensive `.macos` script that:
    * keeps `sudo` privileges alive during script execution.
    * expands save and print panels by default.
    * disables automatic dash and quote substitution.
    * configures finder to show all files, file extensions, and the path bar.
    * sets finder's default view to list view and search scope to the current folder.
    * disables the ".ds_store" file creation on network and usb drives.
    * disables the warning when changing file extensions or emptying the trash.
    * disables the "are you sure you want to open this application?" dialog.
    * configures the dock to autohide instantly, sets the icon size, and removes recent apps and default icons.
    * requires a password immediately after the screensaver starts.
    * prevents time machine from prompting for new backup disks.
* **aliases:**
    * `bf`: updates and cleans up all homebrew packages.
    * `mu`: runs a system software update.

### linux specific

* **shell:** configured for `bash` (`.bashrc`).
* **package management:** the `install-linux.sh` script installs applications via `snap`.
* **aliases:**
    * `au`: updates, upgrades, and autoremoves `apt` packages.