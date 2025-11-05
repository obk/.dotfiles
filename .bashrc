eval "$(oh-my-posh init zsh --config ~/.config/oh-my-posh/obk.toml)"

alias vi='nvim'
alias vim='vnim'
alias cd..='cd ..'
alias gp='git push'
alias gl='git pull'
alias gcm='git commit -m'
alias ll='ls -l --color=auto'
alias lal='ls -a -l --color=auto'
alias au='sudo apt update && sudo apt full-upgrade -y && sudo apt autoremove -y'
alias ou='ollama list | tail -n +2 | awk "{print \$1}" | xargs -I {} ollama pull {}'