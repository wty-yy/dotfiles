# ubuntu

[中文说明](./README.zh-CN.md)

## Contents

- [Overview](#overview)
- [Build](#build)
- [Run](#run)
- [Included Behavior](#included-behavior)
- [Layout](#layout)
- [Notes](#notes)

## Overview

Minimal Ubuntu Docker image (supports `24.04` and `22.04`) with:

- `zsh`
- `powerlevel10k`
- `zsh-autosuggestions`
- `zsh-syntax-highlighting`
- `vim` with `gruvbox`

This setup does not install `oh-my-zsh`. `powerlevel10k` is loaded directly from `.zshrc`.

## Build

From this directory (default base is `ubuntu:24.04`):

```bash
docker build -t ubuntu-test .
```

Build for Ubuntu 22.04:

```bash
docker build --build-arg UBUNTU_TAG=22.04 -t ubuntu-test:22.04 .
```

## GitHub Actions (Docker Hub)

This repo includes workflow `.github/workflows/docker-ubuntu.yml`.

- Trigger: push to `main` with changes under `docker/ubuntu/**` (or manual `workflow_dispatch`)
- Output images:
  - `wtyyy/ubuntu:24.04`
  - `wtyyy/ubuntu:22.04`

Configure repository secrets before running workflow:

- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN` (Docker Hub access token)

## Run

Start an interactive shell:

```bash
docker run -it --rm --name ${USER}-test ubuntu-test zsh
```

If you want to mount the current workspace into the container:

```bash
docker run -it --rm \
  --name ${USER}-test \
  -v "$(pwd)":/workspace \
  -w /workspace \
  ubuntu-test zsh
```

## Included Behavior

- Prompt theme is provided by `powerlevel10k`.
- `gitstatusd` is downloaded during image build, so the first shell startup does not need to fetch it.
- Directory color uses the same `dircolors` override as the main repo `zshrc`, with directories shown in cyan.
- `vim` uses a minimal config with `gruvbox`, line numbers, relative numbers, cursorline, and 4-space indentation.

## Layout

- [Dockerfile](/home/yy/Coding/GitHub/dotfiles/docker/ubuntu/Dockerfile): image definition
- [overlay/.zshrc](/home/yy/Coding/GitHub/dotfiles/docker/ubuntu/overlay/.zshrc): shell config
- [overlay/.p10k.zsh](/home/yy/Coding/GitHub/dotfiles/docker/ubuntu/overlay/.p10k.zsh): p10k prompt config
- [overlay/.vimrc](/home/yy/Coding/GitHub/dotfiles/docker/ubuntu/overlay/.vimrc): minimal vim config
- [overlay/gruvbox.vim](/home/yy/Coding/GitHub/dotfiles/docker/ubuntu/overlay/gruvbox.vim): vim colorscheme
- [overlay/setup-docker.sh](/home/yy/Coding/GitHub/dotfiles/docker/ubuntu/overlay/setup-docker.sh): install script used at build time

## Notes

- Build requires network access because `powerlevel10k` and zsh plugins are cloned during image build.
- If GitHub access is unstable, `setup-docker.sh` already retries clone and gitstatus download.

