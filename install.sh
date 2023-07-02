#!/bin/bash
if [[ $(whoami) != "root" ]]; then
	printf 'Try to run it with sudo\n'
	exit 1
fi

if [[ $(uname -m) != "x86_64" ]]; then
	printf 'This script is intended for 64-bit systems\n'
	exit 1
fi

if ! which unzip > /dev/null; then
	printf '\033[1munzip\033[0m package must be installed to run this script\n'
	exit 1
fi

if ! which curl > /dev/null && ! which wget > /dev/null; then
	printf '\033[1mcurl\033[0m or \033[1mwget\033[0m must be installed to run this script\n'
	exit 1
fi

readonly SCRIPT_PATH=$(dirname $(readlink -f $0))
readonly INSTALL_PATH="/root/.scripts"
readonly USER_NAME="$(logname)"
readonly USER_HOME=$(sudo -u $USER_NAME sh -c 'echo $HOME')

create_hook ()
{
	printf 'Choose your Linux distro:\n'
	printf '	1. Debian-based (Debian/Ubuntu/Mint/etc.)\n'
	printf '	2. Arch-based (Arch/Manjaro/etc.)\n'
	printf '	3. RedHat-based (RedHat/Fedora/etc.)\n'
	printf '	0. Other\n'
	while read -p "Your choice: " DISTRIB; do
		case $DISTRIB in
			"1" )
				cp -f $SCRIPT_PATH/scripts/99fix-opera $INSTALL_PATH
				ln -sf $INSTALL_PATH/99fix-opera /etc/apt/apt.conf.d/
				printf 'Now the script will run automatically every time apt installs or updates Opera.\n'
				break;;
			"2" )
				cp -f $SCRIPT_PATH/scripts/fix-opera.hook $INSTALL_PATH
				ln -sf $INSTALL_PATH/fix-opera.hook /usr/share/libalpm/hooks/
				printf 'Now the script will run automatically every time pacman installs or updates Opera.\n'
				break;;
			"3" )
				dnf install python3-dnf-plugin-post-transaction-actions -y
				cp -f $SCRIPT_PATH/scripts/fix-opera.action $INSTALL_PATH
				ln -sf $INSTALL_PATH/fix-opera.action /etc/dnf/plugins/post-transaction-actions.d/
				printf 'Now the script will run automatically every time dnf installs or updates Opera.\n'
				break;;
			"0" )
				printf "Autostart for your Linux distro is currently unsupported\n"
				break;;
			*   )
				continue;;
		esac
	done
}

printf 'Installing script to your system...\n'

printf 'Would you like to apply Widevine CDM fix? [y/n]'
while read FIX_WIDEVINE; do
	case $FIX_WIDEVINE in
		"y" | "Y")
			printf 'Setting FIX_WIDEVINE to true...\n'
			sed -i '/FIX_WIDEVINE=/s/false/true/g' $SCRIPT_PATH/scripts/fix-opera.sh
			break;;
		"n" | "N")
			printf 'Setting FIX_WIDEVINE to false...\n'
			sed -i '/FIX_WIDEVINE=/s/true/false/g' $SCRIPT_PATH/scripts/fix-opera.sh
			break;;
		*        )
			printf 'Would you like to apply Widevine CDM fix? [y/n]'
			continue;;
	esac
done

mkdir -p $INSTALL_PATH
cp -f $SCRIPT_PATH/scripts/fix-opera.sh $INSTALL_PATH
chmod +x $INSTALL_PATH/fix-opera.sh

printf "Would you like to create an alias for user $USER_NAME? [y/n]"
while read CREATE_ALIAS; do
	case $CREATE_ALIAS in
		"y" | "Y")
			echo "alias fix-opera='sudo ~root/.scripts/fix-opera.sh' # Opera fix HTML5 media" >> $USER_HOME/.bashrc
			printf "Alias \"fix-opera\" will be available after your next logon.\n"
			break;;
		"n" | "N")
			break;;
		*        )
			printf "Would you like to create an alias for user $USER_NAME? [y/n]"
			continue;;
	esac
done

printf "Would you like to run it automatically after each Opera update? [y/n]"
while read CREATE_HOOK; do
	case $CREATE_HOOK in
		"y" | "Y")
			create_hook
			break;;
		"n" | "N")
			break;;
		*        )
			printf "Would you like to run it automatically after each Opera update?? [y/n]"
			continue;;
	esac
done

printf "Would you like to run it now? [y/n]"
while read RUN_NOW; do
	case $RUN_NOW in
		"y" | "Y")
			$INSTALL_PATH/fix-opera.sh
			break;;
		"n" | "N")
			break;;
		*        )
			printf "Would you like to run it now? [y/n]"
			continue;;
	esac
done
