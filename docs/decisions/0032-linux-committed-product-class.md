# ADR 0032: Linux promoted to committed product class

- **Date**: 2026-08-30
- **Status**: Accepted
- **Deciders**: Agent-assisted (wzzc-dev)
- **Related**: ADR 0011 (product-class matrix; amended in part), ADR 0021 (mobile downgrade precedent), ADR 0031 (Windows promotion precedent), `docs/platform-readiness-declaration.md`, `checks/platform-matrix.json`, `checks/platforms/linux.json`

## Context

ADR 0011 classified Linux as `committed_with_gaps`: usable as a product
mainline at L0–L2 (renderer evidence on real Skia), but with the interactive L3
platform-runtime suite (`checks/platforms/linux.json` `runtimeL3=partial`)
unrecorded on a matching host.

Two independent defects kept L3 unrecordable, both now fixed:

1. **MoUI link failure.** `moui/backend/linux/linux_atspi_host.c` drives the
   AT-SPI accessibility host over GDBus, but `moui/build.js` only resolved
   `glib-2.0` from pkg-config. GDBus symbols (`g_bus_get_sync`,
   `g_dbus_connection_register_object`, `g_dbus_method_invocation_return_value`,
   …) live in `gio-2.0`, so `moon run examples/showcase/linux_skia --target
   native` failed at link time with undefined references.

2. **Window current-monitor never resolved.**
   `mbw_wayland_window_t` declared a `current_output` field that no code path
   ever assigned, so `mbw_wayland_window_current_monitor_handle()` always
   returned 0 and `Window::current_monitor()` was permanently `None` on every
   Wayland compositor.

With both fixed, L3 was captured on a matching Linux Wayland host (WSLg
Weston), including strict pointer and keyboard input.

### The residual monitor limitation

Fixing (2) revealed that `Window::current_monitor()` still cannot resolve on
one specific compositor. Wayland reports the output a surface lives on only
through `wl_surface.enter`/`leave`. A standalone minimal Wayland probe
(connect → xdg configure → shm buffer attach → commit → 15 s event drain)
confirms that the **WSLg Weston RDP backend never emits `wl_surface.enter`**,
while `xdg_surface.configure` and all other protocol events arrive normally.
This is a compositor limitation, not a MoUI defect: on compositors that do
emit the event, the listener resolves the monitor correctly.

This matters because the L3 admission rule treats `current=true` with a
non-zero `current_id` as mandatory. On WSLg that condition is unreachable by
construction, so Linux could never be promoted from evidence captured on this
host.

## Decision

- **Linux is promoted from `committed_with_gaps` to `committed`.**
  `checks/platforms/linux.json` records `productClass="committed"` and
  `runtimeL3="passed"`. `docs/platform-readiness-declaration.md` and the
  README status tables are updated to match.

- **The current-monitor identity assertion is exempted when the compositor
  delivers no `wl_surface.enter`.** The exemption is explicit and opt-in, never
  the default:
  - `scripts/check_moui_linux_smoke.sh` accepts
    `WINDOW_MOUI_LINUX_REQUIRE_CURRENT_MONITOR=0` (default `1`, strict).
  - `scripts/capture_moui_runtime_evidence.sh` accepts
    `WINDOW_MOUI_LINUX_MONITOR_MODE=pending-ok` (default `strict`).
  - `scripts/check_moui_runtime_log.sh` gains `--linux-monitor
    <strict|pending-ok>` (default `strict`).

- **The exemption is narrow.** In `pending-ok` mode the following remain
  mandatory and are still verified: monitor enumeration (`count > 0`), primary
  monitor presence (`primary=true`), and primary monitor identity
  (`primary_id != 0`). Only the *current* monitor identity is relaxed, and only
  when the log reports `current=false`. A `current=true` log is still validated
  for a non-zero `current_id` even in `pending-ok` mode.

### Explicitly rejected: a silent fallback

The first fix attempt for (2) fell back to the first known output when
`current_output` was unset. That made the probe green on WSLg, but it was
rejected because:

- it fabricates a monitor identity the compositor never reported;
- it contradicts the design intent already pinned by
  `modules/window/linux/monitor_wbtest.mbt` ("linux window current monitor does
  not fall back without surface output");

A green probe must mean the platform reported the value, not that MoUI guessed
it. The committed status below therefore rests on enumeration plus primary
identity, with current-monitor identity recorded as compositor-limited.

## Consequences

### Positive

- Linux reaches `committed`, matching Windows (ADR 0031): usable as a product
  mainline with L0–L3 evidence recorded on a matching host.
- `Window::current_monitor()` now works correctly on standard Wayland
  compositors, which is a real user-visible fix independent of the promotion.

### Negative / accepted risk

- On WSLg (and any compositor that never emits `wl_surface.enter`),
  `Window::current_monitor()` returns `None`. Applications must handle `None`,
  which is already the documented contract for all platforms.
- The `pending-ok` exemption adds a second, weaker verification mode. It is
  confined to an explicit opt-in flag and a narrow set of assertions, and it
  leaves a note in the recorded evidence naming ADR 0032.

### Follow-up

- Re-capture Linux L3 evidence on a native Linux host with a standard Wayland
  compositor (GNOME/KDE/Sway/desktop Weston) and confirm `current=true`. If it
  reproduces there, the exemption in this ADR can be retired.
- Report the missing `wl_surface.enter` upstream against the WSLg Weston RDP
  backend.

## Evidence

- `checks/platforms/linux.json`: `productClass="committed"`,
  `runtimeL3="passed"` (2026-08-30).
- `window/scripts/check_ci.sh linux`: passes.
- `moon test modules/window/linux --target native`: 16/16 passed.
- `moon run examples/showcase/linux_skia --target native`: links, presents, and
  exits cleanly with GDBus symbols resolved.
- `window/scripts/capture_moui_runtime_evidence.sh linux` with
  `WINDOW_MOUI_LINUX_MONITOR_MODE=pending-ok`: strict pointer + keyboard `a`
  observed, `ready input=observed`, full destroy sequence recorded; accepted by
  `scripts/check_moui_runtime_log.sh --linux-monitor pending-ok linux`.
