# isaaclab

[中文说明](./README.zh-CN.md)

## Overview

This image extends `wtyyy/ubuntu:24.04` and installs the Isaac Lab environment in `/home/user`:

- `uv`
- virtual environment `/home/user/isaaclab`
- `torch==2.7.0`
- `torchvision==0.22.0`
- `isaaclab[isaacsim,all]==2.3.2.post1`
- runtime packages: `libgomp1`, `libglu1`, `mesa-utils`, `vulkan-tools`, `x11-apps`

## Build

```bash
docker build -t wtyyy/isaaclab:2.3.2.post1 .
```

## Run

```bash
docker run -it --rm --gpus all --name ${USER}-isaaclab wtyyy/isaaclab:2.3.2.post1
```

The image keeps the virtualenv on `PATH`, so entering the container uses the Isaac Lab environment directly.

## Layout

- [Dockerfile](/home/yy/Coding/GitHub/dotfiles/docker/isaaclab/Dockerfile): image definition

## GitHub Actions

This repo includes workflow `.github/workflows/docker-isaaclab.yml`.

- Trigger: push to `main` or `master` with changes under `docker/isaaclab/**`, `docker/ubuntu/**`, or manual `workflow_dispatch`
- Default output image:
  - `wtyyy/isaaclab:2.3.2.post1`
- Manual release:
  - trigger `workflow_dispatch`
  - fill `isaaclab_version`
  - output becomes `wtyyy/isaaclab:<isaaclab_version>`

Configure these repository secrets before running the workflow:

- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`
