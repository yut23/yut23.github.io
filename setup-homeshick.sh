#!/bin/bash
set -euo pipefail
cd "$HOME" || exit

REPOS="$HOME/.homesick/repos"

# parse arguments
unattended=0
args=()
for arg in "$@"; do
  case "$arg" in
    -h|--help)
      echo "Installs homeshick and all applicable castles, then installs any extra plugins."
      exit 0
      ;;
    --unattended)
      unattended=1
      ;;
    *)
      args+=("$arg")
      ;;
  esac
done

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
  for arg in "${args[@]}"; do
    castles[$arg]=y
  done
fi

echo "Will clone castles:"
printf ' %s\n' "${!castles[@]}"
for castle in "${!castles[@]}"; do
  git clone --recursive "https://github.com/yut23/$castle-homeshick.git" "$REPOS/$castle"
  # fix any symlinks to submodules under Windows
  git -c core.symlinks=true -C "$REPOS/$castle" restore .
done

if (( unattended )); then
  yes | homeshick link || true
  export TERM=xterm
else
  homeshick link || true
fi

if [[ ${castles[git]+x} ]]; then
  for castle in "${!castles[@]}" homeshick; do
    # update local gitconfig in all repos
    ( cd "$REPOS/$castle"; "$REPOS/git/home/.git_templates/hooks/post-checkout" )
  done
fi
if [[ ${castles[tmux]+x} ]]; then
  "$HOME/.tmux/plugins/tpm/bin/install_plugins" || true
fi
vim_cmd='let g:plug_window=""|PlugInstall'
if (( unattended )); then
  vim_cmd="$vim_cmd|q"
fi
if [[ ${castles[neovim]+x} ]] && command -v nvim >/dev/null 2>&1; then
  nvim +"$vim_cmd" || true
fi
if [[ ${castles[vim]+x} ]]; then
  if (( unattended )) && [[ -d ~/.local/share/nvim/plugged ]]; then
    # link vim's plugged directory to neovim's, to save space
    ln -s ../.local/share/nvim/plugged ~/.vim/plugged
  elif command -v vim >/dev/null 2>&1; then
    vim +"$vim_cmd" || true
  fi
fi
if [[ ${castles[zsh]+x} ]]; then
  mkdir "$HOME/.zsh/cache"
  if (( unattended )); then
    # install all plugins immediately (effectively disables turbo mode)
    zsh -i -c -- '@zinit-scheduler burst'
  else
    echo "Exit the child shell and run 'exec zsh' if everything looks good:"
    zsh
  fi
fi
