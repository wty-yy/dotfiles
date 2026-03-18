# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export TERM=xterm-256color
export SHELL=/usr/bin/zsh

if command -v dircolors >/dev/null 2>&1; then
  eval "$(dircolors -p | sed -e 's/DIR 01;34/DIR 01;36/' | dircolors /dev/stdin)"
fi
alias ls='ls --color=auto'
alias tmux='tmux -u'

if [ -d "$HOME/.local/bin" ]; then
  export PATH="$HOME/.local/bin:$PATH"
fi

export EDITOR='vim'

[[ -r "${HOME}/.powerlevel10k/powerlevel10k.zsh-theme" ]] && source "${HOME}/.powerlevel10k/powerlevel10k.zsh-theme"
[[ -f "${HOME}/.p10k.zsh" ]] && source "${HOME}/.p10k.zsh"
[[ -r "${HOME}/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] && source "${HOME}/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh"
[[ -r "${HOME}/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] && source "${HOME}/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
