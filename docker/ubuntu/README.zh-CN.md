# Ubuntu Docker Image

[English](./README.md) | 中文

## 目录

- [概览](#概览)
- [构建](#构建)
- [运行](#运行)
- [GitHub Actions](#github-actions)

## 概览

精简版 Ubuntu Docker 镜像，支持 `24.04` 和 `22.04`，包含：

- `zsh`，预装 `powerlevel10k` 和常用插件
- `tmux`，使用仓库里的 `.tmux` 配置
- `vim`，使用 `gruvbox`
- 时区为 `Asia/Shanghai`
- 支持通过 `DEFAULT_UID` 和 `DEFAULT_GID` 指定运行用户，尤其在挂载宿主机目录时，**可让新建文件保持宿主机用户权限**

## 构建

在当前目录的上一级 `docker` 下执行，默认基础镜像为 `ubuntu:24.04`：

```bash
cd docker
docker build -t wtyyy/ubuntu:24.04 ubuntu
```

构建 Ubuntu 22.04：

```bash
docker build --build-arg UBUNTU_TAG=22.04 -t wtyyy/ubuntu:22.04 ubuntu
```

## 运行

### 基础示例

按宿主机 UID/GID 对齐运行 Ubuntu 24.04：

```bash
docker run -it --rm \
  --name "${USER}-ubuntu" \
  -e DEFAULT_UID="$(id -u)" \
  -e DEFAULT_GID="$(id -g)" \
  wtyyy/ubuntu:24.04
```

- `-it`：交互终端
- `--rm`：退出后自动删除容器
- `--name`：容器名称
- `-e DEFAULT_UID` 和 `-e DEFAULT_GID`：传入宿主机用户 UID/GID，用于文件权限对齐

以 root 运行：

```bash
docker run -it --rm \
  --name "${USER}-ubuntu-root" \
  -u 0 \
  wtyyy/ubuntu:24.04
```

### 渲染示例

> 先安装 [`nvidia-container-toolkit`](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)，才能在 Docker 中启用 NVIDIA GPU 支持。

带 X11 图形界面、NVIDIA GPU、Vulkan、host 网络和输入设备的普通用户示例：

```bash
docker run -it --name "${USER}-ubuntu" \
  -e DEFAULT_UID="$(id -u)" \
  -e DEFAULT_GID="$(id -g)" \
  -e DISPLAY \
  --gpus all \
  -e NVIDIA_DRIVER_CAPABILITIES=all \
  -e "__NV_PRIME_RENDER_OFFLOAD=1" \
  -e "__GLX_VENDOR_LIBRARY_NAME=nvidia" \
  -v /etc/vulkan/icd.d/nvidia_icd.json:/etc/vulkan/icd.d/nvidia_icd.json:ro \
  -v "/tmp/.X11-unix:/tmp/.X11-unix" \
  --device /dev --group-add $(getent group input | cut -d: -f3) \
  --net=host \
  wtyyy/ubuntu:24.04 zsh
```

- `-e DISPLAY`：指定 X11 转发显示
- `--gpus all`：启用全部 GPU
- NVIDIA 环境变量用于 GPU 渲染和 Vulkan 支持
  - `-e NVIDIA_DRIVER_CAPABILITIES=all`：启用全部 NVIDIA 驱动能力
  - `-e "__NV_PRIME_RENDER_OFFLOAD=1"`：用于 NVIDIA PRIME render offload
  - `-e "__GLX_VENDOR_LIBRARY_NAME=nvidia"`：使用 NVIDIA GLX 库
  - `-v /etc/vulkan/icd.d/nvidia_icd.json:/etc/vulkan/icd.d/nvidia_icd.json:ro`：挂载 NVIDIA Vulkan ICD 以支持 Vulkan
- `-v "/tmp/.X11-unix:/tmp/.X11-unix"`：挂载 X11 socket 以支持 GUI
- `--device /dev`：允许访问全部设备
- `--group-add $(getent group input | cut -d: -f3)`：允许访问输入设备
- `--net=host`：使用宿主机网络

如果需要挂载本地工作目录，可追加：

```bash
-v /path/to/Coding/:/home/user/Coding
```

退出后重新进入已有容器：

```bash
docker start ${USER}-ubuntu
docker exec -it ${USER}-ubuntu zsh
```

## GitHub Actions

该仓库包含 Dockerfile 自动构建工作流 [`.github/workflows/docker-ubuntu.yml`](../../.github/workflows/docker-ubuntu.yml) 上传到 [Docker Hub - wtyyy/ubuntu](https://hub.docker.com/repository/docker/wtyyy/ubuntu)。

- 触发条件：推送到 `main` 或 `master`，且改动路径包含 `docker/ubuntu/**`
- 输出镜像：
  - `wtyyy/ubuntu:24.04`
  - `wtyyy/ubuntu:22.04`

运行工作流前需要配置以下仓库 secrets：

- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`（Docker Hub access token）
