# Fix Opera Linux libffmpeg & WidevineCdm

* Fixes Opera html5 media content including DRM-protected one.
* This script must be executed all times opera fails on showing html5 media content.
* On Debian-based, RedHat-based and Arch-based distributions it could be started automatically after Opera each update or reinstall.

## Requirements

1. **curl** or **wget** (Is needed for downloading the ffmpeg lib and widevine)

   **unzip** (Is needed for unpacking the downloaded file)

   **git** (Is needed for fetching this script)

	For Debian-based systems: `sudo apt install wget unzip git`

	For Arch-based systems: `sudo pacman -S wget unzip git`

	For RedHat-based systems: `sudo dnf install wget unzip git`
	
2. (*Optional*) **python3-dnf-plugin-post-transaction-actions** (Is needed for autoupdate in RedHat-based systems)
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

5. Delete the repo

    `cd .. && rm -rf ./fix-opera-linux-ffmpeg-widevine`
