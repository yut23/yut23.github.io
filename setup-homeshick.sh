#!/bin/bash
set -euo pipefail

REPOS="$HOME/.homesick/repos"

# check for -h|--help
for arg in "$@"; do
  case "$arg" in
    -h|--help)
      echo "Installs homeshick and all applicable castles, then installs any extra plugins."
      exit 0
      ;;
  esac
done

# install homeshick if it isn't already
if [[ ! -e "$REPOS" ]]; then
  echo "Installing homeshick..."
  git clone https://github.com/yut23/homeshick.git "$REPOS/homeshick"
  git --git-dir="$REPOS/homeshick/.git" remote add upstream https://github.com/andsens/homeshick.git || true
fi
. "$REPOS/homeshick/homeshick.sh"

# store as keys into an associative array (i.e. a set)
declare -A castles
if [[ $# -eq 0 ]]; then
  # clone everything that's installed
  castles[git]=y
  castles[misc]=y
  if command -v nvim >/dev/null 2>&1; then
    vim_cmd=nvim
  elif command -v vim >/dev/null 2>&1; then
    vim_cmd=vim
    echo "neovim not found, falling back to vim"
  fi
  if [[ -n "${vim_cmd+x}" ]]; then
    castles[vim]=y
    castles[neovim]=y
  else
    echo "(neo)vim not found, skipping"
  fi
  if command -v tmux >/dev/null 2>&1; then
    castles[tmux]=y
  else
    echo "tmux not found, skipping"
  fi
  if command -v zsh >/dev/null 2>&1; then
    castles[zsh]=y
  else
    echo "zsh not found, skipping"
  fi
else
  # clone castles passed as command line arguments
  for arg in "$@"; do
    castles[$arg]=y
  done
fi

declare -a castle_urls
echo "Will clone castles:"
for castle in "${!castles[@]}"; do
  echo " $castle"
  castle_urls+=("https://bitbucket.org/yut23/$castle-homeshick.git")
done

homeshick clone "${castle_urls[@]}"

if [[ ${castles[tmux]+x} ]]; then
  "$HOME/.tmux/plugins/tpm/bin/install_plugins" || true
fi
if [[ ${castles[vim]+x} ]]; then
  "$vim_cmd" +'let g:plug_window=""|PlugInstall' || true
fi
if [[ ${castles[zsh]+x} ]]; then
  mkdir "$HOME/.zsh/cache"
  echo "Exit the child shell and run 'exec zsh' if everything looks good:"
  zsh
fi
