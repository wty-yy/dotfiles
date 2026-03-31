# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export TERM=xterm-256color
export SHELL=/usr/bin/zsh
export HISTFILE="${HOME}/.zsh_history"
export HISTSIZE=100000
export SAVEHIST=100000

setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt EXTENDED_HISTORY

if [ ! -e "${HISTFILE}" ]; then
  touch "${HISTFILE}" 2>/dev/null || true
fi

if command -v dircolors >/dev/null 2>&1; then
  eval "$(dircolors -p | sed -e 's/DIR 01;34/DIR 01;36/' | dircolors /dev/stdin)"
fi
alias ls='ls --color=auto'
alias tmux='tmux -u'

if [ -d "$HOME/.local/bin" ]; then
  export PATH="$HOME/.local/bin:$PATH"
fi

export EDITOR='vim'

function zvm_config() {
  ZVM_INSERT_MODE_CURSOR=$ZVM_CURSOR_BLOCK
  ZVM_NORMAL_MODE_CURSOR=$ZVM_CURSOR_BLOCK
  ZVM_VISUAL_MODE_CURSOR=$ZVM_CURSOR_BLOCK
  ZVM_VISUAL_LINE_MODE_CURSOR=$ZVM_CURSOR_BLOCK
  ZVM_OPPEND_MODE_CURSOR=$ZVM_CURSOR_BLOCK
}

[[ -r "${HOME}/.powerlevel10k/powerlevel10k.zsh-theme" ]] && source "${HOME}/.powerlevel10k/powerlevel10k.zsh-theme"
[[ -f "${HOME}/.p10k.zsh" ]] && source "${HOME}/.p10k.zsh"
[[ -r "${HOME}/.zsh/zsh-vi-mode/zsh-vi-mode.plugin.zsh" ]] && source "${HOME}/.zsh/zsh-vi-mode/zsh-vi-mode.plugin.zsh"
[[ -r "${HOME}/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] && source "${HOME}/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh"
[[ -r "${HOME}/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] && source "${HOME}/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

function proxy_on(){
  MIXED_PORT=7890  # change port 7890 to mixed-port
  export all_proxy=socks5://127.0.0.1:$MIXED_PORT
  export http_proxy=http://127.0.0.1:$MIXED_PORT
  export HTTP_PROXY=http://127.0.0.1:$MIXED_PORT
  export https_proxy=http://127.0.0.1:$MIXED_PORT
  export HTTPS_PROXY=http://127.0.0.1:$MIXED_PORT
  echo -e "Proxy enabled on port $MIXED_PORT - ENV [all_proxy, http_proxy, HTTP_PROXY, https_proxy, HTTPS_PROXY]"
}

function proxy_off(){
  unset all_proxy
  unset http_proxy
  unset HTTP_PROXY
  unset https_proxy
  unset HTTPS_PROXY
  echo -e "Proxy disabled - ENV [all_proxy, http_proxy, HTTP_PROXY, https_proxy, HTTPS_PROXY]"
}
