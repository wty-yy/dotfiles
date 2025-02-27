# cd ~
# 设置vi-mode模式
# bindkey -v

# 修改zsh缓存文件位置
export ZSH_COMPDUMP=$ZSH/cache/.zcompdump-$HOST

# Isaac Sim
# export OMNI_KIT_ACCEPT_EULA=YES

# 修改zsh文件夹颜色 https://unix.stackexchange.com/questions/236724/changing-directory-color-with-zsh-prezto
export SHELL=/usr/bin/zsh  # 避免docker中没有SHELL环境变量报错
eval $(dircolors -p | sed -e 's/DIR 01;34/DIR 01;36/' | dircolors /dev/stdin)

# LaTex
# export PATH=/usr/local/texlive/2021/bin/x86_64-linux:$PATH
# export PATH=/usr/local/texlive/2021/texmf-dist/scripts/latexindent:$PATH
# export MANPATH=/usr/local/texlive/2021/texmf-dist/doc/man:$MANPATH
# export INFOPATH=/usr/local/texlive/2021/texmf-dist/doc/info:$INFOPATH

# Fcitx5
# export XMODIFIERS="@im=fcitx"
# export GTK_IM_MODULE=fcitx
# export QT_IM_MODULE=fcitx

# CUDA
# export PATH=/usr/local/cuda/bin:$PATH
# export PATH=/usr/local/cuda/extras/CUPTI/lib64:$PATH
# export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
# export LD_LIBRARY_PATH=/usr/local/cuda/extras/CUPTI/lib64:$LD_LIBRARY_PATH
# export CUDA_HOME=/usr/local/cuda:$CUDA_HOME

# setup nvm
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm

# 解决WSL2中 can't find libcudnn shared objects 问题
# https://github.com/pytorch/pytorch/issues/85774
# alias fix_libcuda='
# sudo rm /usr/lib/wsl/lib/libcuda.so.2
# sudo rm /usr/lib/wsl/lib/libcuda.so
# sudo ln -s /usr/lib/wsl/lib/libcuda.so.1.1 /usr/lib/wsl/lib/libcuda.so
# sudo ln -s /usr/lib/wsl/lib/libcuda.so.1.1 /usr/lib/wsl/lib/libcuda.so.1
# sudo ldconfig
# '

# Mujoco
# export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/home/yy/.mujoco/mujoco210/bin
# export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib/nvidia

# Ubuntu24.04中gedit改名为gnome-text-editor
VERSION_ID=$(grep "VERSION_ID=" /etc/os-release | cut -d '"' -f 2)  # 获取当前系统版本号
if [ "$VERSION_ID" = "24.04" ]; then
    alias gedit='gnome-text-editor'
fi

# tmux 修复tmux utf8显示问题
alias tmux='tmux -u'

# 博客的快捷键
alias blog='~/Documents/blog'
alias post='~/Documents/blog/source/_posts' # 进入文档文件夹
alias hexos='hexo clean && hexo s' # 在本地建立并运行
# hexo g 建立blog
# hexo d 上传到github

if [ -d "$HOME/.local/bin" ] ; then  # 将本地可执行文件加入到路径中
    export PATH=$HOME/.local/bin:$PATH
fi

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH
# export PATH=/home/yy/nodejs/bin:$PATH
# Path to your oh-my-zsh installation.
export TERM="xterm-256color"
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="powerlevel10k/powerlevel10k"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to automatically update without prompting.
# DISABLE_UPDATE_PROMPT="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# Caution: this setting can cause issues with multiline prompts (zsh 5.7.1 and newer seem to work)
# See https://github.com/ohmyzsh/ohmyzsh/issues/5765
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git zsh-syntax-highlighting zsh-autosuggestions vi-mode)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
export EDITOR='vim'
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# 开启代理
function proxy_on(){
    export all_proxy=socks5://127.0.0.1:7891  # 将端口号 7891 填为上述 socks-port
    export http_proxy=http://127.0.0.1:7890  # 将端口号 7890 填为上述 port
    export https_proxy=http://127.0.0.1:7890  # 将端口号 7890 填为上述 port
    echo -e "已开启代理"
}

# 关闭代理
function proxy_off(){
    unset all_proxy
    unset http_proxy
    unset https_proxy
    echo -e "已关闭代理"
}

# 清理缓存 (每次创建docker image使用)
function cleanup_caches() {
  paths=(
    "/var/lib/apt/lists/*"
    ~/.vscode-server
    ~/.zcompdump*
    ~/.bash_history
    ~/.zsh_history
    ~/.gazebo
    ~/.ros
    ~/.rviz2
    ~/.sdformat
    ~/.ignition
  )

  for path in "${paths[@]}"; do
    rm -rf "$path"
    echo "Removed $path"
  done
}

# ROS 自启动
# source /opt/ros/humble/setup.zsh
# ROS2 使用zsh脚本所需修改配置 (保证tab可以弹出提示)
# 参考这个 https://github.com/ros2/ros2cli/issues/534#issuecomment-988824521，修改如下文件
# sudo vim /opt/ros/$ROS_DISTRO/share/rosidl_cli/environment/rosidl-argcomplete.zsh
# 找到15行autoload -U +X compinit && compinit，将其注释掉即可
# 如果上述方法没有用, 还是要运行下面这两句话
# eval "$(register-python-argcomplete3 ros2)"
# eval "$(register-python-argcomplete3 colcon)"
