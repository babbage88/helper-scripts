#!/bin/bash

install_updates() {
	sudo apt-get update -y
	sudo apt-get upgrade -y
}

# Install pre-reqs
install_apt_reqs() {
	sudo apt-get install -y software-properties-common wget tar curl python3-venv git ninja-build gettext libtool libtool-bin autoconf automake cmake g++ pkg-config unzip curl doxygen
}

# install cargo
install_rust_cargo() {
	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
	#curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
}

#install uv for python
install_uv() {
	curl -LsSf https://astral.sh/uv/install.sh | sh
}

# install nvm
install_nvm_node() {
	curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.2/install.sh | bash

	# add nvm to PATH
	export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
	[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm

	nvm install --lts
}

install_dotnet_sdk() {
	# install dotnet 9.0 sdk
	sudo apt-get install -y software-properties-common
	sudo add-apt-repository ppa:dotnet/backports
	sudo apt-get update &&
		sudo apt-get install -y dotnet-sdk-9.0
}

update_golang() {
	#install golang
	wget https://go.dev/dl/go1.24.2.linux-amd64.tar.gz
	sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go1.24.2.linux-amd64.tar.gz
}

install_golang() {
	#install golang
	wget https://go.dev/dl/go1.24.2.linux-amd64.tar.gz
	sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go1.24.2.linux-amd64.tar.gz
	echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
	echo 'export GOPATH=$HOME/go' >> ~/.bashrc
	echo 'export GOBIN=$GOPATH/bin' >> ~/.bashrc

	echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.zshrc
	echo 'export GOPATH=$HOME/go' >> ~/.zshrc
	echo 'export GOBIN=$GOPATH/bin' >> ~/.zshrc
}

setup_golang_envars() {
	echo 'export PATH=$PATH:/usr/local/go/bin' >>~/.bashrc
	echo 'export GOPATH=$HOME/go' >>~/.bashrc
	echo 'export GOBIN=$GOPATH/bin' >>~/.bashrc
}

install_nvim_from_source() {
	#install neovim from source
	export curdir=$(pwd)
	git clone --depth 1 https://github.com/neovim/neovim.git
	cd neovim
	make CMAKE_BUILD_TYPE=RelWithDebInfo
	sudo make install
	cd $curdir && rm -rf neovim
}

install_nerd_fonts() {
	cur_dir=$(pwd)
	wget -P ~/.local/share/fonts https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/JetBrainsMono.zip && \
	  cd ~/.local/share/fonts && \
	  unzip JetBrainsMono.zip && \
	  rm JetBrainsMono.zip && \
	  fc-cache -fv && cd $cur_dir
}

install_lazyvim() {
	# isntall lazyvim
	mv ~/.config/nvim{,.bak}
	git clone https://github.com/LazyVim/starter ~/.config/nvim
	rm -rf ~/.config/nvim/.git
}

reinstall_lazyvim() {
	# required
	mv ~/.config/nvim{,.bak}

	# optional but recommended
	mv ~/.local/share/nvim{,.bak}
	mv ~/.local/state/nvim{,.bak}
	mv ~/.cache/nvim{,.bak}
	install_lazyvim
}

add_dev_user() {
	USERNAME="$1"

	# Create the user
	if id "$USERNAME" &>/dev/null; then
		echo "User '$USERNAME' already exists."
	else
		useradd -m -s /bin/bash "$USERNAME"
		echo "User '$USERNAME' created."
	fi

	# Set password
	echo "Set password for '$USERNAME':"
	passwd "$USERNAME"

	# Add to sudo group
	usermod -aG sudo "$USERNAME"
	echo "User '$USERNAME' added to 'sudo' group."

	echo "$USERNAME ALL=(ALL:ALL) NOPASSWD: ALL" >>/etc/sudoers.d/$USERNAME

	mkdir -p /home/$USERNAME/.ssh && chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh && chmod 700 /home/$USERNAME/.ssh

	touch /home/$USERNAME/.ssh/authorized_keys
	cat ~/.ssh/authorized_keys >>/home/$USERNAME/.ssh/authorized_keys
	chown $USERNAME:$USERNAME /home/$USERNAME/.ssh/authorized_keys
}

clone-projects() {
	curdir=$(pwd)
	mv ~/projects/{,.bak}
	mkdir -p ~/projects
	cd ~/projects
	git clone git@github.com:babbage88/Homelab.Configs.git
	git clone git@github.com:babbage88/infra-cli.git
	git clone git@github.com:babbage88/go-infra.git
	git clone git@github.com:babbage88/infra-kubeinit.git
	git clone git@github.com:babbage88/infra-db.git
	git clone git@github.com:babbage88/db-helper-ui.git
	git clone git@github.com:babbage88/react-trahan-compound.git
	git clone git@github.com:babbage88/smbplusplus.git
	git clone git@github.com:babbage88/goph.git
	git clone git@github.com:babbage88/tint.git
	git clone git@github.com:babbage88/rust-web-test.git
	git clone git@github.com:babbage88/go-acme-cli.git
	git clone git@github.com:babbage88/gofiles.git
	git clone git@github.com:babbage88/infra-svui.git
	cd $curdir
}

#install_updates
#install_apt_reqs
#install_rust_cargo
#install_uv
#install_nvm_node
#install_golang
#install_dotnet_sdk
#install_nvim_from_source
#install_nerd_fonts
#install_lazyvim
#add_dev_user jtrahan
