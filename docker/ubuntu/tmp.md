# 介绍
包含基础工具 `vim git zsh tmux curl`，终端用p10k主题，时区调整为ShangHai，镜像默认进入`/home/user`，自动确定用户UID/GID，挂载创建的文件和用户权限一致

可基于该仓库配置conda或uv环境，安装pytorch，isaacsim 4.x

# 安装方法

- Ubuntu22.04: `docker pull wtyyy/ubuntu:22.04`
- Ubuntu24.04: `docker pull wtyyy/ubuntu:24.04`

**Nvidia驱动**，安装nvidia-container-toolkit
- 官网 https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html
- 镜像 https://mirrors.ustc.edu.cn/help/libnvidia-container.html

# 启动指令（以ubuntu22.04为例）
## 无X11渲染
```bash
docker run --name ${USER} --gpus all --net=host -it wtyyy/ubuntu:24.04 zsh
```
可选挂载路径
```bash
-v ${HOME}/Coding:/root/Coding
```

启动代理, 已修改`~/.zshrc`, 终端直接执行`proxy_on`即可将端口转发到`127.0.0.1:7890`, 执行`proxy_off`即可关闭代理, 需要修改端口号请修改`~/.zshrc`文件.

## Nvidia驱动+X11

X11渲染需宿主机开放权限`xhost +local:docker`

```bash
docker run -it --name ${USER} \
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

测试X11和显卡渲染指令

```bash
sudo apt update && sudo apt install -y mesa-utils vulkan-tools x11-apps
xclock  # 测试X11渲染
glxinfo | grep renderer  # 查看X11驱动
vkcube  # 测试vulkan渲染
```

# IsaacSim额外所需库
```bash
sudo apt update && sudo apt install -y libgomp1 libglu1
```