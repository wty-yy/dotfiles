# ubuntu_p10k

[中文说明](./README.zh-CN.md)

## Contents

- [Overview](#overview)
- [Build](#build)
- [Run](#run)
- [Included Behavior](#included-behavior)
- [Layout](#layout)
- [Notes](#notes)

## Overview

Minimal Ubuntu 24.04 Docker image with:

- `zsh`
- `powerlevel10k`
- `zsh-autosuggestions`
- `zsh-syntax-highlighting`
- `vim` with `gruvbox`

This setup does not install `oh-my-zsh`. `powerlevel10k` is loaded directly from `.zshrc`.

## Build

From this directory:

```bash
docker build -t ubuntu-p10k-test .
```

## Run

Start an interactive shell:

```bash
docker run -it --rm --name ${USER}-test ubuntu-p10k-test zsh
```

If you want to mount the current workspace into the container:

```bash
docker run -it --rm \
  --name ${USER}-test \
  -v "$(pwd)":/workspace \
  -w /workspace \
  ubuntu-p10k-test zsh
```

## Included Behavior

- Prompt theme is provided by `powerlevel10k`.
- `gitstatusd` is downloaded during image build, so the first shell startup does not need to fetch it.
- Directory color uses the same `dircolors` override as the main repo `zshrc`, with directories shown in cyan.
- `vim` uses a minimal config with `gruvbox`, line numbers, relative numbers, cursorline, and 4-space indentation.

## Layout

- [Dockerfile](/home/yy/Coding/GitHub/dotfiles/docker/ubuntu_p10k/Dockerfile): image definition
- [overlay/.zshrc](/home/yy/Coding/GitHub/dotfiles/docker/ubuntu_p10k/overlay/.zshrc): shell config
- [overlay/.p10k.zsh](/home/yy/Coding/GitHub/dotfiles/docker/ubuntu_p10k/overlay/.p10k.zsh): p10k prompt config
- [overlay/.vimrc](/home/yy/Coding/GitHub/dotfiles/docker/ubuntu_p10k/overlay/.vimrc): minimal vim config
- [overlay/gruvbox.vim](/home/yy/Coding/GitHub/dotfiles/docker/ubuntu_p10k/overlay/gruvbox.vim): vim colorscheme
- [overlay/setup-docker.sh](/home/yy/Coding/GitHub/dotfiles/docker/ubuntu_p10k/overlay/setup-docker.sh): install script used at build time

## Notes

- Build requires network access because `powerlevel10k` and zsh plugins are cloned during image build.
- If GitHub access is unstable, `setup-docker.sh` already retries clone and gitstatus download.

