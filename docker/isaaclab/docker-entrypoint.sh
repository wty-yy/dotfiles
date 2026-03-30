#!/bin/sh
set -eu

DEFAULT_USER="user"
DEFAULT_UID="${DEFAULT_UID:-1000}"
DEFAULT_GID="${DEFAULT_GID:-1000}"
DEFAULT_HOME_BASE="${DEFAULT_HOME_BASE:-/home}"
DEFAULT_HOME="${DEFAULT_HOME:-${DEFAULT_HOME_BASE}/${DEFAULT_USER}}"

find_group_name_by_gid() {
    gid="$1"
    awk -F: -v target_gid="${gid}" '$3 == target_gid { print $1; exit }' /etc/group
}

find_user_name_by_uid() {
    uid="$1"
    awk -F: -v target_uid="${uid}" '$3 == target_uid { print $1; exit }' /etc/passwd
}

user_in_group() {
    username="$1"
    groupname="$2"
    id -nG "${username}" | tr ' ' '\n' | grep -Fx "${groupname}" >/dev/null 2>&1
}

set_user_home() {
    username="$1"
    current_home="$(getent passwd "${username}" | cut -d: -f6)"

    if [ "${current_home}" = "${DEFAULT_HOME}" ]; then
        return
    fi

    if [ -e "${DEFAULT_HOME}" ]; then
        usermod -d "${DEFAULT_HOME}" "${username}"
        return
    fi

    usermod -d "${DEFAULT_HOME}" -m "${username}"
}

set_user_shell() {
    username="$1"
    current_shell="$(getent passwd "${username}" | cut -d: -f7)"

    if [ "${current_shell}" = "/usr/bin/zsh" ]; then
        return
    fi

    usermod -s /usr/bin/zsh "${username}"
}

set_user_primary_group() {
    username="$1"
    target_group="$2"
    current_gid="$(id -g "${username}")"
    target_gid="$(getent group "${target_group}" | cut -d: -f3)"

    if [ "${current_gid}" = "${target_gid}" ]; then
        return
    fi

    usermod -g "${target_group}" "${username}"
}

ensure_group() {
    if getent group "${DEFAULT_USER}" >/dev/null 2>&1; then
        existing_gid="$(getent group "${DEFAULT_USER}" | cut -d: -f3)"
        if [ "${existing_gid}" != "${DEFAULT_GID}" ]; then
            groupmod -g "${DEFAULT_GID}" "${DEFAULT_USER}"
        fi
        printf '%s\n' "${DEFAULT_USER}"
        return
    fi

    existing_group="$(find_group_name_by_gid "${DEFAULT_GID}")"
    if [ -n "${existing_group}" ]; then
        printf '%s\n' "${existing_group}"
        return
    fi

    groupadd -g "${DEFAULT_GID}" "${DEFAULT_USER}"
    printf '%s\n' "${DEFAULT_USER}"
}

ensure_user() {
    if id -u "${DEFAULT_USER}" >/dev/null 2>&1; then
        existing_uid="$(id -u "${DEFAULT_USER}")"
        if [ "${existing_uid}" != "${DEFAULT_UID}" ]; then
            uid_owner="$(find_user_name_by_uid "${DEFAULT_UID}")"
            if [ -n "${uid_owner}" ] && [ "${uid_owner}" != "${DEFAULT_USER}" ]; then
                usermod -l "${uid_owner}-old" "${uid_owner}"
            fi
            usermod -u "${DEFAULT_UID}" "${DEFAULT_USER}"
        fi
        set_user_home "${DEFAULT_USER}"
        set_user_primary_group "${DEFAULT_USER}" "${TARGET_GROUP}"
        set_user_shell "${DEFAULT_USER}"
        return
    fi

    uid_owner="$(find_user_name_by_uid "${DEFAULT_UID}")"
    if [ -n "${uid_owner}" ]; then
        if [ "${uid_owner}" != "${DEFAULT_USER}" ]; then
            usermod -l "${DEFAULT_USER}" "${uid_owner}"
        fi
        set_user_home "${DEFAULT_USER}"
        set_user_primary_group "${DEFAULT_USER}" "${TARGET_GROUP}"
        set_user_shell "${DEFAULT_USER}"
        return
    fi

    if [ -e "${DEFAULT_HOME}" ]; then
        useradd \
            --uid "${DEFAULT_UID}" \
            --gid "${TARGET_GROUP}" \
            --home-dir "${DEFAULT_HOME}" \
            --shell /usr/bin/zsh \
            "${DEFAULT_USER}"
        return
    fi

    useradd \
        --uid "${DEFAULT_UID}" \
        --gid "${TARGET_GROUP}" \
        --home-dir "${DEFAULT_HOME}" \
        --create-home \
        --shell /usr/bin/zsh \
        "${DEFAULT_USER}"
}

ensure_access_groups() {
    for entry in "${DEFAULT_HOME}"/* "${DEFAULT_HOME}"/.[!.]* "${DEFAULT_HOME}"/..?*; do
        if [ ! -e "${entry}" ]; then
            continue
        fi

        entry_gid="$(stat -c '%g' "${entry}")"
        if [ "${entry_gid}" = "${DEFAULT_GID}" ] || [ "${entry_gid}" = "0" ]; then
            continue
        fi

        entry_group="$(find_group_name_by_gid "${entry_gid}")"
        if [ -z "${entry_group}" ]; then
            continue
        fi

        if ! user_in_group "${DEFAULT_USER}" "${entry_group}"; then
            usermod -aG "${entry_group}" "${DEFAULT_USER}"
        fi
    done
}

sync_root_config() {
    install -d -m 0755 "${DEFAULT_HOME}"

    for entry in .zshrc .p10k.zsh .tmux.conf .tmux.conf.local .vimrc .powerlevel10k .zsh .vim; do
        if [ -e "/root/${entry}" ] && [ ! -e "${DEFAULT_HOME}/${entry}" ]; then
            cp -a "/root/${entry}" "${DEFAULT_HOME}/${entry}"
        fi
    done

    # Avoid recursive chown over the full home directory because the Isaac Lab
    # virtualenv contains many files and would make every container startup slow.
    chown "${DEFAULT_UID}:${DEFAULT_GID}" "${DEFAULT_HOME}"
    for entry in .zshrc .p10k.zsh .tmux.conf .tmux.conf.local .vimrc; do
        if [ -e "${DEFAULT_HOME}/${entry}" ]; then
            chown "${DEFAULT_UID}:${DEFAULT_GID}" "${DEFAULT_HOME}/${entry}"
        fi
    done
    for entry in .powerlevel10k .zsh .vim; do
        if [ -e "${DEFAULT_HOME}/${entry}" ]; then
            chown -R "${DEFAULT_UID}:${DEFAULT_GID}" "${DEFAULT_HOME}/${entry}"
        fi
    done
}

ensure_sudo_access() {
    usermod -aG sudo "${DEFAULT_USER}"
    printf '%s ALL=(ALL) NOPASSWD:ALL\n' "${DEFAULT_USER}" > "/etc/sudoers.d/90-${DEFAULT_USER}"
    chmod 0440 "/etc/sudoers.d/90-${DEFAULT_USER}"
}

select_workdir() {
    cd "${DEFAULT_HOME}"
}

TARGET_GROUP="$(ensure_group)"
ensure_user
ensure_access_groups
sync_root_config
ensure_sudo_access
select_workdir

export HOME="${DEFAULT_HOME}"
export USER="${DEFAULT_USER}"
export LOGNAME="${DEFAULT_USER}"
exec gosu "${DEFAULT_USER}:${TARGET_GROUP}" "$@"
