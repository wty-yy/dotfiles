<div align="center">
  <h1>Kitty Setup</h1>
  <p><strong>Ubuntu GNOME 的 Kitty 安装与桌面集成脚本</strong></p>
  <p><a href="README.md">🌎 English</a>&nbsp;&nbsp;·&nbsp;&nbsp;<strong>🇨🇳 中文</strong></p>
</div>

## 使用

将 `scripts/kitty/` 复制到新电脑即可独立使用，无需完整 dotfiles 仓库。以普通用户在 Ubuntu GNOME 桌面终端运行。系统依赖和默认终端设置按需使用 `sudo`。

```bash
cd ~/Coding/GitHub/dotfiles/scripts/kitty
./install.sh
# 1–7 切换选项，第 7 项为卸载，a 全选，n 全不选，Enter 开始，q 退出

./install.sh --all --dry-run  # 查看全部步骤，不修改系统
./install.sh --all           # 跳过选择界面，全部安装
./install.sh --steps desktop,path,shortcut
./install.sh --steps config  # 仅覆盖配置并安装字体
./install.sh --uninstall     # 卸载 Kitty 并还原脚本改动
./install.sh --uninstall --yes  # 跳过确认直接卸载
```

## 常用快捷键

日常只需记住 `Ctrl+Alt+T` 打开终端。鼠标选中即复制，无需另按复制键。tmux 内直接拖拽即可复制；无法复制时，按住 `Shift` 并用鼠标左键选中。

| 快捷键 | 功能 |
| --- | --- |
| `Ctrl+Alt+T` | 打开终端（GNOME 全局） |
| `Ctrl+Shift+T` | 新建分页 |
| `Alt+1` … `Alt+9` | 切换到第 1–9 个分页 |
| `Ctrl+Shift+R` | 重命名当前分页 |
| `Ctrl+Shift+Q` | 关闭当前分页 |

## 安装项目

六项默认全选，执行时先安装所需依赖，再依次处理下载、PATH、菜单、快捷键、右键菜单和配置。第 7 项或 `--uninstall` 选择卸载，与安装步骤互斥。

| 步骤 | 内容 |
| --- | --- |
| `download` | 使用官方脚本安装或更新最新正式版到 `~/.local/kitty.app`，安装后不启动窗口 |
| `desktop` | 注册 `kitty.desktop`、`kitty-open.desktop`，设置图标和绝对执行路径，更新菜单缓存 |
| `path` | 创建 `~/.local/bin/kitty`、`kitten` 软链接，为 `.profile`、`.bashrc`、`.zprofile`、`.zshrc` 添加去重的 PATH 配置 |
| `shortcut` | 将 `x-terminal-emulator` 设为 Kitty，配置 GNOME 的 `Ctrl+Alt+T`，将 `kitty.desktop` 放在 `xdg-terminals.list` 首位 |
| `context` | 安装 `nautilus-open-any-terminal` 0.8.3 及依赖，配置 Open Kitty Here，在当前目录打开新窗口 |
| `config` | 覆盖为随脚本保存的 `kitty.conf`；优先安装仓库 `fonts/` 中的 CaskaydiaCove Nerd Font，缺失时下载 v3.5.1 |

未选择 `download` 时，桌面集成步骤要求官方安装目录中已有 Kitty。单独安装右键菜单时需要已有 `kitty` 命令，或同时选择 `path`。快捷键和右键菜单需要当前 GNOME 桌面会话。

菜单注册会提供应用列表入口；固定到 Dock 可在 GNOME 中手动操作。`kitty-open.desktop` 同时注册文件和 URL 打开能力。`shortcut` 会修改系统默认终端，其他用户也可能受其影响；已有自定义快捷键若占用 `Ctrl+Alt+T`，需在 GNOME 设置中解除冲突。

## 配置与备份

- `kitty.conf` 保存当前机器的完整配置，之后可直接在仓库中编辑。
- 仓库字体 `fonts/Caskaydia Cove Nerd Font Complete.ttf` 不存在时，`config` 从 Nerd Fonts release 下载 CaskaydiaCove Nerd Font v3.5.1，并将其中 TTF 安装到用户字体目录。
- 配置包含 15 号字体、选择即复制、顶部标签栏、标签切换及全屏快捷键。
- 覆盖已有文件前自动备份至 `${XDG_STATE_HOME:-~/.local/state}/kitty-setup/backups/时间戳.随机后缀/`；内容未变的文件不重复覆盖。
- `files/` 下按原绝对路径保存文件；GNOME 设置和原默认终端信息另存为文本快照。
- 用户配置和数据目录遵循 `XDG_CONFIG_HOME`、`XDG_DATA_HOME`。Kitty 程序固定安装至 `~/.local/kitty.app`。
- 完成后注销并重新登录，使桌面 PATH 和 Nautilus 插件生效；新开的 Kitty 窗口读取新配置。
- 再次执行 `download` 可更新 Kitty；脚本不设置后台自动更新。

## 卸载

TUI 第 7 项或 `--uninstall` 会移除 `~/.local/kitty.app`、shell PATH 片段、`kitty`、`kitten` 软链接、菜单项、Nautilus 插件、配置和已安装字体。有历史备份的文件恢复原文件，其余已安装文件直接删除。`x-terminal-emulator` 原选项和 GNOME 终端设置在存在快照时一并还原。被删除或替换的文件会先复制到新的备份目录，结束时打印其路径。

参考：[Kitty 官方安装与桌面集成](https://sw.kovidgoyal.net/kitty/binary/)、[Nautilus 插件](https://github.com/Stunkymonkey/nautilus-open-any-terminal)。
