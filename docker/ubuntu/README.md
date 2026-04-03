# Ubuntu Docker Image

English | [中文](./README.zh-CN.md)

## Contents

- [Overview](#overview)
- [Build](#build)
- [Run](#run)
- [GitHub Actions](#github-actions)

## Overview

Minimal Ubuntu Docker image (supports `24.04` and `22.04`) with:

- `zsh` with `powerlevel10k` and common plugins
- `tmux` with the repo's `.tmux` configuration
- `vim` with `gruvbox`
- timezone with `Asia/Shanghai`
- running by user specified `DEFAULT_UID` and `DEFAULT_GID`, which **make created files owned by the host user**, especially when mounting volumes

## Build

From this directory (default base is `ubuntu:24.04`):

```bash
cd docker
docker build -t wtyyy/ubuntu:24.04 ubuntu
```

Build for Ubuntu 22.04:

```bash
docker build --build-arg UBUNTU_TAG=22.04 -t wtyyy/ubuntu:22.04 ubuntu
```

## Run

### Basic Example

Run Ubuntu 24.04 with host UID/GID alignment:

```bash
docker run -it --rm \
  --name "${USER}-ubuntu" \
  -e DEFAULT_UID="$(id -u)" \
  -e DEFAULT_GID="$(id -g)" \
  wtyyy/ubuntu:24.04
```

- `-it`: interactive terminal
- `--rm`: remove container after exit
- `--name`: container name
- `-e DEFAULT_UID` and `-e DEFAULT_GID`: pass host user UID and GID for file permission alignment

Or run with root:

```bash
docker run -it --rm \
  --name "${USER}-ubuntu-root" \
  -u 0 \
  wtyyy/ubuntu:24.04
```

### Render Example

> Install [`nvidia-container-toolkit`](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) first to enable NVIDIA GPU support in Docker.

Run `xhost +local:docker` on host first to allow accessing X11 from Docker container.

Example USER with X11 GUI support + NVIDIA GPU + Vulkan + host network + input devices:

```bash
docker run -it --name "${USER}-ubuntu" \
  -e DEFAULT_UID="$(id -u)" \
  -e DEFAULT_GID="$(id -g)" \
  -e DISPLAY \
  --gpus all \
  -v "/tmp/.X11-unix:/tmp/.X11-unix" \
  -e NVIDIA_DRIVER_CAPABILITIES=all \
  -e "__NV_PRIME_RENDER_OFFLOAD=1" \
  -e "__GLX_VENDOR_LIBRARY_NAME=nvidia" \
  -v /etc/vulkan/icd.d/nvidia_icd.json:/etc/vulkan/icd.d/nvidia_icd.json:ro \
  --device /dev/input \
  --group-add $(getent group input | cut -d: -f3) \
  --net=host \
  wtyyy/ubuntu:24.04 zsh
```

- X11:
  - `-e DISPLAY`: specify display for X11 forwarding
  - `-v "/tmp/.X11-unix:/tmp/.X11-unix"`: mount X11 socket for GUI
- `--gpus all`: enable all GPUs
- NVIDIA environment variables for GPU rendering and Vulkan support
  - `-e NVIDIA_DRIVER_CAPABILITIES=all`: enable all NVIDIA driver capabilities
  - `-e "__NV_PRIME_RENDER_OFFLOAD=1"`: for NVIDIA PRIME render offload
  - `-e "__GLX_VENDOR_LIBRARY_NAME=nvidia"`: use NVIDIA GLX library
  - `-v /etc/vulkan/icd.d/nvidia_icd.json:/etc/vulkan/icd.d/nvidia_icd.json:ro`: mount NVIDIA Vulkan ICD for Vulkan support
- `--device /dev/input` and `--group-add $(getent group input | cut -d: -f3)`: allow access to input devices
- `--net=host`: use host network

If needed, add `-v /path/to/Coding/:/home/user/Coding` to mount a local directory into the container.

If you exit the container and want to enter it again later:

```bash
docker start ${USER}-ubuntu
docker exec -it ${USER}-ubuntu zsh
```

## GitHub Actions

This repo includes dockerfile auto-building workflow [`.github/workflows/docker-ubuntu.yml`](../../.github/workflows/docker-ubuntu.yml) that uploads to [Docker Hub - wtyyy/ubuntu](https://hub.docker.com/repository/docker/wtyyy/ubuntu).

- Trigger: push to `main` or `master` with changes under `docker/ubuntu/**`
- Output images:
  - `wtyyy/ubuntu:24.04`
  - `wtyyy/ubuntu:22.04`

Configure these repository secrets before running the workflow:

- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN` (Docker Hub access token)
