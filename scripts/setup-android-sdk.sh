#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/setup-android-sdk.sh [options]

Install the official Android command-line SDK pieces needed to build the MoUI
Counter Android APK.

Options:
  --android-home <dir>    SDK root, default macOS ~/Library/Android/sdk,
                          Linux ~/Android/Sdk.
  --compile-sdk <n>      Android platform level, default 35.
  --build-tools <ver>    Android build-tools version, default 35.0.0.
  --cmake <ver>          Android SDK CMake version, default 3.22.1.
  --ndk <ver>            Android NDK version, default 28.2.13676358
                          (matches Gradle/prepare-native-build pin).
  --accept-licenses      Accept Android SDK licenses non-interactively.
  --skip-licenses        Do not run sdkmanager --licenses.
  --dry-run              Print the packages that would be installed.
  --print-env            Print shell exports only, without installing anything.
  -h, --help             Show this help.

Examples:
  scripts/setup-android-sdk.sh --accept-licenses
  eval "$(scripts/setup-android-sdk.sh --print-env)"
  scripts/build-counter-android-apk.sh
USAGE
}

case "$(uname -s 2>/dev/null || true)" in
  Darwin)
    default_android_home="$HOME/Library/Android/sdk"
    ;;
  *)
    default_android_home="$HOME/Android/Sdk"
    ;;
esac

android_home="$default_android_home"
compile_sdk="35"
build_tools_version="35.0.0"
cmake_version="3.22.1"
ndk_version="28.2.13676358"
accept_licenses=0
skip_licenses=0
dry_run=0
print_env=0

repository_xml_url="${ANDROID_REPOSITORY_XML_URL:-https://dl.google.com/android/repository/repository2-1.xml}"
repository_base_url="${ANDROID_REPOSITORY_BASE_URL:-https://dl.google.com/android/repository}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --android-home)
      android_home="${2:?missing directory after --android-home}"
      shift 2
      ;;
    --compile-sdk)
      compile_sdk="${2:?missing API level after --compile-sdk}"
      shift 2
      ;;
    --build-tools)
      build_tools_version="${2:?missing version after --build-tools}"
      shift 2
      ;;
    --cmake)
      cmake_version="${2:?missing version after --cmake}"
      shift 2
      ;;
    --ndk)
      ndk_version="${2:?missing version after --ndk}"
      shift 2
      ;;
    --accept-licenses)
      accept_licenses=1
      shift
      ;;
    --skip-licenses)
      skip_licenses=1
      shift
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    --print-env)
      print_env=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$android_home" in
  "~"|"~/"*)
    android_home="$HOME${android_home#\~}"
    ;;
esac

packages=(
  "platform-tools"
  "platforms;android-$compile_sdk"
  "build-tools;$build_tools_version"
  "cmake;$cmake_version"
  "ndk;$ndk_version"
)

log() {
  printf '[moui-android-setup] %s\n' "$*" >&2
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "required command not found: $1" >&2
    exit 1
  fi
}

print_exports() {
  local cmake_bin="$android_home/cmake/$cmake_version/bin"
  printf 'export ANDROID_HOME=%q\n' "$android_home"
  printf 'export ANDROID_SDK_ROOT=%q\n' "$android_home"
  printf 'export ANDROID_NDK_HOME=%q\n' "$android_home/ndk/$ndk_version"
  printf 'export PATH=%q:%q:%q:$PATH\n' \
    "$android_home/cmdline-tools/latest/bin" \
    "$android_home/platform-tools" \
    "$cmake_bin"
}

host_os_for_android_repo() {
  case "$(uname -s)" in
    Darwin)
      printf 'macosx'
      ;;
    Linux)
      printf 'linux'
      ;;
    *)
      echo "unsupported host OS for this setup script: $(uname -s)" >&2
      exit 1
      ;;
  esac
}

sha1_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 1 "$1" | awk '{ print $1 }'
  elif command -v sha1sum >/dev/null 2>&1; then
    sha1sum "$1" | awk '{ print $1 }'
  else
    printf ''
  fi
}

find_latest_cmdline_tools_archive() {
  local metadata_file="$1"
  local host_os="$2"
  awk -v host="$host_os" '
    function tag_text(line) {
      sub(/^[^>]*>/, "", line)
      sub(/<.*$/, "", line)
      return line
    }
    /<remotePackage path="cmdline-tools;latest"/ { in_pkg = 1 }
    in_pkg && /<archive>/ { in_archive = 1; url = ""; checksum = ""; os = "" }
    in_pkg && in_archive && /<url>/ { url = tag_text($0) }
    in_pkg && in_archive && /<checksum>/ { checksum = tag_text($0) }
    in_pkg && in_archive && /<host-os>/ { os = tag_text($0) }
    in_pkg && in_archive && /<\/archive>/ {
      if (os == host) {
        print url "\t" checksum
        found = 1
        exit
      }
      in_archive = 0
    }
    in_pkg && /<\/remotePackage>/ { exit }
    END {
      if (!found) {
        exit 1
      }
    }
  ' "$metadata_file"
}

download_cmdline_tools() {
  local sdkmanager_path="$android_home/cmdline-tools/latest/bin/sdkmanager"
  if [ -x "$sdkmanager_path" ]; then
    log "using existing sdkmanager: $sdkmanager_path"
    return 0
  fi

  require_cmd curl
  require_cmd unzip

  local host_os
  host_os="$(host_os_for_android_repo)"
  local tmp_dir metadata archive_info archive_name expected_sha1 archive_url zip_path actual_sha1
  tmp_dir="$(mktemp -d)"
  metadata="$tmp_dir/repository2-1.xml"
  zip_path="$tmp_dir/cmdline-tools.zip"

  log "fetching Android repository metadata"
  curl -fsSL --retry 3 "$repository_xml_url" -o "$metadata"

  archive_info="$(find_latest_cmdline_tools_archive "$metadata" "$host_os")"
  archive_name="${archive_info%%$'\t'*}"
  expected_sha1="${archive_info#*$'\t'}"
  archive_url="$repository_base_url/$archive_name"

  log "downloading official Android command-line tools: $archive_name"
  curl -fL --retry 3 "$archive_url" -o "$zip_path"

  actual_sha1="$(sha1_file "$zip_path")"
  if [ -n "$actual_sha1" ] && [ "$actual_sha1" != "$expected_sha1" ]; then
    echo "checksum mismatch for $archive_name" >&2
    echo "expected: $expected_sha1" >&2
    echo "actual:   $actual_sha1" >&2
    exit 1
  fi

  mkdir -p "$android_home/cmdline-tools"
  if [ -e "$android_home/cmdline-tools/latest" ]; then
    mv "$android_home/cmdline-tools/latest" \
      "$android_home/cmdline-tools/latest.bak.$(date +%Y%m%d%H%M%S)"
  fi

  unzip -q "$zip_path" -d "$tmp_dir/unpacked"
  mv "$tmp_dir/unpacked/cmdline-tools" "$android_home/cmdline-tools/latest"
  log "installed sdkmanager: $sdkmanager_path"
}

accept_sdk_licenses() {
  local sdkmanager_path="$1"
  if [ "$skip_licenses" -eq 1 ]; then
    log "skipping sdkmanager --licenses"
    return 0
  fi

  if [ "$accept_licenses" -eq 1 ]; then
    log "accepting Android SDK licenses non-interactively"
    {
      for _ in {1..200}; do
        printf 'y\n'
      done
    } | "$sdkmanager_path" --sdk_root="$android_home" --licenses
  else
    log "running interactive Android SDK license prompt"
    "$sdkmanager_path" --sdk_root="$android_home" --licenses
  fi
}

install_packages() {
  local sdkmanager_path="$1"
  log "installing Android SDK packages:"
  for package in "${packages[@]}"; do
    log "  $package"
  done
  "$sdkmanager_path" --sdk_root="$android_home" --install "${packages[@]}"
}

if [ "$print_env" -eq 1 ]; then
  print_exports
  exit 0
fi

if [ "$dry_run" -eq 1 ]; then
  log "SDK root: $android_home"
  log "packages:"
  for package in "${packages[@]}"; do
    log "  $package"
  done
  exit 0
fi

require_cmd java
download_cmdline_tools

sdkmanager_path="$android_home/cmdline-tools/latest/bin/sdkmanager"
if [ ! -x "$sdkmanager_path" ]; then
  echo "sdkmanager was not found after installation: $sdkmanager_path" >&2
  exit 1
fi

accept_sdk_licenses "$sdkmanager_path"
install_packages "$sdkmanager_path"

log "Android SDK setup complete"
cat <<EOF

Add this environment to your current shell:

$(print_exports)

Then build the Counter APK:

scripts/build-counter-android-apk.sh
EOF
