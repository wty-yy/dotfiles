## CHANGELOG

- 2026.3.30:
    - 新增[isaaclab/Dockerfile](./docker/isaaclab/Dockerfile)
    - 新增[reencode_videos.py](./scripts/reencode_videos.py)使用ffmpeg重新编码视频文件
- 2026.3.11：更新[docker/ubuntu_p10k](./docker/ubuntu_p10k/)增加了一个基于Ubuntu 24.04的Docker镜像，内置了`zsh`、`vim`，其中`zsh`包含`p10k`主题以及相关插件，`vim`使用了`gruvbox`主题。
- 2026.3.8：更新[codex_vscode_extension_add_proxy](./scripts/codex_vscode_extension_add_proxy.sh)自动修改vscode extension中的codex，为其添加指定端口的proxy端口代理，支持`~/.vscode, ~/.vscode-server, ~/.vscode-server-container`三个文件夹下的自动修改
- 2026.3.3：更新[auto_remote_config](./scripts/auto_remote_config/)能自动加入zerotier，打开sshd，安装可视化界面，从而在zerotier的局域网下可以直接通过ssh和noVNC控制本机
