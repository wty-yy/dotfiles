#!/bin/bash
for i in bashrc vimrc; do
	rm ~/.$i
	ln -s $(pwd)/$i ~/.$i
done

