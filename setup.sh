#!/bin/bash
for i in bashrc vimrc; do
	rm ~/.$i
	ln -s ~/dotfiles/$i ~/.$i
done
