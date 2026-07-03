# 清理系统和常用工具缓存目录
rm -rf \
  /var/lib/apt/lists/* \
  ~/.vscode-server \
  ~/.gazebo \
  ~/.ros \
  ~/.rviz3 \
  ~/.sdformat \
  ~/.ignition \
  ~/.cache/pip \
  ~/.cache/huggingface \
  ~/.cache/vscode-cpptools \
  ~/.git-credentials

# 说明：
# /var/lib/apt/lists/*      - apt 包列表缓存
# ~/.vscode-server          - VSCode Server 缓存（远程开发）
# ~/.gazebo                 - Gazebo 仿真缓存
# ~/.ros                    - ROS 配置缓存
# ~/.rviz3                  - RViz 可视化缓存
# ~/.sdformat               - SDF 模型缓存
# ~/.ignition               - Ignition Robotics 缓存
# ~/.cache/pip              - pip 安装包缓存
# ~/.cache/huggingface      - Hugging Face 模型缓存
# ~/.cache/vscode-cpptools  - VsCode cpptools 插件缓存
# ~/.git-credentials        - git 密码凭证
