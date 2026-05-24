#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT_DIR"

PACKAGE="examples/showcase/macos"
APP_NAME=""
BUNDLE_ID="dev.wzzc.moui.app"
OUTPUT_DIR="dist/macos"
VERSION="0.1.0"
BUILD_VERSION="1"
SKIP_BUILD=false

usage() {
  printf 'Usage: %s [--package <moon-package>] [--name <app-name>] [--bundle-id <id>] [--version <semver>] [--build-version <build>] [--output <dir>] [--no-build]\n' "$0"
  printf '\n'
  printf 'Builds a native macOS example package and wraps the executable in a .app bundle.\n'
  printf 'Example: %s --package examples/showcase/macos --name "MoUI Showcase" --bundle-id dev.wzzc.moui.showcase --version 0.1.0\n' "$0"
}

xml_text() {
  printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

json_text() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --package)
      PACKAGE="${2:?missing value for --package}"
      shift 2
      ;;
    --name)
      APP_NAME="${2:?missing value for --name}"
      shift 2
      ;;
    --bundle-id)
      BUNDLE_ID="${2:?missing value for --bundle-id}"
      shift 2
      ;;
    --version)
      VERSION="${2:?missing value for --version}"
      shift 2
      ;;
    --build-version)
      BUILD_VERSION="${2:?missing value for --build-version}"
      shift 2
      ;;
    --output)
      OUTPUT_DIR="${2:?missing value for --output}"
      shift 2
      ;;
    --no-build)
      SKIP_BUILD=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

PACKAGE_LEAF="$(basename "$PACKAGE")"
PACKAGE_PARENT="$(basename "$(dirname "$PACKAGE")")"
if [ -z "$APP_NAME" ]; then
  APP_NAME="$PACKAGE_PARENT"
fi

EXE_PATH="_build/native/debug/build/$PACKAGE/$PACKAGE_LEAF.exe"
APP_DIR="$OUTPUT_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
APP_EXE="$MACOS_DIR/$PACKAGE_LEAF"

if [ "$SKIP_BUILD" = false ]; then
  printf '==> Building %s\n' "$PACKAGE"
  moon build "$PACKAGE" --target native
fi

if [ ! -f "$EXE_PATH" ]; then
  printf 'Built executable not found: %s\n' "$EXE_PATH" >&2
  exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$EXE_PATH" "$APP_EXE"
chmod +x "$APP_EXE"

PLIST_EXECUTABLE="$(xml_text "$PACKAGE_LEAF")"
PLIST_BUNDLE_ID="$(xml_text "$BUNDLE_ID")"
PLIST_APP_NAME="$(xml_text "$APP_NAME")"
PLIST_VERSION="$(xml_text "$VERSION")"
PLIST_BUILD_VERSION="$(xml_text "$BUILD_VERSION")"

cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$PLIST_EXECUTABLE</string>
  <key>CFBundleIdentifier</key>
  <string>$PLIST_BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$PLIST_APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$PLIST_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$PLIST_BUILD_VERSION</string>
  <key>LSMinimumSystemVersion</key>
  <string>12.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
EOF

JSON_APP_NAME="$(json_text "$APP_NAME")"
JSON_PACKAGE="$(json_text "$PACKAGE")"
JSON_BUNDLE_ID="$(json_text "$BUNDLE_ID")"
JSON_VERSION="$(json_text "$VERSION")"
JSON_BUILD_VERSION="$(json_text "$BUILD_VERSION")"
JSON_EXECUTABLE="$(json_text "$PACKAGE_LEAF")"
JSON_BUNDLE="$(json_text "$APP_NAME.app")"

cat > "$RESOURCES_DIR/moui-package.json" <<EOF
{
  "appName": "$JSON_APP_NAME",
  "package": "$JSON_PACKAGE",
  "bundleIdentifier": "$JSON_BUNDLE_ID",
  "version": "$JSON_VERSION",
  "buildVersion": "$JSON_BUILD_VERSION",
  "executable": "$JSON_EXECUTABLE",
  "bundle": "$JSON_BUNDLE"
}
EOF

printf '==> Wrote %s\n' "$APP_DIR"
