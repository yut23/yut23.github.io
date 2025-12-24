#!/bin/bash
set -euo pipefail
cd "$HOME" || exit

REPOS="$HOME/.homesick/repos"

# install homeshick if it isn't already
if [[ ! -e "$REPOS" ]]; then
  echo "Installing homeshick..."
  git clone https://github.com/yut23/homeshick.git "$REPOS/homeshick"
  git --git-dir="$REPOS/homeshick/.git" remote add upstream https://github.com/andsens/homeshick.git || true
fi
# shellcheck disable=SC1091
. "$REPOS/homeshick/homeshick.sh"

if [[ ! -e "$REPOS/.gitconfig" ]]; then
  cat > "$REPOS/.gitconfig" <<'EOF'
[user]
  email = yut23@gvljohnsons.com
  name = yut23
EOF
fi

# store as keys into an associative array (i.e. a set)
declare -A castles
if [[ $# -eq 0 ]]; then
  castles[misc]=y
  castles[vim]=y
  castles[neovim]=y
  castles[zsh]=y
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
  castle_urls+=("https://github.com/yut23/$castle-homeshick.git")
done

yes | homeshick clone "${castle_urls[@]}" || true
for castle in "${!castles[@]}" homeshick; do
  # fix any symlinks to submodules under Windows
  git -C "$REPOS/$castle" restore .
  if [[ ${castles[git]+x} ]]; then
    # update local gitconfig in all repos
    ( cd "$REPOS/$castle"; "$REPOS/git/home/.git_templates/hooks/post-checkout" )
  fi
done

export TERM=xterm
if [[ ${castles[tmux]+x} ]]; then
  "$HOME/.tmux/plugins/tpm/bin/install_plugins" || true
fi
if [[ ${castles[neovim]+x} ]]; then
  nvim +'let g:plug_window=""|PlugInstall|q' || true
fi
if [[ ${castles[vim]+x} ]]; then
  if [[ -d ~/.local/share/nvim/plugged ]]; then
    # link vim's plugged directory to neovim's, to save space
    ln -s ../.local/share/nvim/plugged ~/.vim/plugged
  else
    vim +'let g:plug_window=""|PlugInstall|q' || true
  fi
fi
if [[ ${castles[zsh]+x} ]]; then
  mkdir "$HOME/.zsh/cache"
  # install all plugins immediately (effectively disables turbo mode)
  zsh -i -c -- '@zinit-scheduler burst'
fi
