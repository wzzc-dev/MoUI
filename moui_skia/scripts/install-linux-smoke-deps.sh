#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/install-linux-smoke-deps.sh [options]

Installs the Ubuntu packages needed by the Linux real Skia smoke path. The
package set covers the MoonBit installer, Skia checkout/sync, GN/Ninja build,
Clang-based Skia compilation, and native C++ stub compilation.

Options:
  --check           Only verify that required packages are installed.
  --print-packages  Print the apt package list and exit.
  --no-sudo         Run apt-get directly instead of through sudo.
  -h, --help        Show this help.
EOF
}

packages=(
  build-essential
  git
  python3
  ninja-build
  clang
  curl
  ca-certificates
  libfontconfig1-dev
  libfreetype-dev
  libharfbuzz-dev
  fonts-noto-cjk
  libwayland-dev
  libwayland-bin
  wayland-protocols
)

check_only=0
use_sudo=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)
      check_only=1
      shift
      ;;
    --print-packages)
      printf '%s\n' "${packages[@]}"
      exit 0
      ;;
    --no-sudo)
      use_sudo=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "Linux smoke dependencies can only be installed on Linux." >&2
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
  echo "Linux Skia smoke dependencies are installed."
  exit 0
fi

if [[ $check_only -eq 1 ]]; then
  echo "Missing Linux Skia smoke dependencies:" >&2
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

echo "Installing Linux Skia smoke dependencies: ${missing[*]}"
"${apt[@]}" update
"${apt[@]}" install -y "${missing[@]}"
