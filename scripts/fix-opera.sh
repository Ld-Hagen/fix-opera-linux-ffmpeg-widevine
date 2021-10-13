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

if ! which wget > /dev/null; then
	printf '\033[1mwget\033[0m package must be installed to run this script\n'
	exit 1
fi

#Config section
readonly FIX_WIDEVINE=true
readonly TEMP_DIR='/tmp'
readonly FFMPEG_SRC_MAIN='https://api.github.com/repos/iteufel/nwjs-ffmpeg-prebuilt/releases'
readonly FFMPEG_SRC_ALT='https://api.github.com/repos/Ld-Hagen/fix-opera-linux-ffmpeg-widevine/releases'
readonly WIDEVINE_VERSIONS='https://dl.google.com/widevine-cdm/versions.txt'
readonly FFMPEG_SO_NAME='libffmpeg.so'
readonly WIDEVINE_SO_NAME='libwidevinecdm.so'
readonly WIDEVINE_MANIFEST_NAME='manifest.json'

readonly OPERA_DIR=$(dirname $(readlink -f $(which opera)))
readonly OPERA_LIB_DIR="$OPERA_DIR/lib_extra"
readonly OPERA_WIDEVINE_DIR="$OPERA_LIB_DIR/WidevineCdm"
readonly OPERA_WIDEVINE_SO_DIR="$OPERA_WIDEVINE_DIR/_platform_specific/linux_x64"
readonly OPERA_WIDEVINE_CONFIG="$OPERA_DIR/resources/widevine_config.json"

#Getting download links
printf 'Getting download links...\n'
##ffmpeg
readonly FFMPEG_URL_MAIN=$(wget -qO - $FFMPEG_SRC_MAIN | grep browser_download_url | cut -d '"' -f 4 | grep linux-x64 | head -n 1)
readonly FFMPEG_URL_ALT=$(wget -qO - $FFMPEG_SRC_ALT | grep browser_download_url | cut -d '"' -f 4 | grep linux-x64 | head -n 1)
[[ $(basename $FFMPEG_URL_ALT) < $(basename $FFMPEG_URL_MAIN) ]] && readonly FFMPEG_URL=$FFMPEG_URL_MAIN || readonly FFMPEG_URL=$FFMPEG_URL_ALT
if [[ -z $FFMPEG_URL ]]; then
	printf 'Failed to get ffmpeg download URL. Exiting...\n'
	exit 1
fi

##Widevine
if $FIX_WIDEVINE; then
	readonly WIDEVINE_LATEST=`wget -qO - $WIDEVINE_VERSIONS | tail -n1`
	readonly WIDEVINE_URL="https://dl.google.com/widevine-cdm/$WIDEVINE_LATEST-linux-x64.zip"
fi

#Downloading files
printf 'Downloading files...\n'
mkdir -p "$TEMP_DIR/opera-fix"
##ffmpeg
wget -q --show-progress $FFMPEG_URL -O "$TEMP_DIR/opera-fix/ffmpeg.zip"
if [ $? -ne 0 ]; then
	printf 'Failed to download ffmpeg. Check your internet connection or try later\n'
	exit 1
fi
##Widevine
if $FIX_WIDEVINE;  then
	wget -q --show-progress "$WIDEVINE_URL" -O "$TEMP_DIR/opera-fix/widevine.zip"
	if [ $? -ne 0 ]; then
		printf 'Failed to download Widevine CDM. Check your internet connection or try later\n'
		exit 1
	fi
fi

#Extracting files
printf 'Extracting files...\n'
##ffmpeg
unzip -o "$TEMP_DIR/opera-fix/ffmpeg.zip" -d $TEMP_DIR/opera-fix > /dev/null
##Widevine
if $FIX_WIDEVINE; then
	unzip -o "$TEMP_DIR/opera-fix/widevine.zip" -d $TEMP_DIR/opera-fix > /dev/null
fi

#Removing old libraries and preparing directories
printf 'Removing old libraries & making directories...\n'
##ffmpeg
rm -f "$OPERA_LIB_DIR/$FFMPEG_SO_NAME"
mkdir -p "$OPERA_LIB_DIR"
##Widevine
if $FIX_WIDEVINE; then
	rm -rf "$OPERA_WIDEVINE_DIR"
	mkdir -p "$OPERA_WIDEVINE_SO_DIR"
fi

#Moving libraries to its place
printf 'Moving libraries to their places...\n'
##ffmpeg
mv -f "$TEMP_DIR/opera-fix/$FFMPEG_SO_NAME" "$OPERA_LIB_DIR"
chmod 0644 "$OPERA_LIB_DIR/$FFMPEG_SO_NAME"
##Widevine
if $FIX_WIDEVINE; then
	mv -f "$TEMP_DIR/opera-fix/$WIDEVINE_SO_NAME" "$OPERA_WIDEVINE_SO_DIR"
	chmod 0644 "$OPERA_WIDEVINE_SO_DIR/$WIDEVINE_SO_NAME"
	mv -f "$TEMP_DIR/opera-fix/$WIDEVINE_MANIFEST_NAME" "$OPERA_WIDEVINE_DIR"
	chmod 0644 "$OPERA_WIDEVINE_DIR/$WIDEVINE_MANIFEST_NAME"
	printf "[\n      {\n         \"preload\": \"$OPERA_WIDEVINE_DIR\"\n      }\n]\n" > "$OPERA_WIDEVINE_CONFIG"
fi

#Removing temporary files
printf 'Removing temporary files...\n'
rm -rf "$TEMP_DIR/opera-fix"
