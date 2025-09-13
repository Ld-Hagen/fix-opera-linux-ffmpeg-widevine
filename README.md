# Fix Opera Linux libffmpeg & WidevineCdm

* Fixes Opera html5 media content including DRM-protected one.
* This script must be executed all times opera fails on showing html5 media content.
* On Debian-based, RedHat-based and Arch-based distributions it could be started automatically after Opera each update or reinstall.
* Works only with native versions of Opera. Won't work with flatpak/snap releses.
* May not work with opera-beta and opera-develper.

## Requirements

1. **curl** (Is needed for downloading the ffmpeg lib and widevine)

   **unzip** (Is needed for unpacking the downloaded file)

   **bsdtar/libarchive** (Is needed for unpacking the widevine lib)

   **git** (Is needed for fetching this script)

   **jq** (Is needed for parsing JSON from github)

	For Debian-based systems: `sudo apt install curl unzip libarchive-tools git jq`

	For Arch-based systems: `sudo pacman -S curl unzip libarchive git jq`

	For RedHat-based systems: `sudo dnf install curl unzip bsdtar git jq`
	
3. (*Optional*) **python3-dnf-plugin-post-transaction-actions** (Is needed for autoupdate in RedHat-based systems)
	`dnf install python3-dnf-plugin-post-transaction-actions`

## Usage

1. Clone this repo

    `git clone https://github.com/Ld-Hagen/fix-opera-linux-ffmpeg-widevine.git`

2. Go to the repo root folder

    `cd ./fix-opera-linux-ffmpeg-widevine`

3. (*Optional*) Run script. And if it works well go to next step.

    `sudo ./scripts/fix-opera.sh`

4. Run install script and answer few questions.

    `sudo ./install.sh`

## How to uninstall

1. Clone this repo

    `cd /tmp && git clone https://github.com/Ld-Hagen/fix-opera-linux-ffmpeg-widevine.git`

2. Go to the repo root folder

    `cd /tmp/fix-opera-linux-ffmpeg-widevine`

3. Make uninstall.sh executable

   `chmod +x uninstall.sh`

5. Run uninstallation script. And if it works well go to next step.

    `sudo ./uninstall.sh`
