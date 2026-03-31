ARG UBUNTU_TAG=24.04
FROM ubuntu:${UBUNTU_TAG}

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
    target_group="$(awk -F: -v gid="${DEFAULT_GID}" '$3 == gid { print $1; exit }' /etc/group)"; \
    if [ -z "${target_group}" ]; then \
        groupadd -g "${DEFAULT_GID}" "${DEFAULT_USER}"; \
        target_group="${DEFAULT_USER}"; \
    fi; \
    uid_owner="$(awk -F: -v uid="${DEFAULT_UID}" '$3 == uid { print $1; exit }' /etc/passwd)"; \
    if [ -n "${uid_owner}" ] && [ "${uid_owner}" != "${DEFAULT_USER}" ]; then \
        usermod -l "${DEFAULT_USER}" "${uid_owner}"; \
    fi; \
    if id -u "${DEFAULT_USER}" >/dev/null 2>&1; then \
        usermod -d "${DEFAULT_HOME}" "${DEFAULT_USER}"; \
        usermod -g "${target_group}" "${DEFAULT_USER}"; \
        usermod -s /usr/bin/zsh "${DEFAULT_USER}"; \
        if [ "$(id -u "${DEFAULT_USER}")" != "${DEFAULT_UID}" ]; then \
            usermod -u "${DEFAULT_UID}" "${DEFAULT_USER}"; \
        fi; \
    else \
        useradd -m -d "${DEFAULT_HOME}" -u "${DEFAULT_UID}" -g "${target_group}" -s /usr/bin/zsh "${DEFAULT_USER}"; \
    fi; \
    usermod -aG sudo "${DEFAULT_USER}"; \
    printf '%s ALL=(ALL) NOPASSWD:ALL\n' "${DEFAULT_USER}" > "/etc/sudoers.d/90-${DEFAULT_USER}"; \
    chmod 0440 "/etc/sudoers.d/90-${DEFAULT_USER}"

COPY overlay/.zshrc /tmp/dotfiles-docker/.zshrc
COPY overlay/.p10k.zsh /tmp/dotfiles-docker/.p10k.zsh
COPY overlay/.tmux.conf /tmp/dotfiles-docker/.tmux.conf
COPY overlay/.tmux.conf.local /tmp/dotfiles-docker/.tmux.conf.local
COPY overlay/.vimrc /tmp/dotfiles-docker/.vimrc
COPY overlay/gruvbox.vim /tmp/dotfiles-docker/gruvbox.vim
COPY overlay/setup-docker.sh /tmp/dotfiles-docker/setup-docker.sh
COPY overlay/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chmod +x /tmp/dotfiles-docker/setup-docker.sh \
    && /tmp/dotfiles-docker/setup-docker.sh \
    && cp -a /etc/skel/. "${DEFAULT_HOME}/" \
    && cp -a /root/.powerlevel10k "${DEFAULT_HOME}/.powerlevel10k" \
    && cp -a /root/.zsh "${DEFAULT_HOME}/.zsh" \
    && chown -R "${DEFAULT_UID}:${DEFAULT_GID}" "${DEFAULT_HOME}" \
    && chmod +x /usr/local/bin/docker-entrypoint.sh \
    && rm -rf /tmp/dotfiles-docker

USER ${DEFAULT_USER}
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
WORKDIR ${DEFAULT_HOME}
CMD ["/usr/bin/zsh"]
