#!/bin/bash
### copy_widevine_from_anywhere()
### Returns: 0 on success (copied), 1 on failure
copy_widevine_from_anywhere() {
  local OUT_DIR="${1:-/tmp/opera-fix}"
  mkdir -p "$OUT_DIR" || return 1
  local min_version="4.10.2891.0"
  local best_version=""
  local best_path=""

  echo "Searching for Widevine across all local users and system locations..."

  # helper to compare versions
  version_ge() {
    # sort -V puts older first, so if $1 is not before $2, it's >=
    [[ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" != "$1" ]] || [[ "$1" == "$2" ]]
  }

  # helper to extract version from path or binary
  get_version() {
    local path="$1"
    # try directory name first
    local dirver
    dirver=$(echo "$path" | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+' | head -n1)
    if [[ -n "$dirver" ]]; then
      echo "$dirver"
      return
    fi
    # fallback: strings scan
    if command -v strings >/dev/null; then
      local binver
      binver=$(strings "$path" | grep -Eo '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n1)
      if [[ -n "$binver" ]]; then
        echo "$binver"
        return
      fi
    fi
    echo "0.0.0.0"
  }

  # Collect candidates from user Firefox + Flatpak profiles
  for userhome in /home/*; do
    [[ -d "$userhome" ]] || continue
    local fx_dir="$userhome/.mozilla/firefox"
    if [[ -d "$fx_dir" ]]; then
      while IFS= read -r -d '' so; do
        local ver
        ver=$(get_version "$so")
        if version_ge "$ver" "$min_version"; then
          if [[ -z "$best_version" ]] || version_ge "$ver" "$best_version"; then
            best_version="$ver"
            best_path="$so"
          fi
        fi
      done < <(find "$fx_dir" -type f -name "libwidevinecdm.so" -print0 2>/dev/null)
    fi

    # Flatpak Firefox per-user
    for widevine_path in "$userhome/.var/app/org.mozilla.firefox/data/.mozilla/firefox"/*/gmp-widevinecdm/*/; do
      [[ -d "$widevine_path" ]] || continue
      local so="${widevine_path}libwidevinecdm.so"
      if [[ -f "$so" ]]; then
        local ver
        ver=$(get_version "$so")
        if version_ge "$ver" "$min_version"; then
          if [[ -z "$best_version" ]] || version_ge "$ver" "$best_version"; then
            best_version="$ver"
            best_path="$so"
          fi
        fi
      fi
    done
  done

  # Chrome / Chromium system paths
  local candidates=(
    "/opt/google/chrome/WidevineCdm/*/"
    "/usr/lib/chromium/WidevineCdm/*/"
    "/usr/lib64/chromium/WidevineCdm/*/"
    "/usr/lib64/google/chrome/WidevineCdm/*/"
    "/var/lib/flatpak/app/org.mozilla.Firefox/current/active/files/share/firefox/gmp-widevinecdm/*/"
    "/snap/chromium/current/*/WidevineCdm/*/"
    "/usr/lib*/widevine-cdm/*/"
  )
  for pat in "${candidates[@]}"; do
    for dir in $pat; do
      [[ -d "$dir" ]] || continue
      local so="${dir}libwidevinecdm.so"
      if [[ -f "$so" ]]; then
        local ver
        ver=$(get_version "$so")
        if version_ge "$ver" "$min_version"; then
          if [[ -z "$best_version" ]] || version_ge "$ver" "$best_version"; then
            best_version="$ver"
            best_path="$so"
          fi
        fi
      fi
    done
  done

  if [[ -n "$best_path" ]]; then
    echo "    Selected Widevine version $best_version from $best_path"
    cp -f "$best_path" "$OUT_DIR/libwidevinecdm.so"
    cp -f "$(dirname "$best_path")"/manifest* "$OUT_DIR/" 2>/dev/null || true
    return 0
  fi

  echo "    No Widevine found meeting minimum version $min_version"
  return 1
}
###

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

if which pacman &> /dev/null; then
	ARCH_SYSTEM=true
fi

#Config section
readonly FIX_WIDEVINE=true
readonly FIX_DIR='/tmp/opera-fix'
readonly FFMPEG_SRC_MAIN='https://api.github.com/repos/Ld-Hagen/nwjs-ffmpeg-prebuilt/releases'
readonly FFMPEG_SRC_ALT='https://api.github.com/repos/Ld-Hagen/fix-opera-linux-ffmpeg-widevine/releases'
readonly WIDEVINE_VERSIONS='https://dl.google.com/widevine-cdm/versions.txt'
readonly FFMPEG_SO_NAME='libffmpeg.so'
readonly WIDEVINE_SO_NAME='libwidevinecdm.so'
readonly WIDEVINE_MANIFEST_NAME='manifest.json'

OPERA_VERSIONS=()

if [ -x "$(command -v opera)" ]; then
  OPERA_VERSIONS+=("opera")
fi

if [ -x "$(command -v opera-beta)" ]; then
  OPERA_VERSIONS+=("opera-beta")
fi

#Getting download links
printf 'Getting download links:\n'

#Configure ffmpeg
readonly FFMPEG_URL_MAIN=$(curl -sL4 $FFMPEG_SRC_MAIN | jq -r '.[0].assets[0].browser_download_url')
readonly FFMPEG_URL_ALT=$(curl -sL4 $FFMPEG_SRC_ALT | jq -r '.[0].assets[0].browser_download_url')
[[ $(basename $FFMPEG_URL_ALT) < $(basename $FFMPEG_URL_MAIN) ]] && readonly FFMPEG_URL=$FFMPEG_URL_MAIN || readonly FFMPEG_URL=$FFMPEG_URL_ALT
if [[ -z $FFMPEG_URL ]]; then
  printf 'Failed to get ffmpeg download URL. Exiting...\n'
  exit 1
fi
echo "FFMPEG_URL_MAIN: $FFMPEG_URL_MAIN"
echo "FFMPEG_URL_MAIN: $FFMPEG_URL_ALT"

#Download ffmpeg
printf 'Downloading ffmpeg...\n'
mkdir -p "$FIX_DIR"
curl -L4 --progress-bar $FFMPEG_URL -o "$FIX_DIR/ffmpeg.zip"
if [ $? -ne 0 ]; then
  printf 'Failed to download ffmpeg. Check your internet connection or try later\n'
  exit 1
fi
#Extracting files
printf 'Extracting files...\n'
##ffmpeg
unzip -o "$FIX_DIR/ffmpeg.zip" -d $FIX_DIR > /dev/null

#Widevine
if copy_widevine_from_anywhere; then
  echo "Found a working Widevine locally, skipping download."
  #Removing temporary files
  printf 'Removing temporary files...\n'
  rm -rf "$FIX_DIR"
  exit 0
else
  echo "No updated local copies found. Falling back to download (don't expect anything useful!) ..."
fi

if $FIX_WIDEVINE; then
  echo "Finding a working Widevine version..."
  versions=$(curl -sL4 "$WIDEVINE_VERSIONS")
  for ver in $(echo "$versions" | tac); do
    # version gate: skip anything older than 4.10.2891.0
    if [[ "$(printf '%s\n%s\n' "$ver" "4.10.2891.0" | sort -V | head -n1)" == "$ver" && "$ver" != "4.10.2891.0" ]]; then
      echo "Widevine version $ver is too old, skipping..."
      continue
    fi
    test_url="https://dl.google.com/widevine-cdm/${ver}-linux-x64.zip"
    if curl --progress-bar --fail "$test_url" -o "$FIX_DIR/widevine.zip"; then
      WIDEVINE_LATEST="$ver"
      WIDEVINE_URL="$test_url"
      echo -e "Trying Widevine version $WIDEVINE_LATEST from $WIDEVINE_URL\n"
      break
    else
      echo "Widevine version $ver not available, trying older..."
    fi
  done
  echo "unzip -o \"$FIX_DIR/widevine.zip\" -d $FIX_DIR"
  unzip -o "$FIX_DIR/widevine.zip" -d $FIX_DIR > /dev/null
fi

for opera in ${OPERA_VERSIONS[@]}; do
  echo "Doing $opera"
  EXECUTABLE=$(command -v "$opera")
	if [[ "$ARCH_SYSTEM" == true ]]; then
		OPERA_DIR=$(dirname $(cat $EXECUTABLE | grep exec | cut -d ' ' -f 2))
	else
		OPERA_DIR=$(dirname $(readlink -f $EXECUTABLE))
	fi
  OPERA_LIB_DIR="$OPERA_DIR/lib_extra"
  OPERA_WIDEVINE_DIR="$OPERA_LIB_DIR/WidevineCdm"
  OPERA_WIDEVINE_SO_DIR="$OPERA_WIDEVINE_DIR/_platform_specific/linux_x64"
  OPERA_WIDEVINE_CONFIG="$OPERA_DIR/resources/widevine_config.json"

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
  cp -f "$FIX_DIR/$FFMPEG_SO_NAME" "$OPERA_LIB_DIR"
  chmod 0644 "$OPERA_LIB_DIR/$FFMPEG_SO_NAME"
  ##Widevine
  if $FIX_WIDEVINE; then
    cp -f "$FIX_DIR/$WIDEVINE_SO_NAME" "$OPERA_WIDEVINE_SO_DIR"
    chmod 0644 "$OPERA_WIDEVINE_SO_DIR/$WIDEVINE_SO_NAME"
    cp -f "$FIX_DIR/$WIDEVINE_MANIFEST_NAME" "$OPERA_WIDEVINE_DIR"
    chmod 0644 "$OPERA_WIDEVINE_DIR/$WIDEVINE_MANIFEST_NAME"
    printf "[\n      {\n         \"preload\": \"$OPERA_WIDEVINE_DIR\"\n      }\n]\n" > "$OPERA_WIDEVINE_CONFIG"
  fi
done

#Removing temporary files
printf 'Removing temporary files...\n'
rm -rf "$FIX_DIR"
