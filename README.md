# My Dotfiles

## Usage

Firstly, install relative packages.

```bash
sudo apt install vim git zsh tmux wget curl
```

Use proxy, if need:
```bash
export https_proxy=http://127.0.0.1:7890  # change proxy id:port
```

Install oh-my-zsh:
```bash
sudo apt install zsh
# China
sh -c "$(wget -O- https://gitee.com/mirrors/oh-my-zsh/raw/master/tools/install.sh)"
# Others
sh -c "$(wget -O- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

Get into the directory, use `chmod` can change the highest access permissions, make `.sh` file can be run.

```sh
cd ~
git clone --depth 1 https://github.com/wty-yy/dotfiles.git
cd dotfiles
chmod 777 setup.sh
sudo ./setup.sh
```

Set zsh as default shell:

```sh
chsh -s $(which zsh)
```

Enjoy command: `vim`, `tmux`, `zsh`

## Content

log out computer and log back in. (https://askubuntu.com/questions/131823/how-to-make-zsh-the-default-shell)

- `.tmux` config: https://github.com/gpakosz/.tmux

  ![.tmux](https://cloud.githubusercontent.com/assets/553208/19740585/85596a5a-9bbf-11e6-8aa1-7c8d9829c008.gif)

- `.vim, .vimrc` config

  ![vim](./assets/vim.png)

- `.bashrc` config: add `ls` and `la` to show files, since we use zsh, so this is not significant.

- `.zshrc, .oh-my-zsh` config: use `p10k` themes (you need change an appropriate font: like [`CaskaydiaCove Nerd Font Complete`](https://github.com/wty-yy/LaTex-Projects/blob/main/Fonts/Caskaydia%20Cove%20Nerd%20Font%20Complete.ttf) or choose one from [nerd-fonts](https://github.com/ryanoasis/nerd-fonts))

  ![zsh](./assets/zsh.png)

- `gitignore_global`: set global ignore files.


