ARG UBUNTU_TAG=24.04
FROM ubuntu:${UBUNTU_TAG}

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        gosu \
        locales \
        sudo \
        vim \
        zsh \
    && locale-gen en_US.UTF-8 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV SHELL=/usr/bin/zsh

COPY overlay/.zshrc /tmp/dotfiles-docker/.zshrc
COPY overlay/.p10k.zsh /tmp/dotfiles-docker/.p10k.zsh
COPY overlay/.vimrc /tmp/dotfiles-docker/.vimrc
COPY overlay/gruvbox.vim /tmp/dotfiles-docker/gruvbox.vim
COPY overlay/setup-docker.sh /tmp/dotfiles-docker/setup-docker.sh
COPY overlay/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chmod +x /tmp/dotfiles-docker/setup-docker.sh \
    && /tmp/dotfiles-docker/setup-docker.sh \
    && chmod +x /usr/local/bin/docker-entrypoint.sh \
    && rm -rf /tmp/dotfiles-docker

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
WORKDIR /home/user
CMD ["/usr/bin/zsh"]
