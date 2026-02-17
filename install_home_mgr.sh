#!/usr/bin/env sh
NIXSRCDIR="$HOME/projects/nix-flakes/rockydev_homemgr"
HMDIR="$HOME/.config/home-manager"
NIXHOMECFG="$NIXSRCDIR/home.nix"
SCRIPTS_SRC_DIR="$NIXSRCDIR/scripts"
export FLAKEKEY="$HMDIR/#jtrahan"

##### ANSI Color Codes #####
BOLD=$(tput bold)
RESET=$(tput sgr0)
C_RESET=$(tput sgr0)

C_RED=$(tput setaf 1)
C_GREEN=$(tput setaf 2)
C_YELLOW=$(tput setaf 3)
C_BLUE=$(tput setaf 4)
C_MAGENTA=$(tput setaf 5)
C_CYAN=$(tput setaf 6)
C_WHITE=$(tput setaf 7)

# Bold colors
C_B_RED="${BOLD}${C_RED}"
C_B_GREEN="${BOLD}${C_GREEN}"
C_B_YELLOW="${BOLD}${C_YELLOW}"
C_B_BLUE="${BOLD}${C_BLUE}"
C_B_MAGENTA="${BOLD}${C_MAGENTA}"
C_B_CYAN="${BOLD}${C_CYAN}"
BOLD_WHITE="${BOLD}${C_WHITE}"
# White on black (foreground 7 background 0)
C_WHITE_ON_BLACK="$(tput setaf 7)$(tput setab 0)"

completed_install_msg=$(
	cat <<EOF
${BOLD_WHITE}#######################################${RESET}
${BOLD_WHITE}#                                     #${RESET}
${BOLD_WHITE}#  Completed installing home-manager  #${RESET}
${BOLD_WHITE}#                                     #${RESET}
${BOLD_WHITE}#######################################${RESET}
EOF
)

completed_updatepkg_msg=$(
	cat <<EOF
${BOLD_WHITE}#############################################${RESET}
${BOLD_WHITE}#                                           #${RESET}
${BOLD_WHITE}#  Completed updating nix-channel and pkgs  #${RESET}
${BOLD_WHITE}#                                           #${RESET}
${BOLD_WHITE}#############################################${RESET}
EOF
)

finish_msg="## ${B_WHITE}flake key: ${B_GREEN}${FLAKEKEY}${RESET}"
completed_switch_msg=$(
	cat <<EOF
${BOLD_WHITE}#######################################${RESET}
${BOLD_WHITE}#                                     #${RESET}
${BOLD_WHITE}#   Completed home-manager switch     #${RESET}
${BOLD_WHITE}#                                     #${RESET}
${BOLD_WHITE}#######################################${RESET}
${finish_msg}
EOF
)

install_hm() {
	local srcdir=${1:-$NIXSRCDIR}
	local dsthomedir=${2:-$HMDIR}
	local src_hm_cfg=${3:-$NIXHOMECFG}
	local src_scripts_dir=${4:-"$srcdir/scripts"}

	mkdir -p $dsthomedir
	printf "${BOLD_WHITE}copying${C_B_MAGENTA} %s ${BOLD_WHITE}to ${C_WHITE_ON_BLACK}%s${C_RESET}\\n" "$src_hm_cfg" "$dsthomedir"
	cp $src_hm_cfg $dsthomedir/home.nix
	printf "${BOLD_WHITE}copying flake files to${C_CYAN} %s${BOLD_WHITE}...${C_RESET}\\n" "$dsthomedir"
	cp $srcdir/flake.* $dsthomedir/
	printf "${BOLD_WHITE}copying scripts source dir: ${C_B_MAGENTA}%s${C_RESET} to${C_CYAN} %s${BOLD_WHITE}...${C_RESET}\\n" "$src_scripts_dir" "$dsthomedir"
	cp -r --force $src_scripts_dir $dsthomedir/
	echo
	echo
	printf "${BOLD_WHITE}\\n%s${C_RESET}\\n" "$completed_install_msg"
}

update_nixpkg() {
	local dsthomedir=${1:-$HMDIR}
	local flake_key="$dsthomedir/#$USER"
	export FLAKEKEY=$flake_key
	local cur_dir_start=$(pwd)
	printf "${BOLD_WHITE}cd into home-manager install dir %s...\\n${C_RESET}" "$dsthomedir"
	cd $dsthomedir
	printf "${BOLD_WHITE}Updating nix channels...${C_RESET}\\n"
	nix-channel --update
	printf "${BOLD_WHITE}Updating nix ${C_B_CYAN}flake.lock${BOLD_WHITE} file...${C_RESET}\\n"
	nix flake update
	printf "${BOLD_WHITE}switching home-manager to flake:${C_B_GREEN} %s\\n${C_RESET}" "$flake_key"
	home-manager switch --flake $flake_key
	printf "${BOLD_WHITE}completed flake_key: ${C_B_GREEN}${flake_key}${C_RESET}\\n"
	printf "${BOLD_WHITE}changing directory back to the starting dir: ${C_B_BLUE} %s\\n${C_RESET}" "$cur_dir_start"
	cd $cur_dir_start
	echo
	printf "${BOLD_WHITE}\\n%s${C_RESET}\\n" "$completed_updatepkg_msg"
}

hm_switch() {
	local dsthomedir=${1:-$HMDIR}
	local flake_key="$dsthomedir/#$USER"
	local cur_dir_start=$(pwd)

	export FLAKEKEY=$flake_key
	echo -e "${BOLD_WHITE}flake key is: ${C_B_GREEN}$FLAKEKEY${C_RESET}"
	printf "${BOLD_WHITE}cd into home-manager install dir ${C_B_YELLOW}%s...\\n${C_RESET}" "$dsthomedir"
	cd $dsthomedir
	printf "${BOLD_WHITE}switching home-manager to ${C_B_GREEN}flake: %s\\n${C_RESET}" "$flake_key"
	home-manager switch --flake $flake_key
	printf "${BOLD_WHITE}changing directory back to the starting dir:${C_B_BLUE} %s\\n${C_RESET}" "$cur_dir_start"
	cd $cur_dir_start
	echo
	printf "${BOLD_WHITE}\\n%s${C_RESET}\\n" "$completed_switch_msg"
}

install_and_updatepkg() {
	install_hm && update_nixpkg && hm_switch
}

#install_and_updatepkg
#hm_switch
#install_hm
