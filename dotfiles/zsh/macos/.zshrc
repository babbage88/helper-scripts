# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH
export ZSH_DISABLE_COMPFIX=true
# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

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

# nvm - Node Version Maanger setup
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
eval "$(starship init zsh)"

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/jtrahan/.lmstudio/bin"
# End of LM Studio CLI section

# python - generating shell completions for uv
eval "$(uv generate-shell-completion zsh)"
# export PATH="/opt/homebrew/anaconda3/bin:$PATH"  # commented out by conda initialize

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/opt/homebrew/anaconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/opt/homebrew/anaconda3/etc/profile.d/conda.sh" ]; then
        . "/opt/homebrew/anaconda3/etc/profile.d/conda.sh"
    else
        export PATH="/opt/homebrew/anaconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

# setting custom homebrew bin path for multiuser macos env
export PATH="/opt/homebrew/opt/libpq/bin:$PATH"
source <(helm completion zsh)
source <(kubectl completion zsh)
source <(dnsctl completion zsh)
source <(tailscale completion zsh)
source <(infractl completion zsh)
#source "$HOME/.scripts/remove_spaces/remove_spaces.sh"
#alias remove-spaces=remove_spaces
if type brew &>/dev/null; then
  FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
fi
autoload -Uz compinit && compinit -u


# eza setup 
# enable syntax highlightin and ls colors via eza
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
alias ls="eza --icons --color=always "
# end eza setup


# other other misc aliases
alias k=kubernetes
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
fpath=("$HOME/.scripts/completions/zsh" $fpath)

# Added by setup_install_tree_sitter_bin.sh for install_tree_sitter_bin zsh completion
source "$HOME/.scripts/completions/zsh/install_tree_sitter_bin.zsh"

# Added by setup_add_routes.sh for add-routes zsh completion
source "$HOME/.scripts/completions/zsh/add-routes.zsh"


# bat/cat setting
export BAT_THEME='Sublime Snazzy'
alias cat='bat --style=plain --paging=never'
