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
- `powerlevel10k`
- `zsh-autosuggestions`
- `zsh-syntax-highlighting`
- 带 `gruvbox` 配色的 `vim`

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

启动一个交互式 shell：

```bash
docker run -it --rm --name ${USER}-ubuntu wtyyy/ubuntu:24.04
```

按宿主机 UID/GID 调整固定的 `user` 用户：

```bash
docker run -it --rm \
  --name ${USER}-ubuntu \
  -e DEFAULT_UID="$(id -u)" \
  -e DEFAULT_GID="$(id -g)" \
  wtyyy/ubuntu:24.04
```

如果希望把当前工作目录挂载进容器：

```bash
docker run -it --rm \
  --name ${USER}-ubuntu \
  -e DEFAULT_UID="$(id -u)" \
  -e DEFAULT_GID="$(id -g)" \
  -v "$(pwd)":/home/user/workspace \
  wtyyy/ubuntu:24.04
```

## 包含内容

- 命令行提示符由 `powerlevel10k` 提供。
- `gitstatusd` 会在镜像构建阶段下载好，因此首次进入 shell 时不需要再额外等待下载。
- 目录颜色使用与仓库根目录 `zshrc` 相同的 `dircolors` 覆盖规则，目录显示为青色。
- `vim` 使用一份最小配置，启用 `gruvbox`、行号、相对行号、当前行高亮和 4 空格缩进。
- 容器启动时会创建固定的 `user` 用户，把 `/root` 下预先准备好的 shell/vim 配置同步到 `/home/user`，然后再切换过去。
- 新用户会获得免密码 `sudo`，这是保留普通用户 shell 体验的同时最接近 root 权限的做法。

## 目录结构

- [Dockerfile](/home/yy/Coding/GitHub/dotfiles/docker/ubuntu/Dockerfile)：镜像定义
- [overlay/.zshrc](/home/yy/Coding/GitHub/dotfiles/docker/ubuntu/overlay/.zshrc)：shell 配置
- [overlay/.p10k.zsh](/home/yy/Coding/GitHub/dotfiles/docker/ubuntu/overlay/.p10k.zsh)：p10k 提示符配置
- [overlay/.vimrc](/home/yy/Coding/GitHub/dotfiles/docker/ubuntu/overlay/.vimrc)：最小 vim 配置
- [overlay/gruvbox.vim](/home/yy/Coding/GitHub/dotfiles/docker/ubuntu/overlay/gruvbox.vim)：vim 配色文件
- [overlay/setup-docker.sh](/home/yy/Coding/GitHub/dotfiles/docker/ubuntu/overlay/setup-docker.sh)：构建阶段执行的安装脚本

## 说明

- 构建时需要联网，因为 `powerlevel10k` 和 zsh 插件是在镜像构建阶段通过 Git 拉取的。
- 如果 GitHub 网络不稳定，`setup-docker.sh` 已经包含 clone 和 `gitstatus` 下载重试逻辑。
- Docker 容器本身无法稳定自动识别宿主机 UID/GID；如果你希望挂载文件的属主和宿主机一致，建议在 `docker run` 时传入 `DEFAULT_UID` 和 `DEFAULT_GID`。

### GitHub Actions（发布到 Docker Hub）

仓库已包含工作流 `.github/workflows/docker-ubuntu.yml`。

- 触发条件：推送到 `main` 或 `master` 且改动 `docker/ubuntu/**`（或手动触发 `workflow_dispatch`）
- 输出镜像：
  - `wtyyy/ubuntu:24.04`
  - `wtyyy/ubuntu:22.04`

在仓库 Secrets 中先配置：

- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`（Docker Hub Access Token）
