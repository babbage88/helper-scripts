rewifi() {
	sudo systemctl stop wpa_supplicant.service &&
		sudo systemctl restart iwd.service &&
		sudo systemctl --no-pager status iwd.service
}
