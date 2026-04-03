#!/bin/sh
set -eu

DEFAULT_USER="user"
DEFAULT_UID="${DEFAULT_UID:-1000}"
DEFAULT_GID="${DEFAULT_GID:-1000}"
DEFAULT_HOME="/home/user"
INITIAL_USER="init-user"

# ==================== Check UID/GID is integer and range is valid (>=1000 and <65536) ==================== 
if ! [ "${DEFAULT_UID}" -eq "${DEFAULT_UID}" ] 2>/dev/null || [ "${DEFAULT_UID}" -lt 1000 ] || [ "${DEFAULT_UID}" -ge 65536 ]; then
    echo "ERROR: DEFAULT_UID (${DEFAULT_UID}) is invalid. It must be a number in [1000, 65535]." >&2
    echo "Hint: UID 0-999 are reserved for system accounts. If you need root, use 'docker run -u 0' instead." >&2
    exit 1
fi
if ! [ "${DEFAULT_GID}" -eq "${DEFAULT_GID}" ] 2>/dev/null || [ "${DEFAULT_GID}" -lt 1000 ] || [ "${DEFAULT_GID}" -ge 65536 ]; then
    echo "ERROR: DEFAULT_GID (${DEFAULT_GID}) is invalid. It must be a number in [1000, 65535]." >&2
    echo "Hint: GID 0-999 are reserved for system groups. If you need root group, use 'docker run -g 0' instead." >&2
    exit 1
fi

# ==================== Part 1: Check DEFAULT_USER uid and gid is correct as expected ====================
# Running container as DEFAULT_USER, will use ROOT to run this entrypoint again, goto Part 2
if [ "$(id -u)" != "0" ]; then
    if [ "${ENTRYPOINT_REEXEC_AS_ROOT:-0}" != "1" ] && { [ "$(id -u)" != "${DEFAULT_UID}" ] || [ "$(id -g)" != "${DEFAULT_GID}" ]; }; then
        exec sudo -E env ENTRYPOINT_REEXEC_AS_ROOT=1 /usr/local/bin/docker-entrypoint.sh "$@"
    fi
    export HOME="${DEFAULT_HOME}"
    export USER="${DEFAULT_USER}"
    export LOGNAME="${DEFAULT_USER}"
    exec "$@"
fi

# ==================== Part 2: ROOT EXECUTION ====================

CURRENT_UID="$(id -u "${DEFAULT_USER}")"
CURRENT_GID="$(id -g "${DEFAULT_USER}")"

# To avoid usermod's default change home directory permission, we set a temporary home
if [ "${CURRENT_UID}" != "${DEFAULT_UID}" ] || [ "${CURRENT_GID}" != "${DEFAULT_GID}" ]; then
    mkdir -p /tmp/dummy_home
    usermod -d /tmp/dummy_home "${DEFAULT_USER}"

    # Align CURRENT_GID to DEFAULT_GID, if needed
    if [ "${CURRENT_GID}" != "${DEFAULT_GID}" ]; then
        existing_group="$(getent group "${DEFAULT_GID}" | cut -d: -f1 || true)"
        if [ -n "${existing_group}" ] && [ "${existing_group}" != "${DEFAULT_USER}" ]; then
            groupdel "${existing_group}"
        fi
        groupmod -g "${DEFAULT_GID}" "${DEFAULT_USER}"
    fi

    # Align CURRENT_UID to DEFAULT_UID, if needed
    if [ "${CURRENT_UID}" != "${DEFAULT_UID}" ]; then
        uid_owner="$(getent passwd "${DEFAULT_UID}" | cut -d: -f1 || true)"
        if [ -n "${uid_owner}" ] && [ "${uid_owner}" != "${DEFAULT_USER}" ]; then
            userdel "${uid_owner}"
        fi
        usermod -u "${DEFAULT_UID}" "${DEFAULT_USER}"
    fi

    usermod -d "${DEFAULT_HOME}" "${DEFAULT_USER}"
    rm -rf /tmp/dummy_home
fi

# Add DEFAULT_USER to INITIAL_USER's groups, get all files permission in DEFAULT_HOME
usermod -aG "${INITIAL_USER}" "${DEFAULT_USER}"

if [ "${ENTRYPOINT_REEXEC_AS_ROOT:-0}" = "1" ]; then
    # If entrypoint is re-execed with root, start DEFAULT_USER
    export HOME="${DEFAULT_HOME}"
    export USER="${DEFAULT_USER}"
    export LOGNAME="${DEFAULT_USER}"
    exec gosu "${DEFAULT_USER}" "$@"
else
    # If entrypoint is root, docker run -u 0, start with root
    export HOME="/root"
    export USER="root"
    export LOGNAME="root"
    if [ "$PWD" = "${DEFAULT_HOME}" ]; then
        cd "/root"
    fi
    exec "$@"
fi
