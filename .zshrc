eval "$(/opt/homebrew/bin/brew shellenv)"
eval "$(oh-my-posh init zsh --config ~/.config/oh-my-posh/obk.toml)"

alias mu='sudo softwareupdate -i -a'
alias bf='brew update && brew upgrade && brew autoremove && brew cleanup --prune=all && brew doctor'
alias ll='ls -l --color=auto'
alias lal='ls -a -l --color=auto'
alias gcm='git commit -m'
alias gpl='git pull'
alias gp='git push'
alias gaa='git add .'
alias gs='git status'
alias gra='git remote add'
alias gi='git init'
alias gc='git clone'
alias gpa='git remote | xargs -L1 -I R git push R'
alias cd..='cd ..'
alias ou='ollama list | tail -n +2 | awk "{print \$1}" | xargs -I {} ollama pull {}'

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/opt/homebrew/Caskroom/miniconda/base/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/opt/homebrew/Caskroom/miniconda/base/etc/profile.d/conda.sh" ]; then
        . "/opt/homebrew/Caskroom/miniconda/base/etc/profile.d/conda.sh"
    else
        export PATH="/opt/homebrew/Caskroom/miniconda/base/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

export PATH="~/.bin:$PATH"

alias vi='nvim'
alias vim='vnim'
