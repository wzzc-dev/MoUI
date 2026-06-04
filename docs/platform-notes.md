# Platform Notes

## Local Window Dependency

MoUI expects the modified `wzzc-dev/window` checkout under `.local_repos/window`.
The README shows the setup commands. The local branch currently supplies target
support that the upstream package does not yet cover for MoUI.
The main checkout now includes `moui_skia`, which provides the editable Skia
binding used by the opt-in native Skia raster renderer.

## Shared Host Contract

Platform backends normalize window, input, surface, focus, text input, redraw,
and close events through `backend/host`. App code receives the same core event
model across Web, macOS, Windows, and the current Linux Wayland scaffold.
`HostWindowRegistry` also provides shared bookkeeping for window ids, primary
windows, focused windows, close requests, closed-window cleanup, and per-window
surface metrics so future multi-window platform hosts do not duplicate lifecycle
state machines. `HostWindowRequestQueue` is the matching platform-neutral
request channel for opening, focusing, closing, resizing, minimizing, showing,
and changing the primary window. `OpenWindow` requests include a scene id and
payload in addition to title, metrics, and primary-window intent, giving future
multi-window hosts a stable app-level key for selecting content/runtime when a
new platform window is created. `HostWindowSceneResolver` resolves those
requests into new `AppRuntime` instances or explicit scene rejections without
embedding platform policy in app code. `HostWindowRegistry::resolve_open_request`
then binds a resolved runtime to the registry record that owns the new window
id, and `HostWindowRuntimeSlot` wraps the record with its `HostRuntimeDriver`.
`HostWindowRuntimeSlots` stores those per-window drivers, supports lookup and
primary/focused slot selection, syncs updated lifecycle records from the
registry, provides shared insert/sync/request/lifecycle-event helpers for
active backends, and removes closed slots. `HostPlatformWindowMap` binds
platform `WindowId` values to `HostWindowId` values, giving multi-window
dispatch a shared routing primitive before backends attach multiple
renderer/window handle sets.
Active platform entrypoints accept a shared queue through their options-bearing
runner and drain focus, close, resize, minimize, show, and set-primary requests
at the platform edge. Each drained request records an ordered completion on the
same queue, so tests and higher-level host code can observe accepted operations
and explicit rejections. Active backends use the shared queue drain helper for
that drain-and-record loop so request completion tracking remains host-owned.
Once the platform reports a window as closed, queued commands for that window
are rejected rather than being replayed against stale runtime slots, and those
rejections are recorded as normal request completions.
Web creates the primary window through the same registry/slot path and supports
resolver-backed `OpenWindow` requests through `run_app_with_options` and
`WebAppOptions`. Native host cores create platform windows through the same
registry/slot path but do not choose concrete renderer families themselves.
Instead, public native entrypoints live in `backend/<platform>/wgpu` and
`backend/<platform>/skia`; those packages call
`backend/<platform>.run_app_with_renderer_provider` with a platform-local
`RendererProvider`. A resolved native window asks that provider for a
renderer-neutral `HostWindowRenderer`, then registers a `HostRuntimeDriver`,
platform binding, and platform slot, and routes redraw, events, context menus,
host service completions, IME sync, and disposal by `HostWindowId`. Without a
scene resolver, hosts reject `OpenWindow` with the shared unavailable-resolver
response.

Native renderer choice is package selection, not a field on host-core app
options. Use `backend/<platform>/wgpu` for native WGPU or
`backend/<platform>/skia` for native Skia raster. The Skia provider remains
explicit and preflights `moui_skia/native` availability before handing control
to the host app runner. Fallback builds therefore return with a clear diagnostic
instead of opening a platform window that later fails to attach a renderer.

Current-platform provider tests are included by
`sh scripts/dev-check.sh --platform-examples-test`. Run provider packages
directly only when you are already on the matching host and toolchain.

The boundary is:

```text
platform window event -> HostEvent -> AppRuntime -> DrawCommand -> renderer
```

Backends should keep platform details at the edge:

- Surface metrics carry logical size, physical size, and scale factor.
- Pointer coordinates are normalized before they reach `core`.
- File drag/drop events carry normalized logical positions and platform file
  paths before they reach `core` drop targets.
- Keyboard modifiers and IME events are converted into shared core input types.
- Redraw scheduling is owned by `HostRuntimeDriver`; hosts request redraws, but
do not mutate the element tree directly.
- Renderers consume `DrawCommand` values and remain separate from view
constructors and platform event conversion.
- Typed host services are routed through `HostServiceBridge`, with explicit
  capability flags for clipboard, menus, file dialogs, URL opening, and system
  theme. Unsupported services should return `Unavailable` responses instead of
  leaking platform checks into `core` or `views`.
- App-owned route history lives in `core` as `RouteHistoryState`, where it can
  model deep-link strings, back/forward cursors, and `RouterSnapshot`
  restoration without depending on a platform host. `backend/host` provides
  `HostRouteSource` for typed route/deep-link fanout through
  `Subscription::route_event`, but browser history updates, native URL bars, OS
  deep-link dispatch, and app history mutation are separate host/app
  integrations and are not implied by the current Skia native route evidence.
- `HostCapabilitySummary` is the app-facing diagnostics rollup over service,
  input, window, text-input, IME, drag/drop, async-service, and accessibility
  readiness. Web, macOS, Windows, and Linux expose package-local summary
  helpers, and Showcase displays the injected summary in its Runtime section.
  `HostCapabilitySummary::preflight_fields()` provides the renderer-neutral
  ready/gap field string used by native Skia provider preflight summaries, so
  provider packages can expose audit logs without duplicating host capability
  formatting or importing concrete renderer policy into host cores.
- Permission- or callback-driven host services can use `HostServiceAsyncQueue`
  and return `HostServiceResponse::Pending` instead of blocking the runtime.
  Hosts drain pending requests into in-flight platform work, complete them with
  the original request, and record completions. Runtime-owned responses such as
  clipboard paste are dispatched through `HostRuntimeDriver`; app-owned service
  workflows should declare `HostAppServices::completion_subscription` while the
  model stores a pending request id so pending completions re-enter the app's
  typed message loop. When that subscription is canceled, the queue removes the
  handler so a later platform response remains available through the completed
  response queue instead of dispatching into stale app state.
- Host service bridges can apply a reported light/dark system theme to a runtime
  `Environment`. Web, macOS, and Windows do this once at startup before the
  first layout/redraw pass. Runtime `ThemeChanged` window events are normalized
  to `HostEvent::ThemeChanged` and update the environment through
  `HostRuntimeDriver`.
- Web, macOS, and Windows route copy/cut/paste keyboard shortcuts through the
  active service bridge. When that bridge exposes clipboard support, focused
  text controls read or write the platform clipboard; app action commands still
  receive the intent when no text command handles it. Pending clipboard reads
  are treated as handled until the async completion arrives, so paste commands
  are not dispatched twice.
- Secondary mouse-button presses are treated as context-menu requests at the
  host edge. Web, macOS, and Windows skip normal pointer dispatch for those
  events so right-click does not activate regular controls; macOS and Windows
  then route the runtime action command menu through their native menu service.
  When a text input is focused, the host driver prepends MoUI's default text
  commands to that menu so native context menus can copy, cut, paste, undo,
  redo, and select text through the same clipboard and command path as keyboard
  shortcuts.

## Web Wasm-GC

The Web path is the canonical browser target: `wasm-gc + window/web + browser
WebGPU host imports`. It requires browser WebGPU. Startup fails clearly if
`navigator.gpu`, an adapter, or a device is unavailable. There is no JS-target
fallback branch. Browser Canvas measurement and WebGPU glyph drawing share the
same CSS `system-ui` font stack generated from `FontSpec`; app-registered embedded fonts
can be surfaced through browser font APIs, but remote font loading is not part
of the backend contract.
The active Web runtime service bridge opens external URLs through the browser
host import, which calls `window.open(..., "_blank", "noopener,noreferrer")`
and reports failure when the browser blocks the popup or the API is unavailable.
Web copy/cut shortcuts are forwarded from the hidden text input to the runtime
and write selected text through a browser host import using the user-gesture
`document.execCommand("copy")` path. Focused browser text input can still paste
through normal input events; app-level async clipboard reads use
`navigator.clipboard.readText()` and complete through `HostServiceAsyncQueue`
when browser permissions allow it.
The Web host now advertises IME readiness because the local `window/web` bridge
supports browser composition lifecycle events and accepts MoUI
`TextInputSession` IME requests for enabling input, cursor-area updates, and
surrounding-text updates. This is browser text-input evidence; it does not make
browser text shaping deterministic across browsers.
The active Web runtime now drains pending async service requests into browser
callbacks. Clipboard reads complete through exported wasm callback functions.
Open-file and directory dialogs use a hidden browser file input and return
browser-exposed file names or relative paths, which app-owned handlers can
receive through typed completion messages from
`HostAppServices::completion_subscription`. Save dialogs use the File System Access API
when `showSaveFilePicker` is available and otherwise complete as an unavailable
service. Canceled file pickers return an empty selection.
The browser host import reads `prefers-color-scheme` at startup and listens for
media-query changes through `window/web`; MoUI maps those events into runtime
environment color-scheme updates.
Browser file drag/drop events on the canvas are normalized through
`HostEvent::DragDrop` and dispatched to `View::on_file_drop` targets. The
Web platform receives browser-exposed file names or relative names rather than
native filesystem paths.
See [Text system](text-system.md) for the shared runtime and renderer text
contract.

The reusable browser runtime assets live under `backend/web/*.js`. Each
`examples/*/web_wasm/` package is only the app-specific Web entrypoint and
supplies the example-specific wasm URL. The canvas host reports logical event
coordinates after DPR mapping and avoids CSS transforms, borders, and padding so
resize and input coordinates stay stable. The browser runtime treats native
pointer events as authoritative when the browser supports `PointerEvent` and
does not synthesize MoUI pointer activation from compatibility mouse/click
fallbacks in that mode. Older environments without pointer-event support still
use mouse/click fallback with transaction de-duplication, including delayed
fallback events whose rounded coordinates drift slightly. This keeps a slow app
rebuild after a button release from replaying the same browser click as a
second MoUI pointer activation.

## macOS Native

The macOS host core uses `wzzc-dev/window/macos` for AppKit windows, lifecycle,
events, services, text-input session synchronization, renderer resize calls, and
redraw requests. It receives concrete rendering through
`MacosRendererProvider`; `backend/macos/wgpu` installs a `CAMetalLayer` on the
window `NSView` for native WGPU, while `backend/macos/skia` presents CPU pixel
frames through an `NSImageView`.
Window events pass through the shared `backend/host` conversion helpers, and the
native host never imports `render/wgpu`, `render/skia`, `wgpu_mbt`, or
`moui_skia`.
The macOS service bridge routes text clipboard requests through `NSPasteboard`,
opens URLs through `NSWorkspace`, presents open/save/directory dialogs through
`NSOpenPanel` and `NSSavePanel`, presents command menus at the current pointer
position through `NSMenu`, and reports the effective light/dark system
appearance through the shared `HostServiceBridge` contract.
The native app entrypoint applies that reported appearance to the runtime
environment before creating the host driver, so components see the system color
scheme on their initial build. AppKit theme-change events use the shared
`HostEvent::ThemeChanged` runtime path when emitted by the local window backend.
Right-click context-menu requests use the same `NSMenu` path and dispatch the
selected `ActionCommand` back through `HostRuntimeDriver`.
File drag/drop events emitted by the local `window/macos` backend are normalized
through `HostEvent::DragDrop` and dispatched to `View::on_file_drop`
targets.
Native WGPU text can use either the shared Moon Cosmic provider or a platform
provider. `backend/macos/wgpu` defaults to the CoreText/CoreGraphics provider
for runtime measurement and glyph rasterization, explicitly composed with the
Moon Cosmic provider as fallback; the Objective-C CoreText stub lives in
`render/wgpu/coretext`, while the selectable/composed Cosmic provider lives in
`render/wgpu/cosmic_text`. The CoreText provider consumes the shared native
`FontSpec` payload, attempts named families from the structured family stack,
maps generic CSS families such as `ui-monospace` and `serif` to suitable macOS
fonts, registers app-provided font bytes under their requested family alias when
CoreText accepts them, and falls back to the system font for unavailable names
before the renderer tries the composed Cosmic fallback.
Choose the text engine with
`@macos_wgpu.run_app_with_options(..., options=MacosWgpuAppOptions::new(text_engine=...))`.
The same options value can carry a `HostWindowSceneResolver` for
resolver-backed secondary windows and `exit_after_first_present` for first-frame
smoke tests. `core` still owns only the neutral `FontSpec`, `TextSystem`
contract, and deterministic fallback text system; it does not name concrete
macOS font files.
The `examples/showcase/macos_cosmic` entrypoint selects `MoonCosmic`
explicitly for comparison with the platform-default CoreText path.
`backend/macos` also exposes an async pump variant for native app entrypoints
that must run `moonbitlang/async` side work on the same thread as the AppKit
event pump. `backend/macos/skia.run_app_with_options_async_pump` keeps the
default blocking `run_app_with_options` behavior unchanged, but lets
`examples/mo_workbench/macos_skia` interleave the Skia window pump with its
owned Pi JSONL transport worker.

Select Skia by importing `wzzc-dev/moui/backend/macos/skia` and using
`MacosSkiaAppOptions`. The provider creates `render/skia.SkiaRasterRenderer`,
draws into a CPU raster surface in physical pixels, scales the canvas by the
host scale factor, reads premultiplied pixels back after each frame, and sends
them to a macOS presenter. The Objective-C presenter builds a `CGImage` from the
pixel bytes and installs it on a dedicated `NSImageView` attached to the content
view. macOS Skia options default to the same system `FontMgr` text path as the
Windows and Linux Skia providers; the first-frame smoke entrypoints explicitly
select `EmptyTypeface` only when their exit-after-first-present environment
flag is set. This path is intentionally separate from `backend/macos/wgpu`;
Skia is a provider package, not a host-core `NativeRenderer` variant.
For local real-Skia configuration, `scripts/macos-skia-renderer-smoke.sh` uses
dynamic `libskia.dylib` by default when `--write-local-config` is preparing
direct `moon run` commands, and static `libskia.a` by default for temporary
smoke/build rewrites when the archive is available; set
`MOUI_SKIA_MACOS_LINK_MODE=dynamic|static` or pass `--link-mode` to override.
`macos_skia_provider_preflight_summary()` exposes package-level preflight
evidence for the selected font resolution, renderer availability,
`moui_skia/native` availability, the `NSImageView` presenter path, inherited
AppKit host service/input/window readiness, explicit
`HostWindowRenderer` bridge forwarding for Skia text-system, image-resource,
image-resource change callbacks, present-count, and disposal diagnostics,
clipboard/menu/file-dialog/open URL/system-theme/async-service readiness,
native context-menu and host-modal file-dialog readiness, native accessibility
status, and the runtime evidence boundary. Treat that summary as
provider/package evidence
only; MoUI macOS Skia runtime proof still comes from the real-Skia renderer
pixel smoke plus Showcase or Markdown Editor first-frame smoke markers.
The macOS host loop records the renderer image-resource revision after each
present, routes later observed revision changes through the matching window's
`request_redraw`, exposes tracked-window revision snapshots for diagnostics,
calls the optional provider-owned `HostAsyncImageLoader` after the presented
revision is baselined, and removes tracked image revisions plus in-flight image
loads when a host window is disposed.

Packages that use `backend/macos` directly must link the AppKit service bridge
frameworks during the final native link step. Missing `_objc_msgSend` or
`___CFConstantStringClassReference` usually means that link step is missing the
host-core flags:

```moonbit
link: {
  "native": {
    "cc-link-flags": "-framework AppKit -framework QuartzCore -framework UniformTypeIdentifiers -lz"
  },
},
```

Packages that use `backend/macos/wgpu` also need QuartzCore, CoreText,
CoreGraphics, Foundation, CoreFoundation, and Objective-C flags for the WGPU
surface and native text provider. Missing `CAMetalLayer` or CoreText raster
symbols mean the provider flags are absent from the final link:

```moonbit
link: {
  "native": {
    "cc-link-flags": "-framework AppKit -framework QuartzCore -framework UniformTypeIdentifiers -framework CoreText -framework CoreGraphics -framework Foundation -framework CoreFoundation -lobjc -lz"
  },
},
```

Use `moon run <package> --target native --dry-run -v` to inspect the final
`cc` command and confirm the expected flags are present. If `moon build` works
but `moon run` links a temporary native stub dylib without those flags, use the
README build-and-execute flow while debugging the toolchain/link configuration.

## Windows Native

Windows native examples use the MSVC toolchain with Visual Studio C++ build
tools, vcpkg `zlib:x64-windows`, and `wgpu_mbt` dynamic mode with the official
`wgpu-windows-x86_64-msvc-release.zip` release.

For MSVC setup and packaging:

```powershell
winget install --id Microsoft.VisualStudio.2022.BuildTools -e
powershell -ExecutionPolicy Bypass -File .\scripts\windows\setup_msvc_deps.ps1 -InstallZlib
powershell -ExecutionPolicy Bypass -File .\scripts\windows\build_windows_msvc.ps1 `
  -Package examples/showcase/windows `
  -BuildOnly
powershell -ExecutionPolicy Bypass -File .\scripts\windows\package_windows_app_msvc.ps1 `
  -Package examples/showcase/windows `
  -AppName MoUIShowcase
```

The MSVC helper imports `vcvarsall.bat` through `vswhere`, sets `CC` and `CXX`
to `scripts\windows\msvc_cl.cmd`, enables MSVC C11 mode and atomics only for
`.c` native stubs such as `wgpu_mbt`, sets `MBT_WGPU_LINK_MODE=dynamic`, and
points `MBT_WGPU_NATIVE_ROOT` at the extracted MSVC WGPU release. `moui_skia`
emits `/std:c++20` stub flags for its Windows Skia C++ bindings, which remain
separate from the C11-only path. Packaged MSVC apps
use the vcpkg `zlib:x64-windows` runtime for native image decoding. When the
Visual Studio-bundled vcpkg rejects direct classic installs, run
`setup_msvc_deps.ps1 -InstallZlib` so the dependency is installed with an
ignored repository-local manifest workspace under `.tools\vcpkg-msvc`. Packaged
apps should be launched through the generated `run.cmd` so the bundled WGPU
release metadata is visible to the dynamic loader.

To run an entrypoint directly after setup:

```powershell
powershell -ExecutionPolicy Bypass -Command "& { . .\scripts\windows\msvc_env.ps1; moon run examples/showcase/windows --target native }"
powershell -ExecutionPolicy Bypass -Command "& { . .\scripts\windows\msvc_env.ps1; moon run examples/showcase/windows_skia --target native }"
powershell -ExecutionPolicy Bypass -Command "& { . .\scripts\windows\msvc_env.ps1; moon run examples/markdown_editor/windows_skia --target native }"
```

For matching-host Skia first-frame evidence, set
`MOUI_WINDOWS_SKIA_EXIT_AFTER_FIRST_PRESENT=1` for Showcase or
`MOUI_MARKDOWN_EDITOR_WINDOWS_SKIA_EXIT_AFTER_FIRST_PRESENT=1` for Markdown
Editor in the same MSVC environment before the `moon run` command. The host
option exits after any injected renderer reports a presented frame; keep the
resulting log/artifacts scoped to Windows runtime evidence.

The Windows host follows the same `HostEvent` and `HostRuntimeDriver` path as
macOS, with platform-specific ownership limited to Win32 window handles,
services, lifecycle, resize handling, text-input session synchronization, and
redraw requests. Concrete rendering is injected through
`WindowsRendererProvider`; `backend/windows/wgpu` owns HWND/HINSTANCE WGPU
surface creation and `backend/windows/skia` owns the GDI pixel presenter. Text
clipboard requests are implemented through the Win32
`CF_UNICODETEXT` clipboard API and normalized to UTF-8 at the host-service
boundary. The Windows service bridge also opens URLs through `ShellExecuteW`,
presents basic open/save/directory dialogs through the Win32 common dialog and
shell APIs, presents command menus at the current cursor position through
`TrackPopupMenu`, and reports light/dark system theme from the current user's
`AppsUseLightTheme` registry value.
The native app entrypoint applies that reported theme to the runtime environment
before creating the host driver, matching the macOS startup path. Windows
theme-change events use the shared `HostEvent::ThemeChanged` runtime path when
emitted by the local window backend.
Right-click context-menu requests use the same `TrackPopupMenu` path and dispatch
the selected `ActionCommand` back through `HostRuntimeDriver`.
File drag/drop events emitted by the local `window/windows` backend are
normalized through `HostEvent::DragDrop` and dispatched to
`View::on_file_drop` targets, matching the macOS host path.
`backend/windows/wgpu` installs the sibling `render/wgpu/directwrite` provider
through the same renderer/runtime boundary used by macOS CoreText and composes
it with `render/wgpu/cosmic_text` as fallback. That provider is currently an
explicit scaffold using `render/wgpu/text_protocol` for UTF-32 input encoding,
private versioned measurement payload parsing, a versioned registration
payload, and a generic shaped-run envelope for glyph placements plus
DirectWrite-private raster payloads. It also routes raster glyph bytes through
the shared single-channel raster parser. Its native stub advertises the
DirectWrite integration point while returning no platform layout/raster data,
so the composed Cosmic fallback handles native text until the real DirectWrite
engine lands. Choose `MoonCosmic` with
`WindowsWgpuAppOptions::new(text_engine=...)`.
The `examples/showcase/windows_cosmic` entrypoint selects `MoonCosmic` explicitly
for comparison with the platform-default DirectWrite scaffold plus Cosmic fallback
path. The `examples/showcase/windows_skia` entrypoint selects the Windows Skia
provider explicitly for Showcase, and
`examples/markdown_editor/windows_skia` selects it for the editing workflow.
The Markdown Editor also has `examples/markdown_editor/windows_cosmic` for the
same explicit text-provider comparison on the editing workflow.

Select Skia by importing `wzzc-dev/moui/backend/windows/skia` and using
`WindowsSkiaAppOptions`. The provider creates `render/skia.SkiaRasterRenderer`
and presents the CPU pixel frame through the Win32 presenter. The C presenter
copies the RGBA premultiplied readback into a top-down 32-bit BGRA DIB buffer
and blits it to the client DC with `StretchDIBits`. If `moui_skia/native` is only
in fallback mode, renderer creation is rejected with a diagnostic instead of
opening an empty HWND.
`windows_skia_provider_preflight_summary()` exposes package-level preflight
evidence for the selected font resolution, renderer availability,
`moui_skia/native` availability, the GDI presenter path, inherited Win32 host
service/input/window readiness, explicit clipboard/menu/file-dialog/open
URL/system-theme/async-service readiness, the `HostWindowRenderer` bridge that
forwards Skia text-system, image-resource, present-count, and disposal
diagnostics, native context-menu and host-modal
file-dialog readiness, native accessibility status, and the matching-host
runtime boundary, including whether the first-frame smoke option is enabled.
Treat that summary and its package test as provider/preflight evidence only;
The Windows host loop records the renderer image-resource revision after each
present, routes later observed revision changes through the matching HWND's
`request_redraw`, exposes tracked-window revision snapshots for diagnostics,
calls the optional provider-owned `HostAsyncImageLoader` after the presented
revision is baselined, and removes tracked image revisions plus in-flight image
loads when a host window is disposed.
Passed Windows runtime evidence still needs a Windows/MSVC host running the
Showcase or Markdown Editor Skia entrypoints with recorded artifacts. On
non-Windows hosts, the Win32 presenter and service stubs may fail C compilation
because they require `windows.h`, so a Darwin failure of
`moui/backend/windows/skia` is a host/toolchain limit rather than Windows
runtime evidence.

To use a preseeded local `wgpu-native` release instead of the helper-managed
copy, set `MBT_WGPU_NATIVE_ROOT` to the extracted MSVC release root or pass that
path as `-WgpuNativeRoot` to the Windows helper script. MSVC dynamic roots
should contain `lib\wgpu_native.dll` and
`wgpu-native-meta\wgpu-native-git-tag`.

## Linux Native

`backend/linux` is a minimal native Wayland host core. It uses the fork-owned
`.local_repos/window/linux` package for Wayland event-loop and window handles,
normalizes window/input events through the shared `HostEvent` contract, and runs
the Showcase entrypoints through the same renderer/runtime boundary as macOS
and Windows. Concrete rendering is injected through `LinuxRendererProvider`;
`backend/linux/wgpu` creates native WGPU surfaces from `wl_display` and
`wl_surface`, while `backend/linux/skia` reuses the window package's
`Window::present_rgba_pixels` presenter.

The Wayland window path requests server-side decorations when the compositor
exposes `xdg-decoration`. If the compositor falls back to client-side
decorations, `backend/linux` reserves a small titlebar band above the MoUI
content, draws the window title and basic controls into the renderer command
stream, and translates input coordinates so application views still receive a
content-origin coordinate space.
The same adapter consumes the window fork's Wayland key/modifier mapping and
current pointer coordinates: Linux backend tests cover modifier propagation into
shared keyboard events and button events using the position carried by the
window event rather than stale pointer state.

Linux runtime requirements are intentionally native:

- A Wayland compositor. For repeatable headless checks, run Weston with the
  headless backend and point `WAYLAND_DISPLAY` at its socket.
- A usable Vulkan stack for `wgpu-native`. Headless software validation can use
  Mesa llvmpipe through `vulkan-swrast`/Lavapipe when hardware Vulkan is not
  available.
- Wayland development headers and generated xdg-shell protocol sources for the
  local `window/linux` native stub.
- zlib in the final native link; Linux entrypoints and `backend/linux` include
  `-lz`.

Useful focused commands on a configured Linux host:

```sh
moon test moui/backend/linux --target native
moon build examples/showcase/linux --target native
moon build examples/showcase/linux_cosmic --target native
moon build examples/showcase/linux_skia --target native
moon build examples/markdown_editor/linux_skia --target native
moon run examples/showcase/linux --target native
moon run examples/showcase/linux_cosmic --target native
moon run examples/showcase/linux_skia --target native
moon run examples/markdown_editor/linux_skia --target native
```

For matching-host Skia first-frame evidence, set
`MOUI_LINUX_SKIA_EXIT_AFTER_FIRST_PRESENT=1` for Showcase or
`MOUI_MARKDOWN_EDITOR_LINUX_SKIA_EXIT_AFTER_FIRST_PRESENT=1` for Markdown
Editor before the `moon run` command. The Linux host exits after the injected
renderer reports a presented frame; keep those logs scoped to Linux Wayland
runtime evidence.

When validating from a Linux VM mounted over the same checkout as a macOS or
Windows host, keep native build output isolated. Either run `moon clean` before
switching hosts or copy the checkout to a Linux-local temporary directory
without `_build`; the native archive and MoonDB files are host-specific and can
be corrupted by cross-host reuse.

The platform-default text path in `backend/linux/wgpu` composes the Linux
`render/wgpu/fontconfig` scaffold provider with the shared Moon Cosmic fallback.
Choose `MoonCosmic` with `LinuxWgpuAppOptions::new(text_engine=...)`;
`examples/showcase/linux_cosmic` selects the Moon Cosmic provider explicitly for
comparison.

Select Skia by importing `wzzc-dev/moui/backend/linux/skia` and using
`LinuxSkiaAppOptions`. The provider creates `render/skia.SkiaRasterRenderer` and
presents the CPU pixel frame through a narrow API exposed by
`.local_repos/window/linux`. That window fork owns the Wayland objects and
provides `Window::present_rgba_pixels`, implemented with reusable `wl_shm`
buffers, buffer-release tracking, `wl_surface_attach`, damage, commit, and
display flush. Keeping the `wl_shm` presenter in the window backend avoids
duplicating Wayland registry and buffer ownership in MoUI.
`linux_skia_provider_preflight_summary()` exposes package-level preflight
evidence for the selected font resolution, renderer availability,
`moui_skia/native` availability, the `wl_shm` presenter path, inherited Wayland
host service/input/window readiness, explicit Linux clipboard/menu/file-dialog/open
URL/async-service, text-input/IME/drag-drop, and native
context-menu/host-modal/native accessibility gaps, `HostWindowRenderer` bridge
forwarding for Skia text-system, image-resource, present-count, and disposal
diagnostics, plus system-theme readiness
and the matching-host runtime boundary, including whether the first-frame smoke
option is enabled. The Linux host loop records the renderer image-resource
revision after each present, routes later observed revision changes through the
matching Wayland window's `request_redraw`, exposes tracked-window revision
snapshots for diagnostics, calls the optional provider-owned
`HostAsyncImageLoader` after the presented revision is baselined, and removes
tracked image revisions plus in-flight image loads when a host window is
disposed. The summary is useful for provider/package
audits, but it does not prove a real Wayland compositor presented Showcase or
Markdown Editor frames;
those claims still require matching-host runtime runs and platform evidence
manifest entries.

The local window fork carries a consumer-style Linux smoke for this dependency
surface. On a matching Wayland host, run
`.local_repos/window/scripts/check_moui_linux_smoke.sh --run` to exercise
surface creation, public Wayland handles, `Window::present_rgba_pixels`, resize,
redraw, and clean shutdown. Add `--require-input` or
`WINDOW_MOUI_LINUX_REQUIRE_INPUT=1` only when representative pointer/keyboard
input is observed. Record dependency-level facts with
`.local_repos/window/scripts/record_moui_evidence.sh`; keep the MoUI Showcase
`linux`, `linux_cosmic`, `linux_skia`, and Markdown Editor `linux_skia` runs as
separate application-level evidence.

`examples/showcase/linux_skia` and `examples/markdown_editor/linux_skia` select
this provider explicitly for Showcase and the editing workflow. Configure real
Skia link flags before relying on native Skia-rendered pixels.
The default JetBrains Linux provider links fontconfig, FreeType, and HarfBuzz;
with those libraries available, `moui_skia` builds a system `FontMgr` through
fontconfig and falls back to common font directories such as `/usr/share/fonts`
when fontconfig reports no families. Missing CJK or emoji glyph coverage still
depends on installed system fonts, and full mixed-script fallback runs remain a
text-system follow-up rather than a Linux backend responsibility.

Remaining Linux gaps stay visible in `backend/linux.readiness()`:

- Clipboard, menus, file dialogs, drag/drop, and AT-SPI native bindings are not
  implemented yet.
- Basic US-QWERTY keyboard character input is derived from Wayland key events;
  Wayland text-input protocol support and IME/composition requests are still
  reported as unsupported until the window package exposes that protocol
  surface.
- The fontconfig/HarfBuzz/FreeType native provider remains a scaffold and relies
  on the composed Moon Cosmic fallback for actual glyph data.

## Platform Validation

Use focused platform validation instead of broad all-repository native checks:

```sh
moon test moui/backend/host --target native
moon test moui/backend/web --target wasm-gc
sh scripts/conformance-check.sh --platform-services
sh scripts/dev-check.sh --platform-examples-test
```

Before release-style validation on a configured host, include platform example
builds:

```sh
sh scripts/dev-check.sh --platform-examples-build
```

When changing event conversion, also run the affected backend package tests. When
changing renderer surface creation or WGPU setup, build at least one native
example for the current platform.
