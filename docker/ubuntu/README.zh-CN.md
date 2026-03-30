# ubuntu

[English Version](./README.md)

## 目录

- [概述](#概述)
- [构建](#构建)
- [运行](#运行)
- [包含内容](#包含内容)
- [目录结构](#目录结构)
- [说明](#说明)

## 概述

这是一个支持 Ubuntu `24.04` 与 `22.04` 的精简 Docker 镜像，包含：

- `zsh`
- 带仓库 `.tmux` 配置的 `tmux`
- `powerlevel10k`
- `zsh-autosuggestions`
- `zsh-syntax-highlighting`
- 带 `gruvbox` 配色的 `vim`
- 时区固定为 `Asia/Shanghai`

这套配置没有安装 `oh-my-zsh`，而是直接在 `.zshrc` 中加载 `powerlevel10k`。

## 构建

在当前目录执行（默认基础镜像是 `ubuntu:24.04`）：

```bash
docker build -t wtyyy/ubuntu:24.04 .
```

构建 Ubuntu 22.04 版本：

```bash
docker build --build-arg UBUNTU_TAG=22.04 -t wtyyy/ubuntu:22.04 .
```

## 运行

运行 Ubuntu 24.04 并对齐宿主机 UID/GID：

```bash
docker run -it --rm \
  --name ${USER}-ubuntu \
  -e DEFAULT_UID="$(id -u)" \
  -e DEFAULT_GID="$(id -g)" \
  wtyyy/ubuntu:24.04
```

带可视化界面支持的运行示例：

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
  -v /usr/share/vulkan/icd.d/nvidia_icd.json:/usr/share/vulkan/icd.d/nvidia_icd.json:ro \
  --net=host \
  wtyyy/ubuntu:24.04 zsh
```

如果需要挂载本地目录到容器，可以添加 `-v /path/to/Coding/:/home/user/Coding`。

## 包含内容

- 命令行提示符由 `powerlevel10k` 提供。
- `tmux` 会直接使用仓库里的 `.tmux.conf` 和 `.tmux.conf.local`。
- `gitstatusd` 会在镜像构建阶段下载好，因此首次进入 shell 时不需要再额外等待下载。
- 目录颜色使用与仓库根目录 `zshrc` 相同的 `dircolors` 覆盖规则，目录显示为青色。
- `vim` 使用一份最小配置，启用 `gruvbox`、行号、相对行号、当前行高亮和 4 空格缩进。
- 容器时区固定为 `Asia/Shanghai`。
- 容器启动时会创建固定的 `user` 用户，把 `/root` 下预先准备好的 shell/vim 配置同步到 `/home/user`，然后再切换过去。
- 新用户会获得免密码 `sudo`，这是保留普通用户 shell 体验的同时最接近 root 权限的做法。

## 目录结构

- [Dockerfile](/home/yy/Coding/GitHub/dotfiles/docker/ubuntu/Dockerfile)：镜像定义
- [overlay/.zshrc](/home/yy/Coding/GitHub/dotfiles/docker/ubuntu/overlay/.zshrc)：shell 配置
- [overlay/.p10k.zsh](/home/yy/Coding/GitHub/dotfiles/docker/ubuntu/overlay/.p10k.zsh)：p10k 提示符配置
- [overlay/.tmux.conf](/home/yy/Coding/GitHub/dotfiles/docker/ubuntu/overlay/.tmux.conf)：tmux 基础配置
- [overlay/.tmux.conf.local](/home/yy/Coding/GitHub/dotfiles/docker/ubuntu/overlay/.tmux.conf.local)：tmux 本地覆盖配置
- [overlay/.vimrc](/home/yy/Coding/GitHub/dotfiles/docker/ubuntu/overlay/.vimrc)：最小 vim 配置
- [overlay/gruvbox.vim](/home/yy/Coding/GitHub/dotfiles/docker/ubuntu/overlay/gruvbox.vim)：vim 配色文件
- [overlay/setup-docker.sh](/home/yy/Coding/GitHub/dotfiles/docker/ubuntu/overlay/setup-docker.sh)：构建阶段执行的安装脚本

## 说明

- 构建时需要联网，因为 `powerlevel10k` 和 zsh 插件是在镜像构建阶段通过 Git 拉取的。
- 如果 GitHub 网络不稳定，`setup-docker.sh` 已经包含 clone 和 `gitstatus` 下载重试逻辑。
- 上面的运行示例已经默认传入 `DEFAULT_UID` 和 `DEFAULT_GID`，这样挂载文件的属主会尽量和宿主机保持一致。

### GitHub Actions（发布到 Docker Hub）

仓库已包含工作流 `.github/workflows/docker-ubuntu.yml`。

- 触发条件：推送到 `main` 或 `master` 且改动 `docker/ubuntu/**`（或手动触发 `workflow_dispatch`）
- 输出镜像：
  - `wtyyy/ubuntu:24.04`
  - `wtyyy/ubuntu:22.04`

在仓库 Secrets 中先配置：

- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`（Docker Hub Access Token）
