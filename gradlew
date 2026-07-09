#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
gradle_version="${MOUI_GRADLE_VERSION:-9.6.1}"
gradle_home="$repo_root/.gradle/moui-gradle-$gradle_version"
gradle_bin="$gradle_home/gradle-$gradle_version/bin/gradle"

if [ -x "$gradle_bin" ]; then
  exec "$gradle_bin" "$@"
fi

if [ -n "${MOUI_GRADLE_BIN:-}" ]; then
  if [ -x "$MOUI_GRADLE_BIN" ]; then
    exec "$MOUI_GRADLE_BIN" "$@"
  fi
  echo "MOUI_GRADLE_BIN is not executable: $MOUI_GRADLE_BIN" >&2
  exit 1
fi

cached_gradle=""
if [ -d "$HOME/.gradle/wrapper/dists/gradle-$gradle_version-bin" ]; then
  cached_gradle="$(find "$HOME/.gradle/wrapper/dists/gradle-$gradle_version-bin" -path "*/gradle-$gradle_version/bin/gradle" -type f -perm -111 2>/dev/null | head -n 1 || true)"
fi
if [ -n "$cached_gradle" ]; then
  exec "$cached_gradle" "$@"
fi

mkdir -p "$gradle_home"
zip_path="$gradle_home/gradle-$gradle_version-bin.zip"
url="https://services.gradle.org/distributions/gradle-$gradle_version-bin.zip"

download_gradle() {
  tmp_path="$zip_path.part"
  rm -f "$tmp_path"
  if command -v curl >/dev/null 2>&1; then
    curl --http1.1 --retry 3 --retry-delay 2 --retry-connrefused -fL "$url" -o "$tmp_path"
  elif command -v wget >/dev/null 2>&1; then
    wget -O "$tmp_path" "$url"
  else
    echo "gradle is not installed, and neither curl nor wget is available to fetch $url" >&2
    exit 1
  fi
  mv "$tmp_path" "$zip_path"
}

if [ ! -f "$zip_path" ]; then
  download_gradle
fi

if command -v unzip >/dev/null 2>&1; then
  if ! unzip -t "$zip_path" >/dev/null 2>&1; then
    echo "Cached Gradle distribution is corrupt; re-downloading $url" >&2
    rm -f "$zip_path"
    download_gradle
    unzip -t "$zip_path" >/dev/null
  fi
  unzip -q -o "$zip_path" -d "$gradle_home"
else
  echo "unzip is required to unpack $zip_path" >&2
  exit 1
fi

exec "$gradle_bin" "$@"
