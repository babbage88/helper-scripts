typeset -U path cdpath fpath manpath
for profile in ${(z)NIX_PROFILES}; do
  fpath+=($profile/share/zsh/site-functions $profile/share/zsh/$ZSH_VERSION/functions $profile/share/zsh/vendor-completions)
done

HELPDIR="/nix/store/4wvhzvwmv2rnwgcg0sadhs769hky28xk-zsh-5.9.1/share/zsh/$ZSH_VERSION/help"

typeset -g ZSH_COMPLETION_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/completions"
mkdir -p "$ZSH_COMPLETION_CACHE_DIR"
fpath=("$ZSH_COMPLETION_CACHE_DIR" $fpath)

# History options should be set in .zshrc and after oh-my-zsh sourcing.
# See https://github.com/nix-community/home-manager/issues/177.
HISTSIZE="10000"
SAVEHIST="10000"

HISTFILE="/home/jtrahan/.zsh_history"
mkdir -p "$(dirname "$HISTFILE")"

# Set shell options
set_opts=(
  HIST_FCNTL_LOCK HIST_IGNORE_DUPS HIST_IGNORE_SPACE SHARE_HISTORY
  NO_APPEND_HISTORY NO_EXTENDED_HISTORY NO_HIST_EXPIRE_DUPS_FIRST
  NO_HIST_FIND_NO_DUPS NO_HIST_IGNORE_ALL_DUPS NO_HIST_SAVE_NO_DUPS
)
for opt in "${set_opts[@]}"; do
  setopt "$opt"
done
unset opt set_opts

export DOCKER_HOST=unix:///var/run/docker.sock
export SCRIPTS_DIR="$HOME/.scripts"
export PATH="$HOME/go/bin:$HOME/.cargo/bin:$HOME/.local/bin:$PATH"
export BUN_INSTALL="$HOME/.bun"
export PATH="$HOME/.local/bin:$BUN_INSTALL/bin:$PATH"

# Source custom functions
source "$HOME/.scripts/helper_funcs/nslookup_k8s.sh"
source "$HOME/.scripts/helper_funcs/minio_keys.sh"
source "$HOME/.scripts/helper_funcs/git_helpers.sh"
source "$HOME/.scripts/helper_funcs/nodepods.sh"
source "$HOME/.scripts/helper_funcs/podterm.sh"
source "$HOME/.scripts/helper_funcs/kube_cleanup_terminating.sh"
source "$HOME/.scripts/helper_funcs/kube_tls_extract.sh"
source "$HOME/.scripts/helper_funcs/get_kube_dockerinfo.sh"
source "$HOME/.scripts/helper_funcs/update_bind.sh"
source "$HOME/.scripts/ssh_utils.sh"
source "$HOME/.scripts/install_latest_nixhm.sh"

# Zsh configuration
fpath+=($HOME/.zsh/pure)
setopt autocd
zstyle ':completion::complete:cd:*' accept-exact '(*/|)..'
zstyle ':completion:*' special-dirs true
autoload -Uz compinit
compinit

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

autoload -U promptinit; promptinit
prompt pure

zstyle :prompt:pure:git:dirty color '#FAFAB2'
zstyle :prompt:pure:git:branch color '#66FFA4'
zstyle :prompt:pure:user color '#99FFCC'
zstyle :prompt:pure:host color '#99FFFF'
zstyle :prompt:pure:path color '#E5CCFF'
zstyle :prompt:pure:prompt:success color '#FFFFFF'
zstyle :prompt:pure:prompt:error color '#FF0000'
zstyle :prompt:pure:virtualenv color '#FFFF99'
zstyle :prompt:pure:continuation color '#FFFF99'

# Completions
ensure_cached_completion cobra-cli _cobra-cli cobra-cli completion zsh
ensure_cached_completion kubectl _kubectl kubectl completion zsh
ensure_cached_completion helm _helm helm completion zsh
ensure_cached_completion infractl _infractl infractl completion zsh

# run ssh-agent in background
eval "$(ssh-agent -s)"
bindkey -e

alias -- cat=bat
alias -- cls=clear
alias -- create-scripts-tar='cd $HOME && tar -hczvf _scripts_dir.tar.gz .scripts/'
alias -- grep='grep --color=auto'
alias -- install-nhmg=install_and_updatepkg
alias -- ip='ip --color=auto'
alias -- k=kubectl
alias -- kube-get-dockerinfo=kube_get_dockerinfo
alias -- kube-tls-extract=kube_tls_extract
alias -- ll='ls -lah --color=auto'
alias -- ls='ls --color=auto'
alias -- nsr='home-manager switch --flake ~/.config/home-manager/#jtrahan -b backup'
alias -- p1='ping -c 5 1.1.1.1'
alias -- pgg='ping -c 5 google.com'
alias -- pgw='ping -c 5 10.0.0.254'
source /nix/store/wjfysmv7d7mc00nh8ihn26k3q40fvk1b-zsh-syntax-highlighting-0.8.0/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main)

