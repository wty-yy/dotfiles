#!/usr/bin/env python3
import os
import sys
import argparse
import subprocess
import re
import pwd
import time

# Define ANSI color codes for terminal output
class Colors:
    CMD = '\033[96m'      # Cyan for commands
    OUT = '\033[90m'      # Dark Gray for real-time output
    ERR = '\033[91m'      # Red for errors
    INFO = '\033[93m'     # Yellow for step information
    SUCCESS = '\033[92m'  # Green for success messages
    RESET = '\033[0m'     # Reset to default terminal color

def run_cmd(cmd, env=None, check=True):
    """Executes shell commands, printing the command and its real-time output in color."""
    print(f"{Colors.CMD}>>> Executing: {cmd}{Colors.RESET}")
    
    try:
        process = subprocess.Popen(
            cmd,
            shell=True,
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, 
            text=True,
            bufsize=1 
        )
        
        output_lines = []
        for line in process.stdout:
            stripped_line = line.rstrip()
            output_lines.append(stripped_line)
            print(f"{Colors.OUT}    | {stripped_line}{Colors.RESET}")
            
        process.wait()
        
        if check and process.returncode != 0:
            print(f"{Colors.ERR}[ERROR] Command failed with exit code {process.returncode}{Colors.RESET}")
            sys.exit(1)
            
        return "\n".join(output_lines)
        
    except Exception as e:
        print(f"{Colors.ERR}[ERROR] Execution exception: {e}{Colors.RESET}")
        if check:
            sys.exit(1)
        return None

def check_root():
    """Ensure the script is run with root privileges."""
    if os.geteuid() != 0:
        print(f"{Colors.ERR}[ERROR] This script must be run as root. Please use sudo.{Colors.RESET}")
        sys.exit(1)

def get_real_user():
    """Get the real user who invoked sudo to place files in their home directory."""
    sudo_user = os.environ.get('SUDO_USER')
    if not sudo_user:
        print(f"{Colors.ERR}[ERROR] Could not determine the original user. Please run via 'sudo python3 ...'{Colors.RESET}")
        sys.exit(1)
    
    user_info = pwd.getpwnam(sudo_user)
    return sudo_user, user_info.pw_dir

def main():
    check_root()
    
    parser = argparse.ArgumentParser(description="Automate ZeroTier, SSH, x11vnc, and noVNC setup.")
    # Made zt_network_id optional
    parser.add_argument("--zt_network_id", required=False, default="", help="Your ZeroTier Network ID (Leave empty to skip ZeroTier)")
    parser.add_argument("--vnc_password", required=True, help="Password for VNC access")
    args = parser.parse_args()

    real_user, user_home = get_real_user()
    print(f"{Colors.INFO}[*] Detected target user: {real_user} (Home: {user_home}){Colors.RESET}")

    # Step 1: Install ZeroTier and join network (Conditional)
    if args.zt_network_id:
        print(f"\n{Colors.INFO}[Step 1] Installing ZeroTier and joining network...{Colors.RESET}")
        if not os.path.exists("/usr/sbin/zerotier-cli"):
            run_cmd("curl -s https://install.zerotier.com | bash")
        else:
            print(f"{Colors.OUT}[*] ZeroTier is already installed.{Colors.RESET}")
        
        run_cmd(f"zerotier-cli join {args.zt_network_id}")
        print(f"{Colors.SUCCESS}[+] Successfully requested to join ZeroTier network: {args.zt_network_id}{Colors.RESET}")
    else:
        print(f"\n{Colors.INFO}[Step 1] Skipping ZeroTier setup (No Network ID provided).{Colors.RESET}")

    # Step 2: Enable sshd service
    print(f"\n{Colors.INFO}[Step 2] Installing and enabling SSH service...{Colors.RESET}")
    run_cmd("apt-get update && apt-get install -y openssh-server")
    run_cmd("systemctl enable --now ssh")
    print(f"{Colors.SUCCESS}[+] SSH service enabled and started.{Colors.RESET}")

    # Step 3: Install x11vnc and set password
    print(f"\n{Colors.INFO}[Step 3] Installing x11vnc and setting up password...{Colors.RESET}")
    run_cmd("apt-get install -y x11vnc")
    run_cmd(f"x11vnc -storepasswd {args.vnc_password} /etc/x11vnc.pass")
    run_cmd("chmod 644 /etc/x11vnc.pass")
    print(f"{Colors.SUCCESS}[+] x11vnc installed and password saved to /etc/x11vnc.pass.{Colors.RESET}")

    # Step 4: Install noVNC
    print(f"\n{Colors.INFO}[Step 4] Installing noVNC...{Colors.RESET}")
    novnc_dir = "/opt/noVNC"
    if not os.path.exists(novnc_dir):
        run_cmd("apt-get install -y git websockify")
        run_cmd(f"git clone https://github.com/novnc/noVNC.git {novnc_dir}")
    else:
        print(f"{Colors.OUT}[*] noVNC already cloned in /opt/noVNC.{Colors.RESET}")
    print(f"{Colors.SUCCESS}[+] noVNC ready.{Colors.RESET}")

    # Step 5: Detect monitors using xrandr (Updated DISPLAY to :1, removed XAUTHORITY)
    print(f"\n{Colors.INFO}[Step 5] Detecting connected monitors...{Colors.RESET}")
    env = os.environ.copy()
    env["DISPLAY"] = ":1" 
    
    xrandr_out = run_cmd("xrandr | grep -w connected", env=env, check=False)
    if not xrandr_out:
        print(f"{Colors.ERR}[ERROR] Failed to detect monitors. Is the GUI running and user logged in?{Colors.RESET}")
        sys.exit(1)

    monitors = []
    pattern = re.compile(r"^([a-zA-Z0-9\-]+)\s+connected.*?\b(\d+x\d+\+\d+\+\d+)\b")
    for line in xrandr_out.split('\n'):
        match = pattern.search(line)
        if match:
            monitors.append({
                "name": match.group(1),
                "geometry": match.group(2)
            })

    if not monitors:
        print(f"{Colors.ERR}[ERROR] No monitors with valid geometries found.{Colors.RESET}")
        sys.exit(1)
        
    print(f"{Colors.SUCCESS}[+] Found {len(monitors)} monitor(s):{Colors.RESET}")
    for i, m in enumerate(monitors):
        print(f"{Colors.SUCCESS}    - Screen {i+1}: {m['name']} ({m['geometry']}){Colors.RESET}")

    # Step 6: Generate the launcher script
    print(f"\n{Colors.INFO}[Step 6] Generating x11vnc + noVNC wrapper script...{Colors.RESET}")
    local_bin_dir = f"{user_home}/.local/bin"
    os.makedirs(local_bin_dir, exist_ok=True)
    run_cmd(f"chown -R {real_user}:{real_user} {user_home}/.local")

    script_path = f"{local_bin_dir}/start_multivnc.sh"
    
    script_content = [
        "#!/bin/bash",
        "",
        "# Cleanup function executed upon receiving exit signals",
        "cleanup() {",
        '    echo -e "\\n[!] Received Ctrl+C (SIGINT), shutting down all VNC and noVNC services..."'
    ]
    
    kill_vars = []
    for i in range(len(monitors)):
        kill_vars.extend([f"$VNC{i+1}_PID", f"$NOVNC{i+1}_PID"])
    
    script_content.append(f"    kill {' '.join(kill_vars)} 2>/dev/null")
    script_content.append('    echo "[✔] All services successfully closed."')
    script_content.append("    exit 0")
    script_content.append("}")
    script_content.append("")
    script_content.append("# Trap SIGINT (Ctrl+C) and SIGTERM signals")
    script_content.append("trap cleanup SIGINT SIGTERM")
    script_content.append("")

    base_vnc_port = 5900
    base_novnc_port = 6080

    for i, monitor in enumerate(monitors):
        vnc_port = base_vnc_port + i
        novnc_port = base_novnc_port + i
        geo = monitor["geometry"]
        
        script_content.extend([
            f"echo '[*] Starting x11vnc for Screen {i+1} ({geo}) on port {vnc_port}...'",
            f"/usr/bin/x11vnc -auth guess -nodpms -capslock -forever -loop -noxdamage -repeat -rfbauth /etc/x11vnc.pass -rfbport {vnc_port} -shared -clip {geo} > /dev/null 2>&1 &",
            f"VNC{i+1}_PID=$!",
            "",
            f"echo '[*] Starting noVNC for Screen {i+1} ({novnc_port} -> {vnc_port})...'",
            f"{novnc_dir}/utils/novnc_proxy --vnc localhost:{vnc_port} --listen {novnc_port} > /dev/null 2>&1 &",
            f"NOVNC{i+1}_PID=$!",
            ""
        ])

    script_content.extend([
        'echo "======================================================"',
        'echo "[✔] All VNC services are running in the background!"'
    ])
    for i in range(len(monitors)):
        script_content.append(f'echo "Screen {i+1} Address: http://127.0.0.1:{base_novnc_port + i}/vnc.html"')
    script_content.extend([
        'echo "Keep this terminal open, press Ctrl+C to close all services."',
        'echo "======================================================"',
        'wait'
    ])

    with open(script_path, "w") as f:
        f.write("\n".join(script_content) + "\n")
    
    os.chmod(script_path, 0o755)
    run_cmd(f"chown {real_user}:{real_user} {script_path}")
    print(f"{Colors.SUCCESS}[+] Script generated at {script_path}{Colors.RESET}")

    # Step 7: Create Systemd Service (Updated DISPLAY to :1, removed XAUTHORITY)
    print(f"\n{Colors.INFO}[Step 7] Configuring systemd service for auto-start...{Colors.RESET}")
    service_path = "/etc/systemd/system/multivnc.service"
    service_content = f"""[Unit]
Description=Multi-Screen x11vnc and noVNC Service
After=network.target graphical.target

[Service]
Type=simple
User={real_user}
Environment=DISPLAY=:1
ExecStart={script_path}
Restart=always
RestartSec=5
TimeoutStopSec=10

[Install]
WantedBy=graphical.target
"""
    with open(service_path, "w") as f:
        f.write(service_content)

    run_cmd("systemctl daemon-reload")
    run_cmd("systemctl enable --now multivnc.service")
    print(f"{Colors.SUCCESS}[+] systemd service 'multivnc.service' enabled and started.{Colors.RESET}")

    # Step 8: Get Connection IP
    print(f"\n{Colors.INFO}[Step 8] Gathering connection info...{Colors.RESET}")
    
    access_ip = "YOUR_SERVER_IP"
    if args.zt_network_id:
        time.sleep(2) 
        ip_out = run_cmd("ip -brief addr show | grep zt", check=False)
        if ip_out:
            match = re.search(r"(\d+\.\d+\.\d+\.\d+)", ip_out)
            if match:
                access_ip = match.group(1)
    else:
        # Try to grab the primary local IP if ZeroTier is skipped
        ip_out = run_cmd("hostname -I", check=False)
        if ip_out:
            access_ip = ip_out.split()[0]

    print(f"\n{Colors.SUCCESS}" + "="*65)
    print("                 SETUP COMPLETED SUCCESSFULLY!                ")
    print("="*65)
    print(f"Server IP Address   : {access_ip}")
    if args.zt_network_id:
        print("                      (Approve in ZeroTier Admin Panel if needed)")
    print(f"VNC Access Password : {args.vnc_password}")
    print("-" * 65)
    
    for i, m in enumerate(monitors):
        novnc_port = base_novnc_port + i
        print(f"Screen {i+1} ({m['name']}) URL : http://{access_ip}:{novnc_port}/vnc.html")
        
    print("-" * 65)
    print(f"{Colors.INFO}File Locations:{Colors.SUCCESS}")
    print(f"  - noVNC Directory  : /opt/noVNC")
    print(f"  - Wrapper Script   : {script_path}")
    print(f"\n{Colors.INFO}Service Management:{Colors.SUCCESS}")
    print(f"  - Check Status     : sudo systemctl status multivnc.service")
    print(f"  - Restart Service  : sudo systemctl restart multivnc.service")
    print("="*65 + f"{Colors.RESET}")

if __name__ == "__main__":
    main()
