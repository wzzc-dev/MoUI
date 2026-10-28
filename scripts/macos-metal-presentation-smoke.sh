#!/usr/bin/env bash
# Real-window presentation smoke for the direct-GPU (no Skia, no wgpu) route.
#
# The renderer has had offscreen pixel proofs and a real-provider text smoke, and
# no committed step ever ran it in a window. This script is that step: it launches
# the Showcase entrypoint with the host's first-frame auto-exit flag and requires
# two lines -- the entrypoint's renderer identity (built from the module's own
# descriptor and capability rows) and the host's "presented first frame" marker.
# The second alone would also be printed by another renderer presenting the same
# window, which is why the first is asked for as well.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
cd "$repo_root"

# moon is not on every host's default PATH; the validators that shell out to it
# fail as "spawnSync moon ENOENT" rather than reporting anything real when it is
# missing, so a smoke script sets it the same way.
export PATH="$HOME/.moon/bin:$PATH"

entrypoint="examples/showcase/macos_metal"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --entrypoint) entrypoint="$2"; shift 2 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

log="$(mktemp -t moui-metal-presentation)"
cleanup() { rm -f "$log"; }
trap cleanup EXIT

status=0
MOUI_MACOS_METAL_EXIT_AFTER_FIRST_PRESENT=1 \
  MOUI_MACOS_METAL_PRESENT_SMOKE=1 \
  moon run "$entrypoint" --target native >"$log" 2>&1 || status=$?
cat "$log"

if [ "$status" -ne 0 ]; then
  echo "FAIL: $entrypoint exited with status $status" >&2
  exit 1
fi

identity="$(grep -c 'MoUI macos_metal renderer=direct-gpu family=direct-gpu provider=metal-direct' "$log" || true)"
presented="$(grep -c 'macOS renderer presented first frame' "$log" || true)"
stalled="$(grep -c 'first-frame smoke did not present before pump limit' "$log" || true)"

if [ "${stalled:-0}" -gt 0 ]; then
  echo "FAIL: the host reported no first present before its pump limit" >&2
  exit 1
fi
if [ "${identity:-0}" -lt 1 ]; then
  echo "FAIL: no renderer identity line; the presenting route is unnamed" >&2
  exit 1
fi
if [ "${presented:-0}" -lt 1 ]; then
  echo "FAIL: no first-frame present marker from the host" >&2
  exit 1
fi

# The presented surface itself: the host copies the drawable it is about to
# present and counts the pixels that differ from the frame's clear colour. A run
# that presented an untouched surface -- a wrong-size layer, a pass that cleared
# and never drew -- gets the marker line above and still fails here.
reading=$(grep -oE 'MOUI-METAL-PRESENT width=[0-9]+ height=[0-9]+ ink=[0-9]+' "$log" | tail -1)
if [ -z "$reading" ]; then
  echo "FAIL: no presented-surface readback line; the smoke flag did not reach the host" >&2
  exit 1
fi
width=$(printf '%s' "$reading" | awk '{print substr($2,7)}')
height=$(printf '%s' "$reading" | awk '{print substr($3,8)}')
ink=$(printf '%s' "$reading" | awk '{print substr($4,5)}')
if [ -z "$width" ] || [ -z "$height" ] || [ -z "$ink" ]; then
  echo "FAIL: no presented-surface readback line; the smoke flag did not reach the host" >&2
  exit 1
fi
total=$((width * height))
floor=$((total / 200))
ceiling=$((total - total / 200))
# Between 0.5% and 99.5% of the surface: some ink must be present, and a surface
# differing from its clear colour everywhere is a broken clear, not a UI.
if [ "$total" -le 0 ] || [ "$ink" -le "$floor" ] || [ "$ink" -ge "$ceiling" ]; then
  echo "FAIL: presented surface has ink=$ink of $total pixels" >&2
  exit 1
fi

echo "MoUI metal presentation smoke passed identity+first-frame+surface-ink ink=$ink/$total entrypoint=$entrypoint"
