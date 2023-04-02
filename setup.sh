#!/bin/bash
for i in bashrc vimrc gitconfig gitignore_global oh-my-zsh zshrc vim; do
	ln -sf $(pwd)/$i ~/.$i
done

rm ~/.tmux.conf
ln -sf $(pwd)/.tmux/.tmux.conf ~/.tmux.conf
cp $(pwd)/.tmux/.tmux.conf.local ~/.tmux.conf.local

