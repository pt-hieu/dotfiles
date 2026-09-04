#!/bin/bash
# Symlink dotfiles to home directory

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Wezterm
ln -sf "$DOTFILES_DIR/wezterm/wezterm.lua" ~/.wezterm.lua

# Zsh
ln -sf "$DOTFILES_DIR/zsh/zshrc" ~/.zshrc
ln -sf "$DOTFILES_DIR/zsh/p10k.zsh" ~/.p10k.zsh

# Git
ln -sf "$DOTFILES_DIR/git/gitconfig" ~/.gitconfig

# Scripts
mkdir -p ~/.local/bin
ln -sf "$DOTFILES_DIR/scripts/claude-idle-sleep.sh" ~/.local/bin/claude-idle-sleep
ln -sf "$DOTFILES_DIR/scripts/cpu-hogs.sh" ~/.local/bin/cpu-hogs

echo "Dotfiles installed!"
