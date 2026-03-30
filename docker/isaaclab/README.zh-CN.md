# isaaclab

[English Version](./README.md)

## 概述

这个镜像基于 `wtyyy/ubuntu:24.04`，并在 `/home/user` 下安装 Isaac Lab 运行环境，包括：

- `uv`
- 虚拟环境 `/home/user/isaaclab`
- `torch==2.7.0`
- `torchvision==0.22.0`
- `isaaclab[isaacsim,all]==2.3.2.post1`
- 运行库：`libgomp1`、`libglu1`、`mesa-utils`、`vulkan-tools`、`x11-apps`

## 构建

```bash
docker build -t wtyyy/isaaclab:2.3.2.post1 .
```

## 运行

```bash
docker run -it --rm --gpus all --name ${USER}-isaaclab wtyyy/isaaclab:2.3.2.post1
```

推荐在图形界面和缓存持久化场景下使用：

```bash
docker run -it --name isaaclab_${USER} \
    -e DISPLAY \
    --gpus all \
    -e NVIDIA_DRIVER_CAPABILITIES=all \
    -e "__NV_PRIME_RENDER_OFFLOAD=1" \
    -e "__GLX_VENDOR_LIBRARY_NAME=nvidia" \
    -v "/tmp/.X11-unix:/tmp/.X11-unix" \
    -v /usr/share/vulkan/icd.d/nvidia_icd.json:/usr/share/vulkan/icd.d/nvidia_icd.json:ro \
    -v /path/to/Coding:/home/user/Coding \
    -v ${HOME}/isaaclab_docker/.cache/ov:/home/user/.cache/ov \
    -v ${HOME}/isaaclab_docker/.nvidia-omniverse:/home/user/.nvidia-omniverse \
    --net=host \
    wtyyy/isaaclab:2.3.2.post1 zsh
```

说明：

- 把 `/path/to/Coding` 替换成你本地的工作目录。
- 如果想复用缓存，建议先在宿主机创建 `${HOME}/isaaclab_docker/.cache/ov` 和 `${HOME}/isaaclab_docker/.nvidia-omniverse`。
- 进入容器的 `zsh` 后会自动 `source /home/user/isaaclab/bin/activate`。

## 目录结构

- [Dockerfile](/home/yy/Coding/GitHub/dotfiles/docker/isaaclab/Dockerfile)：镜像定义

## GitHub Actions

仓库已包含工作流 `.github/workflows/docker-isaaclab.yml`。

- 触发条件：推送到 `main` 或 `master` 且改动 `docker/isaaclab/**`、`docker/ubuntu/**`，或手动触发 `workflow_dispatch`
- 默认输出镜像：
  - `wtyyy/isaaclab:2.3.2.post1`
- 手动发版：
  - 触发 `workflow_dispatch`
  - 填写 `isaaclab_version`
  - 输出镜像会变成 `wtyyy/isaaclab:<isaaclab_version>`

运行前请先在仓库 Secrets 中配置：

- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`
