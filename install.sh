#!/usr/bin/env bash

set -euo pipefail

detect_pkg_manager() {
    if command -v apt-get >/dev/null 2>&1; then
        PKG_MGR="apt"
    elif command -v dnf >/dev/null 2>&1; then
        PKG_MGR="dnf"
    elif command -v pacman >/dev/null 2>&1; then
        PKG_MGR="pacman"
    elif command -v zypper >/dev/null 2>&1; then
        PKG_MGR="zypper"
    elif command -v emerge >/dev/null 2>&1; then
        PKG_MGR="portage"
    else
        PKG_MGR="unknown"
    fi

    if [[ "$PKG_MGR" == "unknown" ]]; then
        echo "Unsupported package manager"
        exit 1
    fi
}

install_deps() {
    DEPS=(curl unzip jq)

    case "$PKG_MGR" in
        apt)
            apt-get update
            apt-get install -y "${DEPS[@]}"
            ;;
        dnf)
            dnf install -y "${DEPS[@]}" python3-dnf-plugin-post-transaction-actions
            ;;
        pacman)
            pacman -Sy --needed --noconfirm "${DEPS[@]}"
            ;;
        zypper)
            zypper install -y "${DEPS[@]}"
            ;;
        portage)
            emerge --ask=n "${DEPS[@]}"
            ;;
        *)
            echo "Unsupported package manager. Install dependencies manually:"
            echo "  ${DEPS[*]}"
            exit 1
            ;;
    esac
}

install_hook () {
    case "$PKG_MGR" in
        apt)
            cp -f "$SCRIPT_PATH/scripts/99fix-opera" "$INSTALL_PATH"
            ln -sf "$INSTALL_PATH/99fix-opera" /etc/apt/apt.conf.d/99fix-opera
            ;;
        pacman)
            cp -f "$SCRIPT_PATH/scripts/fix-opera.hook" "$INSTALL_PATH"
            ln -sf "$INSTALL_PATH/fix-opera.hook" /usr/share/libalpm/hooks/fix-opera.hook
            ;;
        dnf)
            dnf install -y python3-dnf-plugin-post-transaction-actions
            cp -f "$SCRIPT_PATH/scripts/fix-opera.action" "$INSTALL_PATH"
            ln -sf "$INSTALL_PATH/fix-opera.action" \
                /etc/dnf/plugins/post-transaction-actions.d/fix-opera.action
            ;;
        *)
            echo "Automatic hook installation not supported for this system."
            return 1
            ;;
    esac
}

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

if ! which curl > /dev/null; then
	printf '\033[1mcurl\033[0m package must be installed to run this script\n'
	exit 1
fi

if ! which jq > /dev/null; then
	printf '\033[1mjq\033[0m package must be installed to run this script\n'
	exit 1
fi

readonly SCRIPT_PATH=$(dirname $(readlink -f $0))
readonly INSTALL_PATH="/root/.scripts"
readonly USER_NAME="${SUDO_USER:-$(logname)}"
readonly USER_HOME=$(getent passwd "$USER_NAME" | cut -d: -f6)
mkdir -p $INSTALL_PATH

printf 'Installing script to your system...\n'

detect_pkg_manager
install_deps

read -p "Enable automatic execution after Opera updates? [y/N] " AUTO
[[ "$AUTO" =~ ^[Yy]$ ]] && install_hook

mkdir -p "$INSTALL_PATH"
cp -f "$SCRIPT_PATH/scripts/fix-opera.sh" "$INSTALL_PATH"
chmod +x "$INSTALL_PATH/fix-opera.sh"

printf 'Would you like to apply Widevine CDM fix? [y/n]'
while read FIX_WIDEVINE; do
	case $FIX_WIDEVINE in
		"y" | "Y")
			printf 'Setting FIX_WIDEVINE to true...\n'
			sed -i '/FIX_WIDEVINE=/s/false/true/g' $INSTALL_PATH/fix-opera.sh
			break;;
		"n" | "N")
			printf 'Setting FIX_WIDEVINE to false...\n'
			sed -i '/FIX_WIDEVINE=/s/true/false/g' $INSTALL_PATH/fix-opera.sh
			break;;
		*        )
			printf 'Would you like to apply Widevine CDM fix? [y/n]'
			continue;;
	esac
done

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
