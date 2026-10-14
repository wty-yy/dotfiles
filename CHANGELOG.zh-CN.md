## CHANGELOG

- 2026.10.14: 新增 [scripts/kitty/install-macos.sh](./scripts/kitty/install-macos.sh)，支持 macOS 安装和更新 Kitty、配置命令行 PATH、安装配置与字体、覆盖前备份及 `--dry-run` 预览
- 2026.10.14: 更新 [scripts/auto_remote_config](./scripts/auto_remote_config/)，改用带 `KeyEventDelay` 补丁的 TigerVNC `1.16.2`，新增多屏服务启动模板、进程自动重试及中英文使用说明
- 2026.10.14: 更新 [scripts/reencode_videos.py](./scripts/reencode_videos.py)，新增 `--rotation` 支持逆时针旋转 `0/90/180/270` 度，并在缩放和裁剪前应用旋转
- 2026.10.14: 新增 [scripts/tinyimg/tinyimg.py](./scripts/tinyimg/tinyimg.py)，通过 TinyPNG API 批量压缩图片，支持并行处理、递归扫描、原图备份、输出后缀、API 密钥保存及用量查询
- 2026.8.13: 新增[scripts/setup_clash.sh](./scripts/setup_clash.sh)自动安装clash-core并配置url自动更新订阅
- 2026.4.8: 新增[scripts/codex_api_config.py](./scripts/codex_api_config.py)为codex配置api的配置文件
- 2026.3.30:
    - 新增[isaaclab/Dockerfile](./docker/isaaclab/Dockerfile)
    - 新增[reencode_videos.py](./scripts/reencode_videos.py)使用ffmpeg重新编码视频文件
- 2026.3.11：更新[docker/ubuntu_p10k](./docker/ubuntu_p10k/)增加了一个基于Ubuntu 24.04的Docker镜像，内置了`zsh`、`vim`，其中`zsh`包含`p10k`主题以及相关插件，`vim`使用了`gruvbox`主题。
- 2026.3.8：更新[codex_vscode_extension_add_proxy](./scripts/codex_vscode_extension_add_proxy.sh)自动修改vscode extension中的codex，为其添加指定端口的proxy端口代理，支持`~/.vscode, ~/.vscode-server, ~/.vscode-server-container`三个文件夹下的自动修改
- 2026.3.3：更新[auto_remote_config](./scripts/auto_remote_config/)能自动加入zerotier，打开sshd，安装可视化界面，从而在zerotier的局域网下可以直接通过ssh和noVNC控制本机
