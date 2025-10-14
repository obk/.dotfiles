eval "$(/opt/homebrew/bin/brew shellenv)"
eval "$(oh-my-posh init zsh --config ~/.config/oh-my-posh/obk.toml)"

alias mu='sudo softwareupdate -i -a'
alias ou='ollama list | tail -n +2 | awk "{print \$1}" | xargs -I {} ollama pull {}'
alias bf='brew update && brew upgrade && brew autoremove && brew cleanup --prune=all && brew doctor'
alias ll='ls -l --color=auto'
alias lal='ls -a -l --color=auto'
alias cd..='cd ..'

export PATH="~/.bin:$PATH"

alias vi='nvim'
alias vim='vnim'
