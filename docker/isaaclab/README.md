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
docker run -it --rm \
    --name ${USER}-isaaclab \
    -e DEFAULT_UID="$(id -u)" \
    -e DEFAULT_GID="$(id -g)" \
    --gpus all \
    wtyyy/isaaclab:2.3.2.post1
```

Recommended for GUI usage with persistent Omniverse cache:

```bash
# Create cache directories on host first
mkdir -p ${HOME}/isaaclab_docker/.cache/ov
mkdir -p ${HOME}/isaaclab_docker/.nvidia-omniverse

docker run -it --name ${USER}-isaaclab \
  -e DEFAULT_UID="$(id -u)" \
  -e DEFAULT_GID="$(id -g)" \
  -e DISPLAY \
  --gpus all \
  -e NVIDIA_DRIVER_CAPABILITIES=all \
  -e "__NV_PRIME_RENDER_OFFLOAD=1" \
  -e "__GLX_VENDOR_LIBRARY_NAME=nvidia" \
  -v "/tmp/.X11-unix:/tmp/.X11-unix" \
  -v /etc/vulkan/icd.d/nvidia_icd.json:/etc/vulkan/icd.d/nvidia_icd.json:ro \
  -v /path/to/Coding:/home/user/Coding \
  -v ${HOME}/isaaclab_docker/.cache/ov:/home/user/.cache/ov \
  -v ${HOME}/isaaclab_docker/.nvidia-omniverse:/home/user/.nvidia-omniverse \
  --net=host \
  wtyyy/isaaclab:2.3.2.post1 zsh
```

Notes:

- Replace `/path/to/Coding` with your local workspace path.
- Create `${HOME}/isaaclab_docker/.cache/ov` and `${HOME}/isaaclab_docker/.nvidia-omniverse` on the host first if you want persistent cache reuse.
- The run examples above already pass `DEFAULT_UID` and `DEFAULT_GID` so mounted files stay aligned with host ownership.
- The image defaults to user `user`, and the default working directory is `/home/user`.
- `PATH` already includes `/home/user/isaaclab/bin`, so `python` and `pip` point to the Isaac Lab environment by default.
- Entering `zsh` also auto-sources `/home/user/isaaclab/bin/activate`.

If you exit the container and want to enter it again later:

```bash
docker start ${USER}-isaaclab
docker exec -it ${USER}-isaaclab zsh
```

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
