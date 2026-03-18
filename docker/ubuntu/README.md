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
docker build -t wtyyy/ubuntu:24.04 .
```

Build for Ubuntu 22.04:

```bash
docker build --build-arg UBUNTU_TAG=22.04 -t wtyyy/ubuntu:22.04 .
```

## Run

Start an interactive shell:

```bash
docker run -it --rm --name ${USER}-ubuntu wtyyy/ubuntu:24.04
```

Adjust the fixed `user` account to match the host UID/GID:

```bash
docker run -it --rm \
  --name ${USER}-ubuntu \
  -e DEFAULT_UID="$(id -u)" \
  -e DEFAULT_GID="$(id -g)" \
  wtyyy/ubuntu:24.04
```

If you want to mount the current working directory into the container:

```bash
docker run -it --rm \
  --name ${USER}-ubuntu \
  -e DEFAULT_UID="$(id -u)" \
  -e DEFAULT_GID="$(id -g)" \
  -v "$(pwd)":/home/user/workspace \
  wtyyy/ubuntu:24.04
```

## Included Behavior

- Prompt theme is provided by `powerlevel10k`.
- `gitstatusd` is downloaded during image build, so the first shell startup does not need to fetch it.
- Directory color uses the same `dircolors` override as the main repo `zshrc`, with directories shown in cyan.
- `vim` uses a minimal config with `gruvbox`, line numbers, relative numbers, cursorline, and 4-space indentation.
- Container startup creates a fixed `user` account, syncs the prepared shell/vim config from `/root` into `/home/user`, and then switches to that user.
- The new user gets passwordless `sudo`, which is the closest practical equivalent to root privileges while keeping a normal user shell.

## Layout

- [Dockerfile](/home/yy/Coding/GitHub/dotfiles/docker/ubuntu/Dockerfile): image definition
- [overlay/.zshrc](/home/yy/Coding/GitHub/dotfiles/docker/ubuntu/overlay/.zshrc): shell config
- [overlay/.p10k.zsh](/home/yy/Coding/GitHub/dotfiles/docker/ubuntu/overlay/.p10k.zsh): p10k prompt config
- [overlay/.vimrc](/home/yy/Coding/GitHub/dotfiles/docker/ubuntu/overlay/.vimrc): minimal vim config
- [overlay/gruvbox.vim](/home/yy/Coding/GitHub/dotfiles/docker/ubuntu/overlay/gruvbox.vim): vim colorscheme
- [overlay/setup-docker.sh](/home/yy/Coding/GitHub/dotfiles/docker/ubuntu/overlay/setup-docker.sh): install script used during build

## Notes

- Build requires network access because `powerlevel10k` and zsh plugins are cloned during image build.
- If GitHub access is unstable, `setup-docker.sh` already retries clone and gitstatus download.
- Docker cannot reliably detect the host UID/GID by itself; if you want mounted files to match host ownership, pass `DEFAULT_UID` and `DEFAULT_GID` to `docker run`.

### GitHub Actions (Publish to Docker Hub)

This repo includes workflow `.github/workflows/docker-ubuntu.yml`.

- Trigger: push to `main` or `master` with changes under `docker/ubuntu/**` (or manual `workflow_dispatch`)
- Output images:
  - `wtyyy/ubuntu:24.04`
  - `wtyyy/ubuntu:22.04`

Configure these repository secrets before running the workflow:

- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN` (Docker Hub access token)
