ARG UBUNTU_TAG=24.04
FROM ubuntu:${UBUNTU_TAG}

ARG INITIAL_USER=init-user
ARG INITIAL_UID=10000
ARG INITIAL_GID=10000
ARG DEFAULT_USER=user
ARG DEFAULT_UID=1000
ARG DEFAULT_GID=1000
ARG DEFAULT_HOME=/home/user

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Shanghai

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        gosu \
        locales \
        sudo \
        tmux \
        tzdata \
        vim \
        zsh \
    && ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime \
    && echo "${TZ}" > /etc/timezone \
    && locale-gen en_US.UTF-8 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV SHELL=/usr/bin/zsh

RUN set -eux; \
    # Remove the default "ubuntu" user if it exists
    if id -u ubuntu >/dev/null 2>&1; then \
        userdel -r ubuntu; \
    fi; \
    \
    # Check UID and GID availability
    for uid in "${INITIAL_UID}" "${DEFAULT_UID}"; do \
        if getent passwd "${uid}" >/dev/null 2>&1; then \
            echo "ERROR: UID ${uid} is already in use by $(getent passwd "${uid}" | cut -d: -f1). Aborting build."; \
            exit 1; \
        fi; \
    done; \
    for gid in "${INITIAL_GID}" "${DEFAULT_GID}"; do \
        if getent group "${gid}" >/dev/null 2>&1; then \
            echo "ERROR: GID ${gid} is already in use by $(getent group "${gid}" | cut -d: -f1). Aborting build."; \
            exit 1; \
        fi; \
    done; \
    \
    # Create the default and initial user and group
    groupadd -g "${DEFAULT_GID}" "${DEFAULT_USER}"; \
    useradd -M -u "${DEFAULT_UID}" -g "${DEFAULT_GID}" -s /usr/bin/zsh "${DEFAULT_USER}"; \
    groupadd -g "${INITIAL_GID}" "${INITIAL_USER}"; \
    useradd -m -d "${DEFAULT_HOME}" -u "${INITIAL_UID}" -g "${INITIAL_GID}" -s /usr/bin/zsh "${INITIAL_USER}"; \
    \
    # Set default user home to DEFAULT_HOME (DEFAULT_HOME own is INITIAL_USER, new files are DEFAULT_USER)
    usermod -d "${DEFAULT_HOME}" "${DEFAULT_USER}"; \
    usermod -aG "${INITIAL_USER}" "${DEFAULT_USER}"; \
    \
    # Set sudo permissions for DEFAULT_USER, with NOPASSWD
    usermod -aG sudo "${DEFAULT_USER}"; \
    printf '%s ALL=(ALL) NOPASSWD:ALL\n' "${DEFAULT_USER}" > "/etc/sudoers.d/90-${DEFAULT_USER}"; \
    chmod 0440 "/etc/sudoers.d/90-${DEFAULT_USER}"; \
    \
    # Add groups permissions
    for group in adm dialout cdrom floppy audio dip video plugdev render input tty; do \
        if getent group "$group" >/dev/null 2>&1; then \
            usermod -aG "$group" "${DEFAULT_USER}"; \
        fi; \
    done

# User configurations
COPY --chown=${INITIAL_UID}:${INITIAL_GID} overlay/.zshrc ${DEFAULT_HOME}/.zshrc
COPY --chown=${INITIAL_UID}:${INITIAL_GID} overlay/.p10k.zsh ${DEFAULT_HOME}/.p10k.zsh
COPY --chown=${INITIAL_UID}:${INITIAL_GID} overlay/.tmux.conf ${DEFAULT_HOME}/.tmux.conf
COPY --chown=${INITIAL_UID}:${INITIAL_GID} overlay/.tmux.conf.local ${DEFAULT_HOME}/.tmux.conf.local
COPY --chown=${INITIAL_UID}:${INITIAL_GID} overlay/.vimrc ${DEFAULT_HOME}/.vimrc
COPY --chown=${INITIAL_UID}:${INITIAL_GID} overlay/gruvbox.vim ${DEFAULT_HOME}/.vim/colors/gruvbox.vim

# Install and entrypoint script
COPY --chmod=755 overlay/setup-docker.sh /tmp/setup-docker.sh
COPY --chmod=755 overlay/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN set -eux; \
    /tmp/setup-docker.sh "${DEFAULT_HOME}"; \
    touch "${DEFAULT_HOME}/.sudo_as_admin_successful"; \
    rm -rf "${DEFAULT_HOME}/.cache" "${DEFAULT_HOME}/.zcompdump"* "${DEFAULT_HOME}/.zsh_history"; \
    chown -R "${INITIAL_UID}:${INITIAL_GID}" "${DEFAULT_HOME}"; \
    chmod -R g+rwX "${DEFAULT_HOME}"; \
    rm -f /tmp/setup-docker.sh

USER ${DEFAULT_USER}
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
WORKDIR ${DEFAULT_HOME}
CMD ["/usr/bin/zsh"]
