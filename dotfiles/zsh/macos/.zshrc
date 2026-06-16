# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH
export ZSH_DISABLE_COMPFIX=true
# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Cache command-generated completions without sourcing them eagerly at startup.
typeset -g ZSH_COMPLETION_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/completions"
mkdir -p "$ZSH_COMPLETION_CACHE_DIR"

if type brew &>/dev/null; then
  fpath=("$(brew --prefix)/share/zsh/site-functions" $fpath)
fi

fpath=("$ZSH_COMPLETION_CACHE_DIR" $fpath)

# Added by setup_install_tree_sitter_bin.sh for install_tree_sitter_bin zsh completion
fpath=("$HOME/.scripts/completions/zsh" $fpath)

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
#ZSH_THEME="laptop-dev"
ZSH_THEME="agnoster"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git golang)

source $ZSH/oh-my-zsh.sh
. "$HOME/.local/bin/env"

# Source custom private env variables
source ~/.env_defaults

# Setuo default GOPATH and GOBIN env variables and add to PATH
export GOPATH="$HOME/go"
export GOBIN="$GOPATH/bin"
export PATH="$GOBIN:$PATH"

# nvm - load on first use instead of every shell startup
export NVM_DIR="$HOME/.nvm"
load_nvm() {
  unset -f nvm node npm npx yarn corepack load_nvm
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
}

nvm() { load_nvm; nvm "$@"; }
node() { load_nvm; node "$@"; }
npm() { load_nvm; npm "$@"; }
npx() { load_nvm; npx "$@"; }
yarn() { load_nvm; yarn "$@"; }
corepack() { load_nvm; corepack "$@"; }

eval "$(starship init zsh)"

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/jtrahan/.lmstudio/bin"
# End of LM Studio CLI section

ensure_cached_completion() {
  local command_name="$1"
  local cache_name="$2"
  shift 2

  (( $+commands[$command_name] )) || return 0

  if [[ -r "$ZSH_COMPLETION_CACHE_DIR/$cache_name" ]]; then
    "$@" >| "$ZSH_COMPLETION_CACHE_DIR/$cache_name" 2>/dev/null &|
  else
    "$@" >| "$ZSH_COMPLETION_CACHE_DIR/$cache_name" 2>/dev/null
  fi
}

# python - generating shell completions for uv
ensure_cached_completion uv _uv uv generate-shell-completion zsh

# Lazy-load conda only when it is actually used.
load_conda() {
  unset -f conda load_conda

  if [ -f "/opt/homebrew/anaconda3/etc/profile.d/conda.sh" ]; then
    . "/opt/homebrew/anaconda3/etc/profile.d/conda.sh"
  else
    export PATH="/opt/homebrew/anaconda3/bin:$PATH"
  fi
}

conda() {
  load_conda
  conda "$@"
}

# setting custom homebrew bin path for multiuser macos env
export PATH="/opt/homebrew/opt/libpq/bin:$PATH"
ensure_cached_completion helm _helm helm completion zsh
ensure_cached_completion kubectl _kubectl kubectl completion zsh
ensure_cached_completion dnsctl _dnsctl dnsctl completion zsh
ensure_cached_completion tailscale _tailscale tailscale completion zsh
ensure_cached_completion infractl _infractl infractl completion zsh
#source "$HOME/.scripts/remove_spaces/remove_spaces.sh"
#alias remove-spaces=remove_spaces


# eza setup 
# enable syntax highlightin and ls colors via eza
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
alias ls="eza --icons --color=always "
# end eza setup


# other other misc aliases
alias k=kubectl
alias ph-dl="yt-dlp --referer '$PH_URL'"

# pnpm 
export PNPM_HOME="/Users/jtrahan/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

# Added by setup_install_tree_sitter_bin.sh for ~/.scripts
export PATH="$HOME/.scripts:$PATH"

# Added by setup_install_tree_sitter_bin.sh for install_tree_sitter_bin zsh completion
source "$HOME/.scripts/completions/zsh/install_tree_sitter_bin.zsh"

# Added by setup_add_routes.sh for add-routes zsh completion
source "$HOME/.scripts/completions/zsh/add-routes.zsh"


# bat/cat setting
export BAT_THEME='Sublime Snazzy'
alias cat='bat --style=plain --paging=never'
