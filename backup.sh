#!/bin/bash
# Backup script for all dotfiles

# git configurations

cp ~/.gitconfig .
cp ~/.gitconfig-personal .

# obsidian configurations

echo "Please open comment to backup obsidian config"
# cp /Users/quangdinhnguyenpham/Library/Mobile\ Documents/iCloud~md~obsidian/Documents/Persona/.obsidian.vimrc .

# tmux configurations
echo "backup tmux config"
cp ~/.tmux.conf.local .

# zsh config

echo "backup zsh config"
cp ~/.zshrc .
cp ~/.zshenv .
cp ~/.config/zsh/.zimrc .

# wezterm
echo "backup wezterm config"
cp -r ~/.config/wezterm/ .

# aerospace
echo "backup aerospace config"
cp -r ~/.config/aerospace/ .

# ANNE PRO 2 Obinslab config

echo "Please open comment to backup ANNE PRO 2 config"
# cp /Users/destnguyxn/Documents/ANNE\ PRO\ 2.json .

# vimium_c
echo "please copy vimium c config manually"
