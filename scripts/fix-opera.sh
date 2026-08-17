#!/usr/bin/env bash

if [[ $(whoami) != "root" ]]; then
	printf 'Try to run it with sudo\n'
	exit 1
fi

if [[ $(uname -m) != "x86_64" ]]; then
	printf 'This script is intended for 64-bit systems\n'
	exit 1
fi

if ! command -v unzip 2>&1 /dev/null; then
	printf '\033[1munzip\033[0m package must be installed to run this script\n'
	exit 1
fi

if ! command -v curl 2>&1 /dev/null; then
	printf '\033[1mcurl\033[0m package must be installed to run this script\n'
	exit 1
fi

if ! command -v jq 2>&1 /dev/null; then
	printf '\033[1mjq\033[0m package must be installed to run this script\n'
	exit 1
fi

if command -v pacman &> /dev/null; then
	ARCH_SYSTEM=true
fi

#Config section
readonly FIX_WIDEVINE=true
FIX_DIR=$(mktemp -d -t opera-fix.XXXXXXXX)
if [[ ! -d "$FIX_DIR" ]]; then
	printf 'Failed to create a secure temporary directory\n'
	exit 1
fi
readonly FIX_DIR
readonly FFMPEG_SRC_MAIN='https://api.github.com/repos/Ld-Hagen/nwjs-ffmpeg-prebuilt/releases'
readonly FFMPEG_SRC_ALT='https://api.github.com/repos/Ld-Hagen/fix-opera-linux-ffmpeg-widevine/releases'
readonly WIDEVINE_SRC='https://raw.githubusercontent.com/mozilla-firefox/firefox/refs/heads/main/toolkit/content/gmp-sources/widevinecdm.json'
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

if [ -x "$(command -v opera-gx)" ]; then
  OPERA_VERSIONS+=("opera-gx")
fi

get_chromium_major() {
  local opera_dir="$1"
  local opera_name="$2"
  local version=""
  for bin in "$opera_dir/$opera_name" "$opera_dir/opera"; do
    if [[ -f "$bin" ]]; then
      version=$(grep -ao 'Chrome/[0-9]\+' "$bin" 2>/dev/null | head -1 | grep -o '[0-9]\+')
      if [[ -n "$version" ]]; then
        echo "$version"
        return 0
      fi
    fi
  done
  return 1
}

get_ffmpeg_url_for_chromium() {
  local chromium_major="$1"
  local best_tag=""
  local best_url=""
  for releases_json in "$RELEASES_MAIN" "$RELEASES_ALT"; do
    local match
    match=$(echo "$releases_json" | jq -r --arg ver "$chromium_major" '
      [.[] | select((.body // "") | test("Chromium " + $ver + "\\."))]
      | sort_by(.published_at)
      | if length > 0 then .[-1] | "\(.tag_name)\t\(.assets[0].browser_download_url)" else empty end
    ')
    if [[ -n "$match" ]]; then
      local tag url
      tag=$(echo "$match" | cut -f1)
      url=$(echo "$match" | cut -f2)
      if [[ -z "$best_tag" || "$tag" > "$best_tag" ]]; then
        best_tag="$tag"
        best_url="$url"
      fi
    fi
  done
  if [[ -n "$best_url" ]]; then
    printf '%s\t%s' "$best_tag" "$best_url"
    return 0
  fi
  return 1
}

get_latest_ffmpeg_url() {
  local url_main url_alt
  url_main=$(echo "$RELEASES_MAIN" | jq -rS 'sort_by(.published_at) | .[-1].assets[0].browser_download_url')
  url_alt=$(echo "$RELEASES_ALT" | jq -rS 'sort_by(.published_at) | .[-1].assets[0].browser_download_url')
  if [[ $(basename "$url_alt") < $(basename "$url_main") ]]; then
    echo "$url_main"
  else
    echo "$url_alt"
  fi
}

#Getting download links
printf 'Getting download links...\n'

##Fetch all release data once
RELEASES_MAIN=$(curl -sL4 "$FFMPEG_SRC_MAIN?per_page=50")
RELEASES_ALT=$(curl -sL4 "$FFMPEG_SRC_ALT?per_page=50")

##Widevine
if $FIX_WIDEVINE; then
  readonly WIDEVINE_URL=$(curl -sL4 $WIDEVINE_SRC | jq -r '.vendors."gmp-widevinecdm".platforms."Linux_x86_64-gcc3".mirrorUrls[0]')
fi

#Downloading Widevine
if $FIX_WIDEVINE; then
  printf 'Downloading Widevine CDM...\n'
  echo -e "From URL: $WIDEVINE_URL\n"
  curl -L4 --progress-bar "$WIDEVINE_URL" -o "$FIX_DIR/widevine.zip"
  if [ $? -ne 0 ]; then
    printf 'Failed to download Widevine CDM. Check your internet connection or try later\n'
    exit 1
  fi
  echo "Extracting WidevineCDM..."
  unzip -oj "$FIX_DIR/widevine.zip" -d "$FIX_DIR" > /dev/null 2>/dev/null
fi

LAST_FFMPEG_TAG=""

for opera in ${OPERA_VERSIONS[@]}; do
  echo "Doing $opera"
  EXECUTABLE=$(command -v "$opera")
	if [[ "$ARCH_SYSTEM" == true ]]; then
		OPERA_DIR=$(dirname $(cat $EXECUTABLE | grep exec | cut -d ' ' -f 2))
	elif head -1 "$EXECUTABLE" | grep -q 'bash\|sh'; then
		# The executable is a shell wrapper (e.g. openSUSE packages Opera as a wrapper
		# script). readlink -f on a script returns the script itself, not the real binary,
		# so we parse the LIBDIR variable directly from the wrapper instead.
		PARSED_LIBDIR=$(grep '^LIBDIR=' "$EXECUTABLE" | head -1 | sed 's/LIBDIR=//;s/"//g' | sed "s/\\\$PROGNAME/$opera/g")
		if [[ -n "$PARSED_LIBDIR" && -d "$PARSED_LIBDIR" ]]; then
			OPERA_DIR="$PARSED_LIBDIR"
		else
			OPERA_DIR=$(dirname $(readlink -f $EXECUTABLE))
		fi
	else
		OPERA_DIR=$(dirname $(readlink -f $EXECUTABLE))
	fi

  CHROMIUM_MAJOR=$(get_chromium_major "$OPERA_DIR" "$opera")
  if [[ -n "$CHROMIUM_MAJOR" ]]; then
    printf 'Detected Chromium %s for %s\n' "$CHROMIUM_MAJOR" "$opera"
    FFMPEG_MATCH=$(get_ffmpeg_url_for_chromium "$CHROMIUM_MAJOR")
    if [[ -n "$FFMPEG_MATCH" ]]; then
      FFMPEG_TAG=$(echo "$FFMPEG_MATCH" | cut -f1)
      FFMPEG_URL=$(echo "$FFMPEG_MATCH" | cut -f2)
    else
      printf 'WARNING: No ffmpeg release found for Chromium %s, using latest\n' "$CHROMIUM_MAJOR"
      FFMPEG_TAG="latest"
      FFMPEG_URL=$(get_latest_ffmpeg_url)
    fi
  else
    printf 'WARNING: Could not detect Chromium version for %s, using latest ffmpeg\n' "$opera"
    FFMPEG_TAG="latest"
    FFMPEG_URL=$(get_latest_ffmpeg_url)
  fi

  if [[ "$FFMPEG_TAG" != "$LAST_FFMPEG_TAG" ]]; then
    printf 'Downloading ffmpeg (%s)...\n' "$FFMPEG_TAG"
    echo -e "From: $FFMPEG_URL\n"
    curl -L4 --progress-bar "$FFMPEG_URL" -o "$FIX_DIR/ffmpeg.zip"
    if [ $? -ne 0 ]; then
      printf 'Failed to download ffmpeg. Check your internet connection or try later\n'
      exit 1
    fi
    echo "Extracting ffmpeg..."
    unzip -o "$FIX_DIR/ffmpeg.zip" -d "$FIX_DIR" > /dev/null
    LAST_FFMPEG_TAG="$FFMPEG_TAG"
  else
    printf 'Using cached ffmpeg (%s)\n' "$FFMPEG_TAG"
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

    # Newer Chromium-based Opera versions (110+) no longer read widevine_config.json.
    # On zypper-based systems (openSUSE) Opera reads OPERA_FLAGS from /etc/default/opera,
    # so we inject --widevine-cdm-path there as well to cover both loading mechanisms.
    if command -v zypper &>/dev/null && [[ -f /etc/default/$opera ]]; then
      OPERA_DEFAULT="/etc/default/$opera"
      CDM_FLAG="--widevine-cdm-path=$OPERA_WIDEVINE_DIR"
      if grep -q 'OPERA_FLAGS=' "$OPERA_DEFAULT"; then
        # Append the flag if not already present
        if ! grep -qF -- "$CDM_FLAG" "$OPERA_DEFAULT"; then
          sed -i "s|OPERA_FLAGS=\"\(.*\)\"|OPERA_FLAGS=\"\1 $CDM_FLAG\"|" "$OPERA_DEFAULT"
        fi
      else
        echo "OPERA_FLAGS=\"$CDM_FLAG\"" >> "$OPERA_DEFAULT"
      fi
      printf "Widevine CDM path added to %s\n" "$OPERA_DEFAULT"
    fi
  fi
done

#Removing temporary files
printf 'Removing temporary files...\n'
rm -rf "$FIX_DIR"
