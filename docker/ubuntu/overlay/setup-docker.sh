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

TARGET_DIR="${1}"

install -d "${TARGET_DIR}/.zsh"
clone_with_retry https://github.com/romkatv/powerlevel10k.git "${TARGET_DIR}/.powerlevel10k"
install -d "${TARGET_DIR}/.powerlevel10k/gitstatus/usrbin"
run_with_retry env GITSTATUS_CACHE_DIR="${TARGET_DIR}/.powerlevel10k/gitstatus/usrbin" \
    "${TARGET_DIR}/.powerlevel10k/gitstatus/install" -f

clone_with_retry https://github.com/zsh-users/zsh-autosuggestions.git "${TARGET_DIR}/.zsh/zsh-autosuggestions"
clone_with_retry https://github.com/zsh-users/zsh-syntax-highlighting.git "${TARGET_DIR}/.zsh/zsh-syntax-highlighting"
clone_with_retry https://github.com/jeffreytse/zsh-vi-mode.git "${TARGET_DIR}/.zsh/zsh-vi-mode"

rm -rf \
    "${TARGET_DIR}/.powerlevel10k/.git" \
    "${TARGET_DIR}/.zsh/zsh-autosuggestions/.git" \
    "${TARGET_DIR}/.zsh/zsh-syntax-highlighting/.git" \
    "${TARGET_DIR}/.zsh/zsh-vi-mode/.git"
