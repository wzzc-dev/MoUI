# Plan: Linux X11 windowing backend

- **Status**: active
- **Goal**: Add an X11 (Xlib) backend to `wzzc-dev/window`'s Linux package with
  runtime selection next to the existing Wayland backend, wire it through
  `moui/backend/linux`, and validate on a local UTM arm64 Ubuntu VM.
- **Supersedes**: the "X11 后端（除非后续 RFC）" non-goal line in
  `docs/plans/active/window-cross-platform-parity.md` (owner-approved 2026-09-15).
- **Non-goals**: X11 GPU route (Vulkan/GLX surface in `moui_skia_renderer`),
  XIM/ibus IME parity, multi-monitor parity polish, XWayland-specific bugs, and
  any change to the Wayland backend's behavior.

## Motivation

The Linux route is Wayland-only (`window/modules/window/linux`, xdg-shell +
wl_shm). Many environments still surface only X11 (Xvfb CI, remote X, legacy
desktops). The user provides a UTM arm64 Ubuntu VM as the validation target.

## Architecture

- New `window/modules/window/linux/native_x11.c`: Xlib connection, event loop
  (`poll` on `ConnectionNumber` + wake pipe, mirroring the Wayland wake fd),
  window creation (32-bit ARGB visual + colormap), MIT-SHM present with
  XPutImage fallback (RGBA→BGRA), pointer/keyboard/close/resize events, WM
  protocols (`WM_DELETE_WINDOW`), Xft.dpi scale, XRandR primary monitor.
- C-level dispatch: context/window structs carry a backend tag as the first
  field; new `mbw_native_*` wrappers route to `mbw_wayland_*` or `mbw_x11_*`.
  Backend selection probes `MOUI_LINUX_WINDOWING` (`auto|x11|wayland`), then
  `WAYLAND_DISPLAY`/`DISPLAY` (auto order matches winit: Wayland first).
- MoonBit layer keeps one public API; `EventLoop`/`Window` gain a
  `windowing_backend()` accessor returning `X11 | Wayland`; Wayland-only
  extensions (`wl_surface` etc.) raise `NotSupported` on X11;
  `raw_display_handle`/`raw_window_handle` return the existing
  `@windowing` Xlib variants.
- `moui/backend/linux`: surface binding branches on the backend (X11 →
  Xlib `Display*`/`Window` handles into `@render.NativeSurface`); client
  decorations and decoration event offsetting are skipped for X11 (WM
  decorations).
- Renderer: CPU raster only in this slice (same as the Wayland mainline path
  via `present_rgba_pixels`).

## VM validation loop (UTM arm64 Ubuntu)

- VM: UTM/QEMU aarch64 "Linux" VM on 192.168.64.5 (vmnet-shared), 9p share
  `mount_tag=share` → host `/Users/zc/ubuntu-share`.
- Access: bootstrap SSH (enable `openssh-server` in the VM; one-time manual or
  QEMU guest-agent assisted) — pending user-side setup.
- Build: `zig cc -target aarch64-linux-gnu` + Ubuntu arm64 sysroot with X11 dev
  packages (mirror `scripts/linux-riscv64-cross-build.sh`; Skia has arm64
  prebuilt release assets in `skia-provider-lock.json`).
- First smoke: `examples/showcase/linux_sun` (pure-MoonBit sun renderer, no
  Skia) under Xvfb / desktop Xorg; screenshot evidence; then the Skia showcase.

## Acceptance

- [ ] `moon test moui/backend/linux --target native` and window-module tests
      stay green (mooncakes mode restored before commit).
- [ ] Cross-built aarch64 binary lists the X11 backend and runs
      `linux_sun` showcase with `MOUI_LINUX_WINDOWING=x11` against Xvfb in the
      VM: window mapped, first frame presented, pointer/keyboard events
      delivered, clean exit via WM_DELETE_WINDOW.
- [ ] Same binary with `MOUI_LINUX_WINDOWING=wayland` still passes the
      Wayland smoke (no regression).
- [ ] `auto` selection picks Wayland on the Wayland session and X11 when only
      `DISPLAY` is set.
- [ ] Docs updated: `docs/platform-notes-linux.md`, window module README
      (X11 no longer "intentionally unsupported"), `window/docs/platform-gaps.md`
      Linux column gains X11 entries or a documented split.

## Decision log

| Date | Decision |
|------|----------|
| 2026-09-15 | Xlib (not XCB) for the first slice; C-level tag dispatch; runtime selection via env probe; CPU raster only. |
| 2026-09-15 | Validation host is the user's UTM arm64 Ubuntu VM; cross-build from macOS with zig cc + arm64 sysroot. |

## Progress

| Date | Note |
|------|------|
| 2026-09-15 | Plan drafted after architecture survey (Wayland-only linux package; neutral `moui/backend/linux`; `@windowing` already has Xlib/Xcb handle variants). |
| 2026-09-15 | Slice 1 implemented and locally gated: `native_x11.c` (Xlib backend: event loop, window, MIT-SHM/XPutImage present, EWMH/motif state, XRandR monitors, CLIPBOARD selection), `native_backend.c` tag dispatch with `MOUI_LINUX_WINDOWING` probe, `WindowingBackend` API, `moui/backend/linux` X11 binding (GPU rejected → CPU raster), X11 link flags via prebuild `build.js`, `set_linux_deps.sh` X11/Xvfb packages, `scripts/linux-x11-vm-smoke.sh`. Gates: `moui/backend/linux` 25/25 (debug+release), `window/linux` 16/16, `moui_linux_smoke` example compiles, aarch64-linux zig compile + full C-layer link check against real libX11/libXext/libXrandr passes, static validators (maintenance-baseline, api-surface, release-closures, guidance, renderer-capability, doc-references) pass. |
| 2026-09-15 | UTM VM validation green. `scripts/linux-x11-vm-smoke.sh` (window-module standalone layout, native aarch64 Ubuntu 26.04 build) passes all three legs — X11 forced, `auto` selection (DISPLAY-only → x11), and the Wayland regression leg (headless Weston) — with the full `ready → destroy requested → destroyed → finished` sentinel chain; evidence in `artifacts/linux-x11-vm/`. Resize race found and fixed: Xvfb coalesces a map+resize issued without an intervening round trip and never delivers ConfigureNotify, so `request_surface_size` now round-trips with `XSync` (8/8 stable). The smoke example's handle check is backend-aware (X11: Xlib display + Window XID, empty xdg slots). Clipboard roundtrip works on X11; pointer/keyboard stay `pending` on headless Xvfb (no operator input), matching the CI `pending-ok` contract. |
| 2026-09-15 | End-to-end showcase validated on the same VM: `examples/showcase/linux_sun` (full MoUI stack, native aarch64 release build) with `MOUI_LINUX_WINDOWING=x11` + `MOUI_LINUX_SUN_EXIT_AFTER_FIRST_PRESENT=1` under Xvfb prints `Linux renderer presented first frame; exiting by request; title=MoUI Showcase` and exits 0; screenshot pixel stats (stddev 0.44, 158 colors) confirm rendered content (`artifacts/linux-x11-vm/showcase-x11.png`, `sun-x11.log`). The mainline `examples/showcase/linux_skia` (prebuilt static Skia, CPU raster) additionally passes on X11 with the same first-frame sentinel in raster and auto modes (`artifacts/linux-x11-vm/showcase-skia.png`, `skia-x11.log`). VM scratch notes: moon 20260904 on linux-aarch64 cannot solve `bobzhang/openseek@0.2.2` (unrelated registry-packaging issue), so the VM sandbox moon.work drops `examples/mo_workbench`/`examples/browser`; GitHub release downloads need a mirror (asset seeded into `.skia-cache`). |
| 2026-09-15 | Client-side resize + resize cursors on Wayland CSD (GNOME mutter offers no xdg-decoration): `native_wayland.c` binds `wp_cursor_shape_manager_v1`, sets standard resize cursors on a 6px edge zone via `wp_cursor_shape_device_v1.set_shape`, and starts interactive resize with `xdg_toplevel_resize` on edge press (skipped when maximized). Verified on the VM's live GNOME session with uinput-injected edge drag: 38 streamed configure events, width 400→474 (`artifacts/linux-x11-vm/wayland-resize-test.log`), plus `WAYLAND_DEBUG=1` protocol capture showing bind → get_pointer → set_shape(default/n_resize/nw_resize) transitions; all three smoke legs re-pass. Scroll-direction report investigated end-to-end and closed as environment: every layer verified sign-consistent (X11 producer via xdotool injection, Wayland producer via mutter source + uinput on the live session, web test convention, MoUI consumer tests); the inversion comes from the macOS SPICE host translating trackpad gestures into wheel buttons while the guest mouse `natural-scroll` was off — resolved by `gsettings set org.gnome.desktop.peripherals.mouse natural-scroll true` on the guest (aligns the guest with the macOS host feel for all apps). |
| 2026-09-15 | UTM VM discovered at 192.168.64.5 (vmnet-shared, 9p share configured) but has no listening services; QEMU SPICE port-channel handshake implemented and reaches auth, ticket auth rejected by the UTM spice build (no guest logs available). VM smoke deferred until SSH is enabled in the guest. |
