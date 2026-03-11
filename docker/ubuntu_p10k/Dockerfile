FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        locales \
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

RUN chmod +x /tmp/dotfiles-docker/setup-docker.sh \
    && /tmp/dotfiles-docker/setup-docker.sh \
    && rm -rf /tmp/dotfiles-docker

WORKDIR /root
CMD ["/usr/bin/zsh"]
