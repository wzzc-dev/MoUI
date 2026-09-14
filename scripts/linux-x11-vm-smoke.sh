#!/usr/bin/env bash
set -euo pipefail

# Linux X11 windowing smoke for the UTM Ubuntu VM (or any Linux host).
#
# Runs the window module's moui_linux_smoke example against Xvfb with the X11
# backend forced, then verifies the backend selection log line and the smoke
# sentinel output. A Wayland leg (headless Weston) runs for regression when a
# compositor is available.
#
# Works from two layouts:
# - MoUI repository root (uses ./window/modules/window via window dev mode).
# - The window submodule root (standalone: `moui-window/` on the VM).
#
# Usage:
#   sh scripts/linux-x11-vm-smoke.sh               # Xvfb X11 leg (+ auto + Wayland)
#   sh scripts/linux-x11-vm-smoke.sh --x11-only    # skip the auto/Wayland legs
#
# Environment:
#   X11VM_DISPLAY   X display for the Xvfb legs (default :99)
#   X11VM_TIMEOUT   smoke timeout seconds (default 30)
#
# Evidence lands in artifacts/linux-x11-vm/ (MoUI root) or artifacts/ (standalone).

set_layout() {
  if [[ -f "scripts/window-dev-mode.sh" && -d "window/modules/window" ]]; then
    layout="root"
    evidence_dir="artifacts/linux-x11-vm"
    smoke_pkg="window/modules/window/examples/moui_linux_smoke"
  elif [[ -f "modules/window/examples/moui_linux_smoke/moon.pkg" ]]; then
    layout="standalone"
    evidence_dir="artifacts"
    smoke_pkg="modules/window/examples/moui_linux_smoke"
  else
    echo "run this script from a MoUI repository root or a window submodule checkout" >&2
    exit 2
  fi
}

ROOT="$(pwd)"
x11_only=0
for arg in "$@"; do
  case "$arg" in
    --x11-only) x11_only=1 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

display="${X11VM_DISPLAY:-:99}"
timeout_sec="${X11VM_TIMEOUT:-30}"
set_layout
mkdir -p "$evidence_dir"

fail() { printf 'linux-x11-vm smoke failed: %s\n' "$1" >&2; exit 1; }

if [[ "$(uname -s)" != "Linux" ]]; then
  fail "this script must run on the Linux VM, not on the macOS host"
fi
for tool in xvfb-run xdpyinfo moon node pkg-config; do
  command -v "$tool" >/dev/null 2>&1 || fail "missing tool: $tool (install deps via scripts/set_linux_deps.sh on MoUI root, or apt install the X11/Wayland set)"
done

if [[ "$layout" == "root" ]]; then
  # The X11 backend lives in the local window submodule workspace member.
  sh scripts/window-dev-mode.sh on >/dev/null 2>&1 || true
  grep -q "./window/modules/window" moon.work || fail "window dev mode did not activate"
fi

smoke_exe=""
build_smoke() {
  echo "=== building $smoke_pkg ($layout layout) ==="
  moon build "$smoke_pkg" --target native --release 2>&1 \
    | tee "$evidence_dir/build.log" | tail -3
  smoke_exe="$(find _build/native/release/build -type f -name "moui_linux_smoke.exe" -perm -111 -print -quit 2>/dev/null || true)"
  [[ -n "$smoke_exe" ]] || fail "smoke executable not found under _build"
}

require_sentinels() {
  local log="$1" leg="$2"
  for sentinel in "MOUILinuxSmoke: ready" "MOUILinuxSmoke: present result=0" \
    "MOUILinuxSmoke: destroy requested" "MOUILinuxSmoke: destroyed" \
    "MOUILinuxSmoke: finished"; do
    grep -Fq "$sentinel" "$log" || fail "$leg leg missing sentinel: $sentinel (see $log)"
  done
}

run_x11_leg() {
  echo "=== X11 leg (Xvfb $display) ==="
  local log="$evidence_dir/x11-smoke.log"
  set +e
  timeout "$timeout_sec" xvfb-run -a -s "-screen 0 1280x800x24" \
    env MOUI_LINUX_WINDOWING=x11 "$smoke_exe" >"$log" 2>&1
  local status=$?
  set -e
  grep -Fq "moui windowing backend: x11" "$log" \
    || fail "X11 leg did not select the x11 backend (see $log)"
  require_sentinels "$log" "x11"
  grep -Fq "MOUILinuxSmoke: handles wl_display=0x" "$log" &&
    grep -Fq "xdg_surface=0x0" "$log" \
    || fail "X11 leg did not report X11-style handles (see $log)"
  echo "x11 leg ok (exit=$status)"
  tail -4 "$log"
}

run_auto_leg() {
  echo "=== auto-selection leg (Xvfb DISPLAY only, expects x11) ==="
  local log="$evidence_dir/auto-smoke.log"
  set +e
  timeout "$timeout_sec" xvfb-run -a -s "-screen 0 1280x800x24" \
    env MOUI_LINUX_WINDOWING=auto "$smoke_exe" >"$log" 2>&1
  local status=$?
  set -e
  grep -Fq "moui windowing backend: x11 (auto)" "$log" \
    || fail "auto leg did not select x11 (see $log)"
  require_sentinels "$log" "auto"
  echo "auto leg ok (exit=$status)"
}

run_wayland_leg() {
  if ! command -v weston >/dev/null 2>&1; then
    echo "weston not installed; skipping Wayland regression leg"
    return 0
  fi
  echo "=== Wayland regression leg (headless Weston) ==="
  local log="$evidence_dir/wayland-smoke.log"
  local runtime_dir="${XDG_RUNTIME_DIR:-/tmp/moui-x11vm-wayland}"
  mkdir -p "$runtime_dir"
  local socket="way-x11vm-$$"
  weston --backend=headless-backend.so --socket="$socket" \
    --width=1280 --height=800 >"$evidence_dir/weston.log" 2>&1 &
  local weston_pid=$!
  sleep 3
  set +e
  timeout "$timeout_sec" env XDG_RUNTIME_DIR="$runtime_dir" \
    WAYLAND_DISPLAY="$socket" MOUI_LINUX_WINDOWING=wayland \
    WINDOW_MOUI_LINUX_REQUIRE_CURRENT_MONITOR=0 \
    "$smoke_exe" >"$log" 2>&1
  local status=$?
  set -e
  kill "$weston_pid" 2>/dev/null || true
  wait "$weston_pid" 2>/dev/null || true
  grep -Fq "moui windowing backend: wayland" "$log" \
    || fail "Wayland leg did not select the wayland backend (see $log)"
  require_sentinels "$log" "wayland"
  echo "wayland leg ok (exit=$status)"
}

build_smoke
run_x11_leg
if [[ $x11_only -eq 0 ]]; then
  run_auto_leg
  run_wayland_leg
fi

echo "linux-x11-vm smoke: ok (evidence in $evidence_dir/)"
