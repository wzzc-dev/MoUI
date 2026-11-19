#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/capture-showcase-sun.sh --out PATH [--section 0|1|2]

Runs examples/showcase/linux_sun on a headless X server, waits for the
"MoUI Showcase" window and saves that window's rectangle as a PNG with scrot.

Sections:
  0  Welcome (first screen, default)
  1  diagnostics/advanced-rendering
  2  components/accessibility-probe

Reproducible evidence for the Sun visual-parity work. Requires moon on PATH,
xvfb-run, xwininfo and scrot (all part of scripts/set_linux_deps.sh);
ffmpeg is used to crop the window out of the full-screen grab when present.
EOF
}

out=""
section=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --out)
      out="${2:-}"
      shift 2
      ;;
    --section)
      section="${2:-}"
      shift 2
      ;;
    -h | --help)
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

if [[ -z "$out" ]]; then
  usage >&2
  exit 2
fi
case "$section" in
  0 | 1 | 2) ;;
  *)
    echo "--section must be 0, 1 or 2" >&2
    exit 2
    ;;
esac

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
out_dir="$(dirname -- "$out")"
mkdir -p "$out_dir"
out_abs="$(CDPATH= cd -- "$out_dir" && pwd)/$(basename -- "$out")"

# Re-exec inside xvfb-run so the capture does not depend on a developer's
# display server. The marker also prevents a second re-exec.
if [[ "${MOUI_CAPTURE_XVFB:-}" != "1" ]]; then
  MOUI_CAPTURE_XVFB=1 exec xvfb-run -a -s "-screen 0 1600x1000x24" \
    "$0" --section "$section" --out "$out_abs"
fi

for tool in moon xwininfo scrot setsid; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "$tool is not on PATH" >&2
    exit 1
  fi
done

section_env=()
case "$section" in
  1) section_env=(MOUI_SHOWCASE_SECTION_1=1) ;;
  2) section_env=(MOUI_SHOWCASE_SECTION_2=1) ;;
esac

log="$(mktemp)"
cleanup() {
  if [[ -n "${app_pid:-}" ]]; then
    kill -- "-$app_pid" 2>/dev/null || kill "$app_pid" 2>/dev/null || true
  fi
  rm -f "$log"
  if [[ -n "${full:-}" ]]; then
    rm -f "$full"
  fi
}
trap cleanup EXIT

cd "$repo_root"
setsid env "${section_env[@]}" moon -C examples/showcase run linux_sun --target native \
  >"$log" 2>&1 &
app_pid=$!
# Start the app in its own session/process group so the whole `moon run` tree
# stops on cleanup.
if ! kill -0 "$app_pid" 2>/dev/null; then
  echo "failed to start examples/showcase/linux_sun" >&2
  cat "$log" >&2
  exit 1
fi

# Wait for Sun's first full-window raster. A direct window grab this early can
# return an unpainted drawable on Xvfb without a window manager, so grab the
# full screen (a known-good path) and crop the window rectangle out of it.
sleep 20
full="$(mktemp --suffix=.png)"
rm -f "$full"
if command -v ffmpeg >/dev/null 2>&1; then
  cropper="ffmpeg"
else
  cropper=""
fi

if ! xwininfo -name "MoUI Showcase" >/dev/null 2>&1; then
  echo "the MoUI Showcase window did not appear" >&2
  cat "$log" >&2
  exit 1
fi

geometry="$(xwininfo -name "MoUI Showcase")"
field() {
  printf '%s\n' "$geometry" | awk -F': ' -v key="$1" '$0 ~ key {gsub(/ /, "", $2); print $2; exit}'
}
x="$(field "Absolute upper-left X")"
y="$(field "Absolute upper-left Y")"
width="$(field "Width")"
height="$(field "Height")"
if [[ -z "$x" || -z "$y" || -z "$width" || -z "$height" ]]; then
  echo "could not read the Showcase window rectangle" >&2
  printf '%s\n' "$geometry" >&2
  exit 1
fi

capture_window() {
  scrot -o "$full"
  if [[ -n "$cropper" ]]; then
    ffmpeg -loglevel error -y -i "$full" \
      -vf "crop=${width}:${height}:${x}:${y}" -frames:v 1 "$out_abs"
  else
    scrot -o -a "$x,$y,$width,$height" "$out_abs"
  fi
}

# Capture until the PNG is larger than a blank frame (a uniform image
# compresses to a couple of KB), so the evidence never records a black frame.
min_bytes=10000
for _ in $(seq 1 20); do
  capture_window
  if [[ -s "$out_abs" && "$(stat -c %s "$out_abs")" -gt "$min_bytes" ]]; then
    break
  fi
  sleep 2
done
rm -f "$full"
if [[ ! -s "$out_abs" || "$(stat -c %s "$out_abs")" -le "$min_bytes" ]]; then
  echo "the Showcase window stayed blank at $out_abs" >&2
  cat "$log" >&2
  exit 1
fi

echo "captured $out_abs (section $section, ${width}x${height} at $x,$y)"
