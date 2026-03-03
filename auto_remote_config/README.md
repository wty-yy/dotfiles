由Python实现，功能如下：
1. 安装ZeroTier并加入指定网络
2. 打开sshd服务
3. 安装x11vnc并设置密码
5. 安装noVNC并自动将每个屏幕的VNC服务转发到不同的端口
4. 根据当前屏幕个数自动配置x11vnc clip范围，完成启动x11vnc+noVNC服务的脚本，放在`${HOME}/.local/bin/`目录下，并添加执行权限，并加入开机自动启动systemd服务
6. 输出每个屏幕的VNC访问地址和密码

该程序进入时候需要通过命令行传入ZeroTier网络ID和VNC访问密码，并支持代理，例如：
```bash
sudo python3 auto_remote_config.py \
    --zt_network_id <your_id> \
    --vnc_password <your_password> \
    --proxy 127.0.0.1:7890
```
程序需要root权限运行，因为需要安装软件包和配置服务，并输出当前执行到哪一步了，代码的全部注释都用英文，输出的文本也用英文，最后显示每个屏幕的VNC访问地址和密码。

step4方案：
得到显示屏个数以及范围
```bash
❯ xrandr | grep -w connected
HDMI-0 connected primary 1920x1080+0+0 (normal left inverted right x axis y axis) 597mm x 336mm
DP-1 connected 1920x1080+1920+0 (normal left inverted right x axis y axis) 527mm x 296mm
```

我这有一个可供参考的x11vnc+noVNC脚本如下（需要对应上面的显示屏个数和分辨率位置修改，并用英文注释和输出内容）
```bash
#!/bin/bash

# 定义清理函数：当收到退出信号时执行
cleanup() {
    echo -e "\n[!] 收到 Ctrl+C (SIGINT)，正在关闭所有 VNC 和 noVNC 服务..."
    
    # 终止所有记录的后台进程 PID
    kill $VNC1_PID $VNC2_PID $NOVNC1_PID $NOVNC2_PID 2>/dev/null
    
    echo "[✔] 所有服务已成功关闭。"
    exit 0
}

# 捕获 SIGINT (Ctrl+C) 和 SIGTERM (终止) 信号，触发 cleanup 函数
trap cleanup SIGINT SIGTERM

echo "[1/4] 启动主屏幕 x11vnc (端口 5900)..."
/usr/bin/x11vnc -auth guess -nodpms -capslock -forever -loop -noxdamage -repeat -rfbauth /etc/x11vnc.pass -rfbport 5900 -shared -clip 2560x1440+1080+480 > /dev/null 2>&1 &
VNC1_PID=$!

echo "[2/4] 启动副屏幕 x11vnc (端口 5901)..."
/usr/bin/x11vnc -auth guess -nodpms -capslock -forever -loop -noxdamage -repeat -rfbauth /etc/x11vnc.pass -rfbport 5901 -shared -clip 1080x1920+0+0 > /dev/null 2>&1 &
VNC2_PID=$!

echo "[3/4] 启动主屏幕 noVNC (6080 -> 5900)..."
/home/hk/wutianyang/Programs/noVNC/utils/novnc_proxy --vnc localhost:5900 --listen 6080 > /dev/null 2>&1 &
NOVNC1_PID=$!

echo "[4/4] 启动副屏幕 noVNC (6081 -> 5901)..."
# 注意：这里帮你把 localhost:5900 修正为了 localhost:5901
/home/hk/wutianyang/Programs/noVNC/utils/novnc_proxy --vnc localhost:5901 --listen 6081 > /dev/null 2>&1 &
NOVNC2_PID=$!

echo "======================================================"
echo "[✔] 所有服务已在后台运行！"
echo "主屏幕地址: http://127.0.0.1:6080/vnc.html"
echo "副屏幕地址: http://127.0.0.1:6081/vnc.html"
echo "请保持此终端开启，随时按 Ctrl+C 即可一键关闭全部服务。"
echo "======================================================"

# 挂起脚本，等待用户的 Ctrl+C 打断
wait
```

Step1的方案如下
```bash
# 1. 创建专门用于官方 ZeroTier 的数据目录
sudo mkdir -p /opt/zerotier-official

# 2. 写入 local.conf 配置文件，修改默认端口为 9994
sudo bash -c 'cat <<EOF > /opt/zerotier-official/local.conf
{
  "settings": {
    "primaryPort": 9994
  }
}
EOF'

# 启动 Docker 容器
sudo docker run -d \
  --name zt-official \
  --restart always \
  --network host \
  --cap-add NET_ADMIN \
  --cap-add SYS_ADMIN \
  --device /dev/net/tun \
  -v /opt/zerotier-official:/var/lib/zerotier-one \
  zerotier/zerotier:latest

# 加入网络
sudo docker exec zt-official zerotier-cli join <ID>
```
