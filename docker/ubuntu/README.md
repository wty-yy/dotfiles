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
- `tmux` with the repo's `.tmux` configuration
- `powerlevel10k`
- `zsh-autosuggestions`
- `zsh-syntax-highlighting`
- `vim` with `gruvbox`
- timezone fixed to `Asia/Shanghai`

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

Run Ubuntu 24.04 with host UID/GID alignment:

```bash
docker run -it --rm \
  --name ${USER}-ubuntu \
  -e DEFAULT_UID="$(id -u)" \
  -e DEFAULT_GID="$(id -g)" \
  wtyyy/ubuntu:24.04
```

Example with GUI support:

```bash
docker run -it --name ${USER}-ubuntu \
  -e DEFAULT_UID="$(id -u)" \
  -e DEFAULT_GID="$(id -g)" \
  -e DISPLAY \
  --gpus all \
  -e NVIDIA_DRIVER_CAPABILITIES=all \
  -e "__NV_PRIME_RENDER_OFFLOAD=1" \
  -e "__GLX_VENDOR_LIBRARY_NAME=nvidia" \
  -v "/tmp/.X11-unix:/tmp/.X11-unix" \
  -v /etc/vulkan/icd.d/nvidia_icd.json:/etc/vulkan/icd.d/nvidia_icd.json:ro \
  --net=host \
  wtyyy/ubuntu:24.04 zsh
```

If needed, add `-v /path/to/Coding/:/home/user/Coding` to mount a local directory into the container.

If you exit the container and want to enter it again later, specify the user explicitly:

```bash
docker start ${USER}-ubuntu
docker exec -it ${USER}-ubuntu sudo -iu user zsh
```

## Included Behavior

- Prompt theme is provided by `powerlevel10k`.
- `tmux` ships with the same `.tmux.conf` and `.tmux.conf.local` used in the repo.
- `gitstatusd` is downloaded during image build, so the first shell startup does not need to fetch it.
- Directory color uses the same `dircolors` override as the main repo `zshrc`, with directories shown in cyan.
- `vim` uses a minimal config with `gruvbox`, line numbers, relative numbers, cursorline, and 4-space indentation.
- Container timezone is set to `Asia/Shanghai`.
- Container startup creates a fixed `user` account, syncs the prepared shell/vim config from `/root` into `/home/user`, and then switches to that user.
- The new user gets passwordless `sudo`, which is the closest practical equivalent to root privileges while keeping a normal user shell.

## Layout

- [Dockerfile](/home/yy/Coding/GitHub/dotfiles/docker/ubuntu/Dockerfile): image definition
- [overlay/.zshrc](/home/yy/Coding/GitHub/dotfiles/docker/ubuntu/overlay/.zshrc): shell config
- [overlay/.p10k.zsh](/home/yy/Coding/GitHub/dotfiles/docker/ubuntu/overlay/.p10k.zsh): p10k prompt config
- [overlay/.tmux.conf](/home/yy/Coding/GitHub/dotfiles/docker/ubuntu/overlay/.tmux.conf): tmux base config
- [overlay/.tmux.conf.local](/home/yy/Coding/GitHub/dotfiles/docker/ubuntu/overlay/.tmux.conf.local): tmux local overrides
- [overlay/.vimrc](/home/yy/Coding/GitHub/dotfiles/docker/ubuntu/overlay/.vimrc): minimal vim config
- [overlay/gruvbox.vim](/home/yy/Coding/GitHub/dotfiles/docker/ubuntu/overlay/gruvbox.vim): vim colorscheme
- [overlay/setup-docker.sh](/home/yy/Coding/GitHub/dotfiles/docker/ubuntu/overlay/setup-docker.sh): install script used during build

## Notes

- Build requires network access because `powerlevel10k` and zsh plugins are cloned during image build.
- If GitHub access is unstable, `setup-docker.sh` already retries clone and gitstatus download.
- The run examples above already pass `DEFAULT_UID` and `DEFAULT_GID` so mounted files stay aligned with host ownership.

### GitHub Actions (Publish to Docker Hub)

This repo includes workflow `.github/workflows/docker-ubuntu.yml`.

- Trigger: push to `main` or `master` with changes under `docker/ubuntu/**` (or manual `workflow_dispatch`)
- Output images:
  - `wtyyy/ubuntu:24.04`
  - `wtyyy/ubuntu:22.04`

Configure these repository secrets before running the workflow:

- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN` (Docker Hub access token)
