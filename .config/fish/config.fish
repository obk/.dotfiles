fish_add_path $HOME/.bin $HOME/.local/bin

set -gx EDITOR 'zed --wait'
set -gx VISUAL $EDITOR

if test -x /opt/homebrew/bin/brew
    /opt/homebrew/bin/brew shellenv | source
else if test -x /usr/local/bin/brew
    /usr/local/bin/brew shellenv | source
end

if status is-interactive
    oh-my-posh init fish --config ~/.config/oh-my-posh/obk.toml | source

    alias cd..='cd ..'
    alias gp='git push'
    alias gl='git pull'
    alias gcm='git commit -m'

    # common typos
    alias sl='ls'
    alias gti='git'
    alias exti='exit'
    alias grpe='grep'
    alias celar='clear'
    alias claer='clear'
    alias clera='clear'

    switch (uname)
        case Darwin
            alias ll='ls -lG'
            alias lal='ls -alG'
            alias mu='sudo softwareupdate -i -a'
            alias bf='brew update && brew upgrade && brew autoremove && brew cleanup --prune=all && brew doctor'
        case Linux
            # GNU ls: -G hides the group column, color is --color
            alias ll='ls -l --color=auto'
            alias lal='ls -al --color=auto'
            alias mu='sudo dnf upgrade --refresh'
    end

    # eza: ls with icons and git status, when installed
    if type -q eza
        alias ll='eza -l --icons --git'
        alias lal='eza -la --icons --git'
    end
    # dust: du as a readable tree, when installed (`command du` still runs the real one)
    if type -q dust
        alias du='dust'
    end
end
