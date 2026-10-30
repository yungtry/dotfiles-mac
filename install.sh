#!/bin/sh
# Symlinks the configs in this repo into place. An existing config is moved aside, not deleted.
set -e
cd "$(dirname "$0")"
repo=$(pwd)

link() {
  src="$repo/$1"
  dst="$2"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    echo "ok      $dst"
    return
  fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    mv "$dst" "$dst.backup.$(date +%Y%m%d%H%M%S)"
    echo "backup  $dst"
  fi
  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  echo "linked  $dst -> $src"
}

link nvim "$HOME/.config/nvim"
