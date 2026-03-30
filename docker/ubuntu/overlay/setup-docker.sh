#!/bin/sh
set -eu

clone_with_retry() {
    repo_url="$1"
    dest_dir="$2"

    if [ -d "${dest_dir}" ]; then
        return 0
    fi

    attempt=1
    while [ "${attempt}" -le 3 ]; do
        if git clone --depth=1 "${repo_url}" "${dest_dir}"; then
            return 0
        fi
        rm -rf "${dest_dir}"
        attempt=$((attempt + 1))
        sleep 2
    done

    echo "failed to clone ${repo_url} after 3 attempts" >&2
    return 1
}

run_with_retry() {
    attempt=1
    while [ "${attempt}" -le 3 ]; do
        if "$@"; then
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 2
    done

    echo "command failed after 3 attempts: $*" >&2
    return 1
}

install -d "${HOME}/.zsh"
clone_with_retry https://github.com/romkatv/powerlevel10k.git "${HOME}/.powerlevel10k"
install -d "${HOME}/.powerlevel10k/gitstatus/usrbin"
run_with_retry env GITSTATUS_CACHE_DIR="${HOME}/.powerlevel10k/gitstatus/usrbin" \
    "${HOME}/.powerlevel10k/gitstatus/install" -f

clone_with_retry https://github.com/zsh-users/zsh-autosuggestions.git "${HOME}/.zsh/zsh-autosuggestions"
clone_with_retry https://github.com/zsh-users/zsh-syntax-highlighting.git "${HOME}/.zsh/zsh-syntax-highlighting"
clone_with_retry https://github.com/jeffreytse/zsh-vi-mode.git "${HOME}/.zsh/zsh-vi-mode"

rm -rf \
    "${HOME}/.powerlevel10k/.git" \
    "${HOME}/.zsh/zsh-autosuggestions/.git" \
    "${HOME}/.zsh/zsh-syntax-highlighting/.git" \
    "${HOME}/.zsh/zsh-vi-mode/.git"

install -m 0644 /tmp/dotfiles-docker/.zshrc "${HOME}/.zshrc"
install -m 0644 /tmp/dotfiles-docker/.p10k.zsh "${HOME}/.p10k.zsh"
install -m 0644 /tmp/dotfiles-docker/.tmux.conf "${HOME}/.tmux.conf"
install -m 0644 /tmp/dotfiles-docker/.tmux.conf.local "${HOME}/.tmux.conf.local"
install -d "${HOME}/.vim/colors"
install -m 0644 /tmp/dotfiles-docker/.vimrc "${HOME}/.vimrc"
install -m 0644 /tmp/dotfiles-docker/gruvbox.vim "${HOME}/.vim/colors/gruvbox.vim"
install -d /etc/skel
install -m 0644 /tmp/dotfiles-docker/.zshrc /etc/skel/.zshrc
install -m 0644 /tmp/dotfiles-docker/.p10k.zsh /etc/skel/.p10k.zsh
install -m 0644 /tmp/dotfiles-docker/.tmux.conf /etc/skel/.tmux.conf
install -m 0644 /tmp/dotfiles-docker/.tmux.conf.local /etc/skel/.tmux.conf.local
install -d /etc/skel/.vim/colors
install -m 0644 /tmp/dotfiles-docker/.vimrc /etc/skel/.vimrc
install -m 0644 /tmp/dotfiles-docker/gruvbox.vim /etc/skel/.vim/colors/gruvbox.vim
