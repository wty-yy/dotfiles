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
docker build -t ubuntu-test .
```

构建 Ubuntu 22.04 版本：

```bash
docker build --build-arg UBUNTU_TAG=22.04 -t ubuntu-test:22.04 .
```

## GitHub Actions（发布到 Docker Hub）

仓库已包含工作流 `.github/workflows/docker-ubuntu.yml`。

- 触发条件：推送到 `main` 且改动 `docker/ubuntu/**`（或手动触发 `workflow_dispatch`）
- 输出镜像：
  - `wtyyy/ubuntu:24.04`
  - `wtyyy/ubuntu:22.04`

在仓库 Secrets 中先配置：

- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`（Docker Hub Access Token）

## 运行

启动一个交互式 shell：

```bash
docker run -it --rm --name ${USER}-test ubuntu-test zsh
```

如果希望把当前工作目录挂载进容器：

```bash
docker run -it --rm \
  --name ${USER}-test \
  -v "$(pwd)":/workspace \
  -w /workspace \
  ubuntu-test zsh
```

## 包含内容

- 命令行提示符由 `powerlevel10k` 提供。
- `gitstatusd` 会在镜像构建阶段下载好，因此首次进入 shell 时不需要再额外等待下载。
- 目录颜色使用与仓库根目录 `zshrc` 相同的 `dircolors` 覆盖规则，目录显示为青色。
- `vim` 使用一份最小配置，启用 `gruvbox`、行号、相对行号、当前行高亮和 4 空格缩进。

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
