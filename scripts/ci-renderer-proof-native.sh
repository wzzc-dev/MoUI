#!/usr/bin/env sh
set -eu

backend="${1:-}"
platform="${2:-}"

if [ -z "$backend" ] || [ -z "$platform" ]; then
  printf 'Usage: sh scripts/ci-renderer-proof-native.sh <wgpu-native|skia-native> <macos|windows|linux>\n' >&2
  exit 2
fi

case "$backend" in
  wgpu-native|skia-native) ;;
  *)
    printf 'Unknown renderer proof backend: %s\n' "$backend" >&2
    exit 2
    ;;
esac

case "$platform" in
  macos|windows|linux) ;;
  *)
    printf 'Unknown renderer proof platform: %s\n' "$platform" >&2
    exit 2
    ;;
esac

artifact_name="moui-renderer-proof-${backend}-${platform}"
proof_dir="artifacts/conformance/renderer-proof"
platform_dir="artifacts/platform-evidence/${platform}"
log_path="${proof_dir}/${backend}-${platform}.log"
manifest_path="${proof_dir}/${backend}-${platform}.json"

mkdir -p "$proof_dir" "$platform_dir"
record_logs=

run() {
  printf '\n==> %s\n' "$*" >> "$log_path"
  if ! "$@" >> "$log_path" 2>&1; then
    cat "$log_path"
    exit 1
  fi
}

printf 'MoUI renderer proof backend=%s platform=%s\n' "$backend" "$platform" > "$log_path"
record_logs="$log_path"

if [ "$backend" = "wgpu-native" ]; then
  run moon test moui/render/wgpu --target native
  run moon test moui/render/wgpu/text_protocol --target native
  case "$platform" in
    macos) run moon test moui/backend/macos/wgpu --target native ;;
    windows) run moon test moui/backend/windows/wgpu --target native ;;
    linux) run moon test moui/backend/linux/wgpu --target native ;;
  esac
  printf '%s\n' 'MoUI renderer proof package tests passed for native WGPU.' >> "$log_path"
else
  skia_text_emoji_log_path="${platform_dir}/skia-text-emoji-smoke.log"
  record_logs="${record_logs} ${skia_text_emoji_log_path}"
  cat > "$skia_text_emoji_log_path" <<EOF
MoUI Skia text/emoji smoke platform=${platform}
status=failed
missing colorEmojiPixels: requires real Skia high-saturation color emoji pixels or Skia glyph/paragraph evidence.
missing zwjGrapheme: requires single grapheme cluster and no interior caret evidence.
missing bidiLayout: requires visual-order glyph/paragraph evidence.
missing paragraphWrapping: requires line metrics and later-line pixels.
EOF
  run moon test moui/render/skia --target native
  case "$platform" in
    macos) run moon test moui/backend/macos/skia --target native ;;
    windows) run moon test moui/backend/windows/skia --target native ;;
    linux) run moon test moui/backend/linux/skia --target native ;;
  esac
  printf '%s\n' 'MoUI renderer proof package tests passed for native Skia.' >> "$log_path"
fi

cat >> "$log_path" <<'EOF'
MoUI renderer proof radialGradient missing: requires true radial center/mid/edge pixel artifact.
MoUI renderer proof transformPixels missing: requires nested transform/clip/layer/filter pixel artifact.
MoUI renderer proof colorEmojiPixels missing: requires real high-saturation emoji raster/glyph evidence.
MoUI renderer proof zwjGrapheme missing: requires single grapheme cluster and no interior caret evidence.
MoUI renderer proof bidiLayout missing: requires visual-order evidence.
MoUI renderer proof paragraphWrapping missing: requires line metrics and later-line pixels.
MoUI renderer proof asyncImageSecondFrame missing: requires late completion, repaint request, and second-frame pixels.
EOF

set -- scripts/record-renderer-proof-manifest.mjs \
  --backend "$backend" \
  --platform "$platform" \
  --artifact-name "$artifact_name" \
  --output "$manifest_path"

for path in $record_logs; do
  set -- "$@" --log "$path"
done

node "$@"

printf 'renderer proof native manifest recorded: %s\n' "$manifest_path"
