# IsaacLab Docker Image

English | [中文](./README.zh-CN.md)

## Contents

- [Overview](#overview)
- [Build](#build)
- [Run](#run)
- [GitHub Actions](#github-actions)

## Overview

This image extends `wtyyy/ubuntu:24.04` and installs the Isaac Lab environment in `/home/user` with:

- `uv` and uv venv at `/home/user/isaaclab`
- python packages (change versions in `Dockerfile` if needed):
  - `torch==2.7.0`
  - `torchvision==0.22.0`
  - `isaaclab[isaacsim,all]==2.3.2.post1`
- system runtime packages:
  - IsaacSim: `libgomp1`, `libglu1`
  - Render & DEBUG: `mesa-utils`, `vulkan-tools`, `x11-apps`

## Build

```bash
cd docker
docker build -t wtyyy/isaaclab:2.3.2.post1 isaaclab
```

## Run
> Install [`nvidia-container-toolkit`](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) first to enable NVIDIA GPU support in Docker.

Run `xhost +local:docker` on host first to allow accessing X11 from Docker container.

Example USER with X11 GUI support + NVIDIA GPU + Vulkan + host network + input devices + mounted cache files + mounted workspace:

```bash
# Create cache directories on host first
mkdir -p ${HOME}/isaaclab_docker/.cache/ov
mkdir -p ${HOME}/isaaclab_docker/.nvidia-omniverse

docker run -it --name ${USER}-isaaclab \
  -e DEFAULT_UID="$(id -u)" \
  -e DEFAULT_GID="$(id -g)" \
  -e DISPLAY \
  -v "/tmp/.X11-unix:/tmp/.X11-unix" \
  --gpus all \
  -e NVIDIA_DRIVER_CAPABILITIES=all \
  -e "__NV_PRIME_RENDER_OFFLOAD=1" \
  -e "__GLX_VENDOR_LIBRARY_NAME=nvidia" \
  -v /etc/vulkan/icd.d/nvidia_icd.json:/etc/vulkan/icd.d/nvidia_icd.json:ro \
  --device /dev/input \
  --group-add $(getent group input | cut -d: -f3) \
  --net=host \
  -v /path/to/Coding:/home/user/Coding \
  -v ${HOME}/isaaclab_docker/.cache/ov:/home/user/.cache/ov \
  -v ${HOME}/isaaclab_docker/.nvidia-omniverse:/home/user/.nvidia-omniverse \
  wtyyy/isaaclab:2.3.2.post1 zsh
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
- `-v /path/to/Coding:/home/user/Coding`: mount local workspace into container (optional)
- `-v ${HOME}/isaaclab_docker/.cache/ov:/home/user/.cache/ov` and `-v ${HOME}/isaaclab_docker/.nvidia-omniverse:/home/user/.nvidia-omniverse`: mount cache directories to persist assets

If you exit the container and want to enter it again later:

```bash
docker start ${USER}-isaaclab
docker exec -it ${USER}-isaaclab zsh
```

## GitHub Actions

This repo includes dockerfile auto-building workflow [`.github/workflows/docker-isaaclab.yml`](../../.github/workflows/docker-isaaclab.yml) that upload to [Docker Hub - wtyyy/isaaclab](https://hub.docker.com/repository/docker/wtyyy/isaaclab):

- Trigger: push to `main` or `master` with changes under `docker/isaaclab/**`, `docker/ubuntu/**`
- Default output image:
  - `wtyyy/isaaclab:2.3.2.post1`
- Manual release:
  - trigger `workflow_dispatch`
  - fill `isaaclab_version`
  - output becomes `wtyyy/isaaclab:<isaaclab_version>`

Configure these repository secrets before running the workflow:

- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`
