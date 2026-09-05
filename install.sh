#!/bin/bash
# Symlink dotfiles to home directory. Safe to re-run.

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

link() {
  local source="$1" destination="$2"

  if [ -L "$destination" ] && [ "$(readlink "$destination")" = "$source" ]; then
    echo "  ok      $destination"
    return
  fi

  mkdir -p "$(dirname "$destination")"

  # Anything already there that isn't our symlink is the user's own config —
  # move it aside rather than let ln -f delete it.
  if [ -e "$destination" ] || [ -L "$destination" ]; then
    local backup="$destination.backup"
    local suffix=1
    while [ -e "$backup" ] || [ -L "$backup" ]; do
      backup="$destination.backup.$suffix"
      suffix=$((suffix + 1))
    done
    mv "$destination" "$backup"
    echo "  backup  $destination -> $backup"
  fi

  ln -s "$source" "$destination"
  echo "  link    $destination"
}

# Wezterm
link "$DOTFILES_DIR/wezterm/wezterm.lua" ~/.wezterm.lua

# Ghostty
link "$DOTFILES_DIR/ghostty/config" ~/.config/ghostty/config

# Zsh
link "$DOTFILES_DIR/zsh/zshrc" ~/.zshrc
link "$DOTFILES_DIR/zsh/p10k.zsh" ~/.p10k.zsh

# Git
link "$DOTFILES_DIR/git/gitconfig" ~/.gitconfig

# Scripts
link "$DOTFILES_DIR/scripts/claude-idle-sleep.sh" ~/.local/bin/claude-idle-sleep
link "$DOTFILES_DIR/scripts/cpu-hogs.sh" ~/.local/bin/cpu-hogs

echo "Dotfiles installed!"
