#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/build-component-gallery-android-apk.sh [options]

Build the experimental Component Gallery Android debug APK.

Options:
  --abi <abi>          Android ABI, default arm64-v8a.
  --api <level>       Android min/platform API, default 23.
  --compile-sdk <n>   Android compile SDK, default 35.
  --build-dir <dir>   Working directory, default artifacts/android/component_gallery.
  --output <apk>      APK output, default artifacts/android/component_gallery/app-debug.apk.
  --fallback-skia     Do not fetch/link real Skia; build packaging plumbing only.
  --prepare-only      Generate MoonBit C and configure CMake, then stop.
  -h, --help          Show this help.

Real Android rendering requires the default Skia path. --fallback-skia is only a
fast build-system smoke; the resulting native library reports Skia unavailable.
The default Android Skia link mode is dynamic so the APK can package libskia.so.
USAGE
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
abi="arm64-v8a"
api_level="23"
compile_sdk="35"
build_dir="$repo_root/artifacts/android/component_gallery"
output_apk=""
fallback_skia=0
prepare_only=0
skia_link_mode="${MOUI_SKIA_LINK_MODE:-dynamic}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --abi)
      abi="${2:?missing ABI after --abi}"
      shift 2
      ;;
    --api)
      api_level="${2:?missing API level after --api}"
      shift 2
      ;;
    --compile-sdk)
      compile_sdk="${2:?missing SDK level after --compile-sdk}"
      shift 2
      ;;
    --build-dir)
      build_dir="${2:?missing directory after --build-dir}"
      shift 2
      ;;
    --output)
      output_apk="${2:?missing APK path after --output}"
      shift 2
      ;;
    --fallback-skia)
      fallback_skia=1
      shift
      ;;
    --prepare-only)
      prepare_only=1
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

case "$build_dir" in
  /*) ;;
  *) build_dir="$repo_root/$build_dir" ;;
esac

if [ -n "$output_apk" ]; then
  case "$output_apk" in
    /*) ;;
    *) output_apk="$repo_root/$output_apk" ;;
  esac
fi

case "$abi" in
  arm64-v8a)
    skia_arch="arm64"
    ndk_abi_triple="aarch64-linux-android"
    ;;
  x86_64)
    skia_arch="x64"
    ndk_abi_triple="x86_64-linux-android"
    ;;
  riscv64)
    skia_arch="riscv64"
    ndk_abi_triple="riscv64-linux-android"
    ;;
  *)
    echo "unsupported ABI for locked Android Skia artifacts: $abi" >&2
    exit 2
    ;;
esac

log() {
  printf '[moui-component-gallery-android] %s\n' "$*"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "required command not found: $1" >&2
    exit 1
  fi
}

json_var() {
  node -e '
const fs = require("fs");
const key = process.argv[1];
const input = fs.readFileSync(0, "utf8");
const parsed = JSON.parse(input);
process.stdout.write((parsed.vars && parsed.vars[key]) || "");
' "$1"
}

first_link_dir() {
  local flags="$1"
  local flag
  for flag in $flags; do
    case "$flag" in
      -L?*)
        printf '%s\n' "${flag#-L}"
        return 0
        ;;
    esac
  done
  return 1
}

contains_link_flag() {
  local flags="$1"
  local expected="$2"
  local flag
  for flag in $flags; do
    if [ "$flag" = "$expected" ]; then
      return 0
    fi
  done
  return 1
}

find_ndk_libcxx_shared() {
  local candidate
  candidate="$(
    find "$ndk_home/toolchains/llvm/prebuilt" \
      -path "*/sysroot/usr/lib/$ndk_abi_triple/libc++_shared.so" \
      -type f \
      -print 2>/dev/null | head -n 1
  )"
  if [ -n "$candidate" ]; then
    printf '%s\n' "$candidate"
    return 0
  fi
  return 1
}

latest_child_dir() {
  local parent="$1"
  if [ ! -d "$parent" ]; then
    return 1
  fi
  find "$parent" -mindepth 1 -maxdepth 1 -type d | sort | tail -n 1
}

android_home="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
if [ -z "$android_home" ]; then
  for candidate_android_home in "$HOME/Library/Android/sdk" "$HOME/Android/Sdk"; do
    if [ -d "$candidate_android_home" ]; then
      android_home="$candidate_android_home"
      break
    fi
  done
fi
if [ -z "$android_home" ]; then
  echo "ANDROID_HOME or ANDROID_SDK_ROOT must point at an Android SDK." >&2
  echo "Run scripts/setup-android-sdk.sh --accept-licenses, then eval \"\$(scripts/setup-android-sdk.sh --print-env)\"." >&2
  exit 1
fi

ndk_home="${ANDROID_NDK_HOME:-}"
if [ -z "$ndk_home" ]; then
  if [ -d "$android_home/ndk-bundle" ]; then
    ndk_home="$android_home/ndk-bundle"
  else
    ndk_home="$(latest_child_dir "$android_home/ndk" || true)"
  fi
fi

if [ -z "$ndk_home" ] || [ ! -f "$ndk_home/build/cmake/android.toolchain.cmake" ]; then
  echo "Android NDK not found. Set ANDROID_NDK_HOME or install an SDK NDK." >&2
  exit 1
fi

build_tools="$(latest_child_dir "$android_home/build-tools" || true)"
if [ -z "$build_tools" ]; then
  echo "Android build-tools not found under $android_home/build-tools." >&2
  exit 1
fi

android_jar="$android_home/platforms/android-$compile_sdk/android.jar"
if [ ! -f "$android_jar" ]; then
  echo "Android platform jar not found: $android_jar" >&2
  exit 1
fi

require_cmd moon
require_cmd node
require_cmd cmake
require_cmd javac
require_cmd keytool
require_cmd zip

aapt="$build_tools/aapt"
d8="$build_tools/d8"
zipalign="$build_tools/zipalign"
apksigner="$build_tools/apksigner"
for tool in "$aapt" "$d8" "$zipalign" "$apksigner"; do
  if [ ! -x "$tool" ]; then
    echo "required Android build-tool not executable: $tool" >&2
    exit 1
  fi
done

moon_home="${MOON_HOME:-$HOME/.moon}"
if [ ! -f "$moon_home/lib/runtime.c" ] || [ ! -f "$moon_home/include/moonbit.h" ]; then
  echo "MoonBit runtime headers not found under $moon_home. Set MOON_HOME if needed." >&2
  exit 1
fi

if [ -z "$output_apk" ]; then
  output_apk="$build_dir/app-debug.apk"
fi

moon_target_dir="$build_dir/moonbit"
cmake_build_dir="$build_dir/cmake/$abi"
java_build_dir="$build_dir/java"
apk_work_dir="$build_dir/apk-work"
mkdir -p "$build_dir" "$moon_target_dir"

log "Generating MoonBit native C for examples/component_gallery/android"
(
  cd "$repo_root"
  MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 \
  MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM=1 \
    moon build examples/component_gallery/android --target native --target-dir "$moon_target_dir"
)

moonbit_c="$moon_target_dir/native/debug/build/examples/component_gallery/android/android.c"
if [ ! -f "$moonbit_c" ]; then
  echo "MoonBit generated C was not found: $moonbit_c" >&2
  exit 1
fi

skia_stub_flags=""
skia_link_flags=""
apk_shared_libs=()
ndk_libcxx_shared="$(find_ndk_libcxx_shared || true)"
if [ -n "$ndk_libcxx_shared" ]; then
  apk_shared_libs+=("$ndk_libcxx_shared")
fi
if [ "$fallback_skia" -eq 0 ]; then
  log "Resolving Android Skia provider flags for $abi"
  if ! skia_json="$(
    cd "$repo_root/moui_skia"
    MOUI_SKIA_PLATFORM=android \
    MOUI_SKIA_ARCH="$skia_arch" \
    MOUI_SKIA_LINK_MODE="$skia_link_mode" \
      node build.js <<'EOF'
{}
EOF
  )"; then
    echo "failed to resolve Android Skia. Use --fallback-skia for a packaging-only smoke." >&2
    exit 1
  fi
  skia_stub_flags="$(printf '%s' "$skia_json" | json_var MOUI_SKIA_STUB_CC_FLAGS)"
  skia_link_flags="$(printf '%s' "$skia_json" | json_var MOUI_SKIA_CC_LINK_FLAGS)"
  if contains_link_flag "$skia_link_flags" "-lskia"; then
    skia_lib_dir="$(first_link_dir "$skia_link_flags" || true)"
    if [ -n "$skia_lib_dir" ] && [ -f "$skia_lib_dir/libskia.so" ]; then
      apk_shared_libs+=("$skia_lib_dir/libskia.so")
    fi
  fi
else
  log "Using fallback Skia mode; APK/native library will not render real Skia frames"
fi

cmake_args=(
  -S "$repo_root/examples/component_gallery/android_app/app/src/main/cpp"
  -B "$cmake_build_dir"
  "-DCMAKE_TOOLCHAIN_FILE=$ndk_home/build/cmake/android.toolchain.cmake"
  "-DANDROID_ABI=$abi"
  "-DANDROID_PLATFORM=android-$api_level"
  "-DMOUI_REPO_ROOT=$repo_root"
  "-DMOUI_MOON_HOME=$moon_home"
  "-DMOUI_COMPONENT_GALLERY_ANDROID_MOONBIT_C=$moonbit_c"
  "-DMOUI_SKIA_STUB_CC_FLAGS=$skia_stub_flags"
  "-DMOUI_SKIA_CC_LINK_FLAGS=$skia_link_flags"
)

if command -v ninja >/dev/null 2>&1; then
  cmake_args=(-G Ninja "${cmake_args[@]}")
fi

log "Configuring Android native library with CMake"
cmake "${cmake_args[@]}"

if [ "$prepare_only" -eq 1 ]; then
  log "Prepared Android build inputs in $build_dir"
  exit 0
fi

log "Building Android native library"
cmake --build "$cmake_build_dir"
native_lib="$(find "$cmake_build_dir" -name libcomponent_gallery_android.so -type f | head -n 1)"
if [ -z "$native_lib" ]; then
  echo "native library was not produced under $cmake_build_dir" >&2
  exit 1
fi

app_src="$repo_root/examples/component_gallery/android_app/app/src/main"
manifest_src="$app_src/AndroidManifest.xml"
manifest_for_aapt="$java_build_dir/AndroidManifest.xml"
generated_java="$java_build_dir/generated"
classes_dir="$java_build_dir/classes"
dex_dir="$java_build_dir/dex"
resources_ap="$build_dir/resources.ap_"
unsigned_apk="$build_dir/app-unsigned.apk"
aligned_apk="$build_dir/app-aligned.apk"

rm -rf "$java_build_dir" "$apk_work_dir" "$resources_ap" "$unsigned_apk" "$aligned_apk"
mkdir -p "$generated_java" "$classes_dir" "$dex_dir" "$apk_work_dir/lib/$abi"
sed 's#<manifest xmlns:android=#<manifest package="dev.wzzc.moui.componentgallery" xmlns:android=#' \
  "$manifest_src" > "$manifest_for_aapt"

log "Packaging Android resources"
"$aapt" package \
  -f \
  -m \
  -J "$generated_java" \
  -M "$manifest_for_aapt" \
  -S "$app_src/res" \
  -I "$android_jar" \
  --min-sdk-version "$api_level" \
  --target-sdk-version "$compile_sdk" \
  --version-code 1 \
  --version-name 0.1.0 \
  -F "$resources_ap"

log "Compiling Java activity"
javac \
  -source 8 \
  -target 8 \
  -bootclasspath "$android_jar" \
  -classpath "$android_jar" \
  -d "$classes_dir" \
  "$generated_java/dev/wzzc/moui/componentgallery/R.java" \
  "$app_src/java/dev/wzzc/moui/componentgallery/MainActivity.java"

class_file_list="$java_build_dir/class-files.txt"
find "$classes_dir" -name '*.class' -type f | sort > "$class_file_list"
if [ ! -s "$class_file_list" ]; then
  echo "javac produced no class files" >&2
  exit 1
fi

log "Dexing Java classes"
xargs "$d8" --min-api "$api_level" --lib "$android_jar" --output "$dex_dir" < "$class_file_list"

log "Assembling unsigned APK"
cp "$resources_ap" "$unsigned_apk"
(
  cd "$dex_dir"
  zip -q -r "$unsigned_apk" classes.dex
)
cp "$native_lib" "$apk_work_dir/lib/$abi/libcomponent_gallery_android.so"
for shared_lib in "${apk_shared_libs[@]}"; do
  log "Packaging native dependency $(basename "$shared_lib")"
  cp "$shared_lib" "$apk_work_dir/lib/$abi/$(basename "$shared_lib")"
done
(
  cd "$apk_work_dir"
  zip -q -r "$unsigned_apk" lib
)

log "Aligning and signing debug APK"
"$zipalign" -f -p 4 "$unsigned_apk" "$aligned_apk"
keystore="$build_dir/debug.keystore"
if [ ! -f "$keystore" ]; then
  keytool -genkeypair \
    -keystore "$keystore" \
    -storepass android \
    -keypass android \
    -alias androiddebugkey \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    -dname "CN=Android Debug,O=Android,C=US" >/dev/null
fi

mkdir -p "$(dirname "$output_apk")"
"$apksigner" sign \
  --ks "$keystore" \
  --ks-pass pass:android \
  --key-pass pass:android \
  --out "$output_apk" \
  "$aligned_apk"
"$apksigner" verify "$output_apk"

log "Wrote $output_apk"
