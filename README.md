# Fix Opera Linux libffmpeg & WidevineCdm

* Fixes Opera html5 media content including DRM-protected one.
* This script must be executed all times opera fails on showing html5 media content.
* On Debian-based and Arch-based distributions it could be started automatically after Opera each update or reinstall.

## Requirements

1. **wget** (Is needed for downloading the ffmpeg lib and widevine)
    ```sudo apt install wget```

2. **unzip** (Is needed for unpacking the downloaded file)
    ```sudo apt install unzip```

2. **git** (Is needed for fetching this script)
	    ```sudo apt install git```

## Usage

1. Clone this repo

    ```git clone https://github.com/Ld-Hagen/fix-opera-linux-ffmpeg-widevine.git```

2. Go to the repo root folder

    ```cd ./fix-opera-linux-ffmpeg-widevine```

3. (*Optional*) Run script. And if it works well go to next step.

    ```sudo ./scripts/fix-opera.sh```

4. Run install script and answer few questions.

    ```sudo ./install.sh```

5. Delete the repo

    ```cd .. && rm -rf ./fix-opera-linux-ffmpeg-widevine```
