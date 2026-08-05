> [!WARNING]
> Make sure, you're using latest version of this script. If not, update it (run installation steps again, say "n" when it asks for creating alias).
> 
> Since the may, 16th it doesn't get the latest libffmpeg, but checks for version compatibility.

> [!NOTE]
> All future versions of libffmpeg will be posted in https://github.com/Ld-Hagen/nwjs-ffmpeg-prebuilt/releases instead of this repo.

# Fix Opera Linux libffmpeg & WidevineCdm

* Fixes Opera html5 media content including DRM-protected one.
* This script must be executed all times opera fails on showing html5 media content.
* On Debian-based, RedHat-based and Arch-based distributions it could be started automatically after Opera each update or reinstall.
* Works only with native versions of Opera. Won't work with flatpak/snap releses.
* May not work with opera-beta and opera-develper.

## Requirements

1. **curl** (is needed for downloading the ffmpeg lib and widevine)

   **unzip** (is needed for unpacking the downloaded file)

   **git** (is needed for fetching this script)

   **jq** (is needed for parsing JSON from github)

2. (*Optional*) **python3-dnf-plugin-post-transaction-actions** (is needed for autoupdate in RedHat-based systems)

    The main installer - `install.sh` - auto-detects your distro and installs the both the appropriate and the optional requirements by itself, if they're missing.

## Usage

1. Clone this repo

    `git clone https://github.com/Ld-Hagen/fix-opera-linux-ffmpeg-widevine.git`

2. Go to the repo root folder

    `cd ./fix-opera-linux-ffmpeg-widevine`

3. (*Optional*) Run script. And if it works well go to next step.

    `chmod +x scripts/fix-opera.sh && sudo ./scripts/fix-opera.sh`

4. Make install.sh executable

   `chmod +x ./install.sh`

5. Run install script and answer few questions.

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
