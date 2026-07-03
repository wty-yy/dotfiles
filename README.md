# My Dotfiles

This repository contains my personal dotfiles, common scripts and docker images.

## Links

- [scripts](./scripts/)
- [docker](./docker/)
- [CHANGELOG.zh-CN](./CHANGELOG.zh-CN.md)

## Dotfiles Usage

Firstly, install relative packages.

```bash
sudo apt install vim git zsh tmux wget curl
```

Get into the directory, use `chmod` can change the highest access permissions, make `.sh` file can be run.

```sh
cd ~
git clone --depth 1 https://github.com/wty-yy/dotfiles.git
cd dotfiles
chmod 777 setup.sh
./setup.sh  # setup for now user
sudo ./setup.sh  # setup for root user
```

Set zsh as default shell:

```sh
chsh -s $(which zsh)
```

Enjoy command: `vim`, `tmux`, `zsh`

If you find that the font and colors do not match the image below, try installing [nerd font](https://www.nerdfonts.com/) on your shell visualization machine.
If you are using Docker containers, please check the following environment variables:

```bash
export TERM="xterm-256color"
apt update && apt install -y locales
update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
export LANG=en_US.UTF-8
```

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
