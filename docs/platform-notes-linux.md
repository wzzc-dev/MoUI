# Linux Platform Notes

`backend/linux` is a minimal native Wayland host core. It uses the
`wzzc-dev/window@0.5.1-0.1.7-2` Linux package for Wayland event-loop and window handles,
normalizes window/input events through the shared `HostEvent` contract, and runs
the Showcase entrypoints through the same renderer/runtime boundary as macOS
and Windows. Concrete rendering is injected through `LinuxRendererProvider`;
`backend/linux/skia` is the native mainline and reuses the window package's
`Window::present_rgba_pixels` presenter, while `backend/linux/wgpu` creates
native WGPU surfaces from `wl_display` and `wl_surface` for diagnostics.

The Wayland window path requests server-side decorations when the compositor
exposes `xdg-decoration`. If the compositor falls back to client-side
decorations, `backend/linux` reserves a small titlebar band above the MoUI
content, draws the window title and basic controls into the renderer command
stream, and translates input coordinates so application views still receive a
content-origin coordinate space.
The same adapter consumes the window package's Wayland key/modifier mapping and
current pointer coordinates: Linux backend tests cover modifier propagation into
shared keyboard events and button events using the position carried by the
window event rather than stale pointer state. The fork also exposes Wayland
data-device clipboard selection and file drag/drop events to MoUI; drag/drop
paths continue through `HostEvent::DragDrop` before reaching `View::on_file_drop`.
Text-input focus state and IME requests are synchronized through the shared
`TextInputSession` path used by other native hosts. That session now records
`TextInputImeRequestDiagnostics` for each enabled/update request, including
grapheme-normalized cursor/anchor character positions, UTF-8 offsets for
surrounding text, the logical candidate-anchor caret rectangle, and whether
surrounding-text payloads fit the window package's IME contract.

## Runtime Requirements

Linux runtime requirements are intentionally native:

- A Wayland compositor. For repeatable headless checks, run Weston with the
  headless backend and point `WAYLAND_DISPLAY` at its socket.
- A usable Vulkan stack only when running WGPU diagnostics. Headless software
  validation can use Mesa llvmpipe through `vulkan-swrast`/Lavapipe when
  hardware Vulkan is not available.
- Wayland development headers and generated xdg-shell protocol sources for the
  `wzzc-dev/window@0.5.1-0.1.7-2` native stub.
- `wl_data_device_manager` from the compositor for native clipboard selection
  and file drag/drop runtime behavior.
- XDG desktop integration for Linux services: OpenURI goes through
  xdg-desktop-portal when available and falls back to the desktop opener;
  file-dialog selections use xdg-desktop-portal with `zenity` as the fallback
  dialog provider. Install `zenity` if portal is not available:
  ```sh
  sudo apt-get install zenity
  ```
  When neither portal nor zenity is available, file and folder selection
  silently returns cancelled, and the app prints a diagnostic message to stdout.
- zlib / pthread / fontconfig system libraries for the final native link.
  `moui/build.js` injects them through prebuild `link_configs` for
  `backend/linux`, `backend/linux/skia`, `backend/linux/sun`,
  `backend/linux/wgpu`, and `render/wgpu/fontconfig`. Linux example entrypoints
  should not repeat `-lz` or fontconfig stacks; they only need an empty
  `cc-link-flags` override so Moon disables `tcc -run` when required.
- glib-2.0 development headers and runtime library. `backend/linux`
  unconditionally drives `HostTimerSource` subscriptions through the GLib main
  loop (`g_timeout_add` / `g_source_remove`), so the `moui` prebuild resolves
  `glib-2.0` through `pkg-config` and feeds the resulting `-I` include flags
  into `stub-cc-flags` and merges the libs into the `backend/linux`
  `link_configs` entry. On hosts where `pkg-config` cannot find `glib-2.0`,
  both resolve to empty (the C stub body is guarded by `#ifdef __linux__` and
  only matters on Linux). Distro-specific setups can override the resolved
  flags with `MOUI_LINUX_GLIB_STUB_CC_FLAGS` and
  `MOUI_LINUX_GLIB_CC_LINK_FLAGS`.
- WebKitGTK development packages (`libwebkit2gtk-4.1-dev` or `4.0`) for native
  WebView support. The `moui_webview` prebuild auto-detects
  `gtk+-3.0` with `webkit2gtk-4.1` or `webkit2gtk-4.0` through `pkg-config`;
  if found, it enables the native bridge. Fallback builds do not link WebKitGTK
  and report WebView unavailable. Distro-specific setups can override the
  detection with `MOUI_LINUX_WEBKITGTK_STUB_CC_FLAGS` and
  `MOUI_LINUX_WEBKITGTK_CC_LINK_FLAGS`.

## Running

Useful focused commands on a configured Linux host:

```sh
moon test moui/backend/linux --target native
moon build examples/showcase/linux_skia --target native
moon build examples/markdown_editor/linux_skia --target native
moon run examples/showcase/linux_skia --target native
moon run examples/markdown_editor/linux_skia --target native
```

The ordinary Linux Skia entrypoints are interactive app entrypoints. Keep
matching-host first-frame smoke in tester/backend smoke runners and store those
logs under ignored `artifacts/` paths when they are needed for release notes.

When validating from a Linux VM mounted over the same checkout as a macOS or
Windows host, keep native build output isolated. Either run `moon clean` before
switching hosts or copy the checkout to a Linux-local temporary directory
without `_build`; the native archive and MoonDB files are host-specific and can
be corrupted by cross-host reuse.

## WGPU Diagnostics

The WGPU diagnostic text path in `backend/linux/wgpu` composes the Linux
`render/wgpu/fontconfig` provider with the shared Moon Cosmic fallback.
The fontconfig provider includes real fontconfig family resolution, FreeType
rasterization (loaded via dlopen), HarfBuzz shaping, embedded-font registration,
and a narrow color-emoji path; MoonBit tests verify protocol versioning and
native payload parsing on all platforms, while the full shaping/measurement/raster
path runs on Linux with the required C libraries. Choose `MoonCosmic` with
`LinuxWgpuAppOptions::new(text_engine=...)`;
`examples/showcase/linux_wgpu_cosmic` selects the Moon Cosmic provider explicitly for
comparison.

## Skia Provider

Select the native mainline Skia provider by importing
`wzzc-dev/moui/backend/linux/skia` and using `LinuxSkiaAppOptions`. The
provider creates `render/skia.SkiaRasterRenderer` and presents the CPU pixel
frame through a narrow API exposed by
`wzzc-dev/window/linux`. That window package owns the Wayland objects and
provides `Window::present_rgba_pixels`, implemented with reusable `wl_shm`
buffers, buffer-release tracking, `wl_surface_attach`, damage, commit, and
display flush. Keeping the `wl_shm` presenter in the window backend avoids
duplicating Wayland registry and buffer ownership in MoUI.
Linux native WebView support is auto-detected via `pkg-config`. When
WebKitGTK development packages are installed, the host syncs placements from
`DrawFrame.platform_views` using the Wayland surface handle, offsets placement
below client decorations when needed, pumps the GTK main context from the Linux
event-loop wait path, forwards navigation/title/history/JavaScript events
through `HostEvent::WebView`, and drains `HostWebViewCommandQueue` commands
after frame rendering. macOS, Windows, and Linux native bridges enforce the
shared `WebViewNavigationPolicy` before committing a navigation; blocked URLs
produce a `NavigationFailed` event. Matching-host smoke is still required before
promoting Linux WebView runtime observation beyond package-level compile coverage.
`linux_skia_provider_preflight_summary()` exposes package-level preflight
observation for the selected font resolution, renderer availability,
`moui_skia/native` availability, the `wl_shm` presenter path, inherited Wayland
host service/input/window readiness, explicit Linux clipboard/file-dialog/text-file/open
URL/menu/system-theme readiness, native menu readiness, async-service gap,
text-input/IME/drag-drop readiness, native context-menu readiness and native
accessibility readiness, host-modal
file-dialog readiness, `HostWindowRenderer` bridge
forwarding for Skia text-system, image-resource, present-count, and disposal
diagnostics, and the matching-host runtime boundary, including whether the first-frame smoke
option is enabled. The Linux host loop records the renderer image-resource
revision after each present, routes later observed revision changes through the
matching Wayland window's `request_redraw`, exposes tracked-window revision
snapshots for diagnostics, calls the optional provider-owned
`HostAsyncImageLoader` after the presented revision is baselined, and removes
tracked image revisions plus in-flight image loads when a host window is
disposed. The Linux Skia provider package now covers the host route from a
loading first-frame image record through deferred `skia_image_load_completion`,
repaint request, and second presented-frame status recording. The required
async second-frame runtime artifact remains matching-host pending until a
Wayland run records it from the Skia entrypoints or provider smoke. The summary
is useful for provider/package
audits, but it does not prove a real Wayland compositor presented Showcase or
Markdown Editor frames;
those claims still require matching-host runtime runs and smoke logs
manifest entries.

## Runtime Evidence

For Linux Skia runtime evidence, record these as separate ignored
`artifacts/` logs on the matching Wayland host:

```sh
MOUI_LINUX_SKIA_EXIT_AFTER_FIRST_PRESENT=1 \\
  moon run examples/showcase/linux_skia --target native
MOUI_MARKDOWN_EDITOR_LINUX_SKIA_EXIT_AFTER_FIRST_PRESENT=1 \\
  moon run examples/markdown_editor/linux_skia --target native
scripts/run-window-package-smoke.sh linux --run
```

The Showcase and Markdown Editor logs must include
`Linux renderer presented first frame; exiting by request; title=...` from the
host loop before they can be cited as app-level runtime evidence. The window
package smoke remains dependency-level evidence for Wayland handles,
`present_rgba_pixels`, resize/redraw, IME request state, and clean shutdown.

The window package carries a consumer-style Linux smoke for this dependency
surface. On a matching Wayland host, run
`scripts/run-window-package-smoke.sh linux --run` to exercise
surface creation, public Wayland handles, `Window::present_rgba_pixels`, resize,
redraw, IME request state, and clean shutdown. Add `--require-input` or
`WINDOW_MOUI_LINUX_REQUIRE_INPUT=1` only when representative pointer/keyboard
input is observed. Linux clipboard selection, file dialogs, text-file reads and
writes, desktop URL opening, IME composition/cursor geometry, and file
drag/drop are implemented host-service/input paths, but they remain
matching-host runtime evidence boundaries: cite only logs that exercised the
actual desktop/compositor service, not the package preflight summary alone.
Record dependency-level facts from the `wzzc-dev/window@0.5.1-0.1.7-2`
package smoke artifacts; keep the MoUI Showcase
`linux_skia` and Markdown Editor `linux_skia` runs as separate mainline
application-level observation. Keep `linux_wgpu` and `linux_wgpu_cosmic` as WGPU diagnostic
observation when a Vulkan/WGPU stack is configured.

For Linux WebView runtime evidence on a configured host with WebKitGTK
installed, build or run the demo and cite the smoke log separately from Skia
first-frame evidence:

```sh
moon check examples/webview_demo/linux_skia --target native
moon run examples/webview_demo/linux_skia --target native
```

That smoke should exercise placement, controlled navigation policy failures,
title/history notifications, JavaScript result callbacks, and command queue
draining. Package tests cover the pure event/command mapping and fallback
capability path, but they do not prove a real WebKitGTK view presented.

`examples/showcase/linux_skia` and `examples/markdown_editor/linux_skia` select
this provider for the mainline Showcase and editing workflow. Configure real
Skia link flags before relying on native Skia-rendered pixels.
The default JetBrains Linux provider links fontconfig, FreeType, and HarfBuzz;
with those libraries available, `moui_skia` builds a system `FontMgr` through
fontconfig and falls back to common font directories such as `/usr/share/fonts`
when fontconfig reports no families. Missing CJK or emoji glyph coverage still
depends on installed system fonts, and full mixed-script fallback runs remain a
text-system follow-up rather than a Linux backend responsibility.

Linux native context menus use the shared `HostServiceBridge::ShowMenu`
contract. The backend encodes enabled command rows for a desktop menu picker,
dispatches the selected `ActionCommand` through `HostRuntimeDriver`, and reports
an unavailable response when the configured desktop menu tool is absent.

Linux AT-SPI accessibility binding stays behind `backend/linux`: it publishes
AccessKit-shaped snapshots from the shared semantics tree, dispatches action
callbacks through the shared semantics action bridge, and reports cleanup
diagnostics when disposed. Matching-host assistive-technology smoke is still
runtime evidence, not package-level proof.

### Remaining Gaps

Remaining Linux gaps stay visible in `backend/linux.readiness()`:

- Linux clipboard, file-dialog, text-file, open URL, text-input/IME request, and
  file drag/drop host surfaces are implemented, but passed platform status still
  requires matching-host Wayland/desktop-service observation rather than package
  preflight alone.

#### WSL2 Verification Progress (2026-07-11)

On 2026-07-11, an end-to-end runtime evidence capture was completed on WSL2 + WSLg (Debian 13 on Windows):

```sh
bash window/scripts/capture_moui_runtime_evidence.sh linux \
  --log artifacts/platform-evidence/linux/moui-linux-runtime.log
```

**Passed:**
- ✅ Wayland surface/handles/present/cursor/resize/redraw — all working correctly
- ✅ **IME probe: all 8 fields passed** (`enabled`, `hint`, `surrounding`, `cursor`, `updated`, `updated_hint`, `updated_cursor`, `disabled` all `true`)
- ✅ Clipboard data device: `clipboard=true clipboard_roundtrip=true drag_drop=true`
- ✅ `check_ci.sh` CI check passed

**Still requires a real Wayland desktop:**
- ❌ Interactive pointer/keyboard input (cannot be sent automatically in WSL2)
- ❌ Complete destroy sequence (requires focused window interaction)

The IME protocol functionality has been verified via WSL2. Full L3 runtime
pass requires running `WINDOW_MOUI_LINUX_REQUIRE_INPUT=1` mode on a real Wayland
desktop (Ubuntu 24.04+) with actual keyboard presses and mouse clicks.
