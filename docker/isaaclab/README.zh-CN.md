# IsaacLab Docker 镜像

[English](./README.md) | 中文

## 目录

- [概览](#概览)
- [构建](#构建)
- [运行](#运行)
- [GitHub Actions](#github-actions)

## 概览

该镜像基于 `wtyyy/ubuntu:24.04`，并在 `/home/user` 中安装 Isaac Lab 环境，包含：

- `uv` 以及位于 `/home/user/isaaclab` 的 uv venv
- Python 包，可按需在 `Dockerfile` 中修改版本：
  - `torch==2.7.0`
  - `torchvision==0.22.0`
  - `isaaclab[isaacsim,all]==2.3.2.post1`
- 系统运行时包：
  - IsaacSim：`libgomp1`、`libglu1`
  - 渲染与调试：`mesa-utils`、`vulkan-tools`、`x11-apps`

## 构建

```bash
cd docker
docker build -t wtyyy/isaaclab:2.3.2.post1 isaaclab
```

## 运行

> 先安装 [`nvidia-container-toolkit`](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)，才能在 Docker 中启用 NVIDIA GPU 支持。

先在宿主机上运行 `xhost +local:docker`，以允许 Docker 容器访问 X11。

带 X11 图形界面、NVIDIA GPU、Vulkan、host 网络、输入设备、挂载缓存文件和挂载工作区的普通用户示例：

```bash
# 先在宿主机创建缓存目录
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

- X11：
  - `-e DISPLAY`：指定 X11 转发显示
  - `-v "/tmp/.X11-unix:/tmp/.X11-unix"`：挂载 X11 socket 以支持 GUI
- `--gpus all`：启用全部 GPU
- NVIDIA 环境变量用于 GPU 渲染和 Vulkan 支持
  - `-e NVIDIA_DRIVER_CAPABILITIES=all`：启用全部 NVIDIA 驱动能力
  - `-e "__NV_PRIME_RENDER_OFFLOAD=1"`：用于 NVIDIA PRIME render offload
  - `-e "__GLX_VENDOR_LIBRARY_NAME=nvidia"`：使用 NVIDIA GLX 库
  - `-v /etc/vulkan/icd.d/nvidia_icd.json:/etc/vulkan/icd.d/nvidia_icd.json:ro`：挂载 NVIDIA Vulkan ICD 以支持 Vulkan
- `--device /dev/input` 和 `--group-add $(getent group input | cut -d: -f3)`：允许访问输入设备
- `--net=host`：使用宿主机网络
- `-v /path/to/Coding:/home/user/Coding`：将本地工作区挂载到容器中，可选
- `-v ${HOME}/isaaclab_docker/.cache/ov:/home/user/.cache/ov` 和 `-v ${HOME}/isaaclab_docker/.nvidia-omniverse:/home/user/.nvidia-omniverse`：挂载缓存目录以持久化资源

如果退出容器后想再次进入：

```bash
docker start ${USER}-isaaclab
docker exec -it ${USER}-isaaclab zsh
```

## GitHub Actions

该仓库包含 Dockerfile 自动构建工作流 [`.github/workflows/docker-isaaclab.yml`](../../.github/workflows/docker-isaaclab.yml) 上传到 [Docker Hub - wtyyy/isaaclab](https://hub.docker.com/repository/docker/wtyyy/isaaclab)：

- 触发条件：推送到 `main` 或 `master`，且改动路径包含 `docker/isaaclab/**`、`docker/ubuntu/**`
- 默认输出镜像：
  - `wtyyy/isaaclab:2.3.2.post1`
- 手动发布：
  - 触发 `workflow_dispatch`
  - 填写 `isaaclab_version`
  - 输出变为 `wtyyy/isaaclab:<isaaclab_version>`

运行工作流前需要配置以下仓库 secrets：

- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`
