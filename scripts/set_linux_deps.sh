#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/set_linux_deps.sh [options]

Installs the Ubuntu/Debian packages needed to build and run MoUI on Linux.
The default set covers the MoonBit toolchain prerequisites, the Wayland
window core (backend/linux + wzzc-dev/window), GLib/zlib link libraries,
Weston for headless compositor checks, desktop integration (zenity), and the
Skia renderer stack (fontconfig/FreeType/HarfBuzz, Clang/Ninja, fonts,
Vulkan headers). Native WebView (WebKitGTK) is optional and off by default.

Options:
  --minimal          Install only the core Wayland build/runtime set
                     (no Skia stack, no fonts, no Vulkan headers).
  --with-webview     Also install WebKitGTK development packages
                     (libwebkit2gtk-4.1-dev) for native WebView support.
  --check            Only verify that required packages are installed.
  --print-packages   Print the apt package list for the selected set and exit.
  --no-sudo          Run apt-get directly instead of through sudo.
  -h, --help         Show this help.
EOF
}

base_packages=(
  build-essential
  git
  curl
  ca-certificates
  pkg-config
  unzip
  python3
)

wayland_packages=(
  libwayland-dev
  libwayland-bin
  wayland-protocols
  libglib2.0-dev
  zlib1g-dev
)

runtime_packages=(
  weston
  libegl1
  libegl-mesa0
  libgles2
  zenity
)

skia_packages=(
  libfontconfig1-dev
  libfreetype-dev
  libharfbuzz-dev
  ninja-build
  clang
  fonts-noto-cjk
  fonts-noto-core
  fonts-dejavu-core
  fonts-noto-color-emoji
  libvulkan-dev
)

webview_packages=(
  libwebkit2gtk-4.1-dev
)

minimal_only=0
with_webview=0
check_only=0
print_packages=0
use_sudo=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --minimal) minimal_only=1; shift ;;
    --with-webview) with_webview=1; shift ;;
    --check) check_only=1; shift ;;
    --print-packages) print_packages=1; shift ;;
    --no-sudo) use_sudo=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

packages=("${base_packages[@]}" "${wayland_packages[@]}" "${runtime_packages[@]}")
if [[ $minimal_only -eq 0 ]]; then
  packages+=("${skia_packages[@]}")
fi
if [[ $with_webview -eq 1 ]]; then
  packages+=("${webview_packages[@]}")
fi

if [[ $print_packages -eq 1 ]]; then
  printf '%s\n' "${packages[@]}"
  exit 0
fi

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "Linux dependencies can only be installed on Linux." >&2
  exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
  echo "apt-get was not found; install these packages manually:" >&2
  printf '  %s\n' "${packages[@]}" >&2
  exit 1
fi

missing=()
for package in "${packages[@]}"; do
  if ! dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -Fq 'install ok installed'; then
    missing+=("$package")
  fi
done

if [[ ${#missing[@]} -eq 0 ]]; then
  echo "Linux dependencies are installed."
  exit 0
fi

if [[ $check_only -eq 1 ]]; then
  echo "Missing Linux dependencies:" >&2
  printf '  %s\n' "${missing[@]}" >&2
  exit 1
fi

apt=(apt-get)
if [[ $use_sudo -eq 1 && ${EUID:-$(id -u)} -ne 0 ]]; then
  if ! command -v sudo >/dev/null 2>&1; then
    echo "sudo was not found; rerun as root or pass --no-sudo in a root shell." >&2
    exit 1
  fi
  apt=(sudo apt-get)
fi

echo "Installing Linux dependencies: ${missing[*]}"
"${apt[@]}" update
"${apt[@]}" install -y "${missing[@]}"
