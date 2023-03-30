# 设置bash的左端
PS1="\w> "
# 配置用户路劲
# export PATH=$PATH:$HOME/anaconda3/bin:$HOME/apps/bin
# export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$HOME/anaconda3/lib:$HOME/anaconda3/envs/tf_gpu/lib

# 设置显示ls相关配置，用la显示完整信息
alias ls='ls --color'
alias la='ls -al --color'

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/home/wty-yy/miniforge3/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/home/wty-yy/miniforge3/etc/profile.d/conda.sh" ]; then
        . "/home/wty-yy/miniforge3/etc/profile.d/conda.sh"
    else
        export PATH="/home/wty-yy/miniforge3/bin:$PATH"
    fi
fi
unset __conda_setup

if [ -f "/home/wty-yy/miniforge3/etc/profile.d/mamba.sh" ]; then
    . "/home/wty-yy/miniforge3/etc/profile.d/mamba.sh"
fi
# <<< conda initialize <<<

