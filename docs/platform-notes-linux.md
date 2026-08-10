# Linux Platform Notes

`backend/linux` is a minimal native Wayland host core. It uses the
`wzzc-dev/window@0.5.4-0.1.5` Linux package for Wayland event-loop and window handles,
normalizes window/input events through the shared `Event` contract, and runs
the Showcase entrypoints through the same renderer/runtime boundary as macOS
and Windows. Application entrypoints supply ordered
`RendererProvider` values for concrete rendering.
`backend/linux` exposes the window package's `Window::present_rgba_pixels`
presenter, raw-byte image I/O, and opaque native surface/display handles; Skia and
WGPU construction stays in `moui_skia_renderer` and `moui_wgpu_renderer`.

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
paths continue through `Event::DragDrop` before reaching `View::on_file_drop`.
Text-input focus state and IME requests are synchronized through the shared
`TextInputSession` path used by other native hosts. That session now records
`TextInputImeRequestDiagnostics` for each enabled/update request, including
grapheme-normalized cursor/anchor character positions, UTF-8 offsets for
surrounding text, the logical candidate-anchor caret rectangle, and whether
surrounding-text payloads fit the window package's IME contract.

## Runtime Requirements

Linux runtime requirements are intentionally native:

- On a Debian-family host, `scripts/set_linux_deps.sh` installs the package
  sets below in one step. The default set covers the Wayland window core,
  GLib/zlib link libraries, Weston for headless compositor checks, zenity,
  and the Skia renderer stack. `--minimal` restricts the install to the core
  Wayland build/runtime set, `--with-webview` adds WebKitGTK development
  packages for native WebView support, and `--print-packages` shows the exact
  apt list for the selected set before installing:
  ```sh
  sh scripts/set_linux_deps.sh                 # full default set (Skia included)
  sh scripts/set_linux_deps.sh --minimal       # core Wayland build/runtime only
  sh scripts/set_linux_deps.sh --with-webview  # + WebKitGTK native WebView
  sh scripts/set_linux_deps.sh --check         # verify the installed set
  ```
  The individual requirements below describe what each package set provides
  and how the MoUI prebuilds consume them.

- A Wayland compositor. For repeatable headless checks, run Weston with the
  headless backend and point `WAYLAND_DISPLAY` at its socket.
- A usable Vulkan stack only when running WGPU diagnostics. Headless software
  validation can use Mesa llvmpipe through `vulkan-swrast`/Lavapipe when
  hardware Vulkan is not available.
- Wayland development headers and generated xdg-shell protocol sources for the
  `wzzc-dev/window@0.5.4-0.1.5` native stub.
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
  `moui_skia_renderer/build.js` injects them through prebuild `link_configs` for
  `backend/linux`, `moui_skia_renderer`, and `moui_wgpu_renderer/fontconfig`. Linux example entrypoints
  should not repeat `-lz` or fontconfig stacks; they only need an empty
  `cc-link-flags` override so Moon disables `tcc -run` when required.
- glib-2.0 development headers and runtime library. `backend/linux`
  drives `@services.TimerSource` subscriptions through the GLib main
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

## Linux RISC-V64 Cross-build

MoUI's first Linux RISC-V64 path is an experimental architecture variant of
the canonical `linux/skia` route. It targets `riscv64-linux-gnu` (glibc/LP64D)
and deliberately selects Skia Raster with static linking. Vulkan, WGPU,
WebView, and matching-device Wayland runtime claims are outside this first
slice.

The fixture is locked to Ubuntu Base 24.04.4 RISC-V64 and Zig 0.16.0 in
`checks/toolchains/linux-riscv64.json`. On a Linux host with
`qemu-user-static`, prepare the sysroot and run the L0-L2 helper:

```sh
bash scripts/prepare-linux-riscv64-sysroot.sh \
  --output .cache/moui/riscv64/sysroot/ubuntu-24.04.4-riscv64
bash scripts/linux-riscv64-cross-build.sh \
  --sysroot .cache/moui/riscv64/sysroot/ubuntu-24.04.4-riscv64 \
  --run-qemu
```

The helper sets `MOON_CC`/`MOON_AR` to Zig wrappers, redirects `pkg-config` to
the target sysroot, builds `examples/showcase/linux_skia` and the offscreen
Skia renderer/text smokes in Moon Release mode, then verifies ELF64, the RISC-V
machine, the LP64D glibc interpreter, static Skia, and the absence of a Vulkan
dependency. The evidence directory includes the complete target package list,
the sysroot file-checksum manifest, ELF reports, executable checksums, and smoke
logs. `--run-qemu` chroots into the target rootfs for dynamic libraries,
fontconfig, and fonts, and executes only renderer-owned offscreen smokes; it
does not prove a Wayland compositor, input, IME, clipboard, or desktop service.

The helper self-test requires no downloaded sysroot and pins the explicit
failure diagnostics for the wrong architecture/ABI, missing target `.pc`
files, and accidental Vulkan enablement:

```sh
bash scripts/test-linux-riscv64-cross-build.sh
```

The architecture evidence contract lives in
`checks/architecture-evidence/linux-skia-riscv64.json`. Keep its `ready=false`
and `runtimeL3.status=pending` until a real RISC-V64 Wayland device produces
matching-host evidence. A device run uses the existing Linux Showcase command
and remains a separate L3 promotion step. Copy the cross-built Showcase ELF to
the matching RISC-V64 Wayland device, then collect first-frame, input, IME,
clipboard, and service logs with:

```sh
MOUI_SKIA_RENDERER=skia-raster ./linux_skia.exe
```

## Running

Useful focused commands on a configured Linux host:

```sh
moon test moui/backend/linux --target native
moon build examples/showcase/linux_skia --target native
moon run examples/showcase/linux_skia --target native
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

The WGPU diagnostic factory composes the Linux `moui_wgpu_renderer/fontconfig`
provider with the shared Moon Cosmic fallback.
The fontconfig provider includes real fontconfig family resolution, FreeType
rasterization (loaded via dlopen), HarfBuzz shaping, embedded-font registration,
and a narrow color-emoji path; MoonBit tests verify protocol versioning and
native payload parsing on all platforms, while the full shaping/measurement/raster
path runs on Linux with the required C libraries. Choose the engine through
`@wgpu_renderer.native(text_engine=...)`; the canonical `linux_wgpu` route uses
the fontconfig provider with Moon Cosmic as its internal fallback.

## Skia Renderer

Select the native mainline Skia renderer by importing
`wzzc-dev/moui_skia_renderer`, adding
`@render_skia.from_env(platform=@render_skia.NativeGpuPlatform::Linux)` to the
app builder, and capturing `LinuxHostAppOptions` in `@linux.entry`. The
provider binds a `RendererSession` backed by `@render_skia.SkiaRasterRenderer`
and presents the CPU pixel
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
through `Event::WebView`, and drains `HostWebViewCommandQueue` commands
after frame rendering. macOS, Windows, and Linux native bridges enforce the
shared `WebViewNavigationPolicy` before committing a navigation; blocked URLs
produce a `NavigationFailed` event. Matching-host smoke is still required before
promoting Linux WebView runtime observation beyond package-level compile coverage.
The Linux host loop drains `RendererEvent` image requests, keeps only
cancellable byte-I/O tasks, and returns token-matched completions to the
selected session. Linux reads local files into `HostImageSource` bytes; the
selected renderer owns decode, resource caches, and completion diagnostics.
Applied completions request redraw for the matching Wayland window, while stale
or disposed tokens are ignored. Package tests cover the host route from a
loading first-frame request through completion, repaint request, and second
presented frame. The required
async second-frame runtime artifact remains matching-host pending until a
Wayland run records it from a Skia composition root. Package tests do not prove
a real Wayland compositor presented Showcase frames;
those claims still require matching-host runtime runs and smoke logs
manifest entries.

## Runtime Evidence

For Linux Skia runtime evidence, record these as separate ignored
`artifacts/` logs on the matching Wayland host:

```sh
MOUI_FIRST_FRAME_EXIT=1 \\
  moon run examples/showcase/linux_skia --target native
scripts/run-window-package-smoke.sh linux --run
```

The Showcase log must include
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
Record dependency-level facts from the `wzzc-dev/window@0.5.4-0.1.5`
package smoke artifacts; keep the MoUI Showcase
`linux_skia` run as the mainline application observation. Keep `linux_wgpu` as
a WGPU diagnostic observation when a Vulkan/WGPU stack is configured.

Linux WebView runtime evidence belongs to a matching-host tester/backend probe.
Package tests cover pure event/command mapping and fallback capability paths,
but cannot prove that a real WebKitGTK view was presented.

`examples/showcase/linux_skia` selects the canonical Linux Skia provider route.
Configure real Skia link flags before relying on native Skia-rendered pixels.
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
