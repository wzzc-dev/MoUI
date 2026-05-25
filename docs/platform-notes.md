# Platform Notes

## Local Window Dependency

MoUI expects the modified `Milky2018/window` checkout under `.local_repos/window`.
The README shows the setup commands. The local branch currently supplies target
support that the upstream package does not yet cover for MoUI.

## Shared Host Contract

Platform backends normalize window, input, surface, focus, text input, redraw,
and close events through `backend/host`. App code receives the same core event
model regardless of whether the host is Web, macOS, or Windows.
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
The active Web, macOS, and Windows hosts accept a shared queue through
`run_app_with_window_requests` and drain current-window focus, close, resize,
minimize, show, and set-primary requests at the platform edge. Each drained
request records an ordered completion on the same queue, so tests and
higher-level host code can observe accepted current-window operations and
explicit rejections. Active backends use the shared queue drain helper for that
drain-and-record loop so future `OpenWindow` support does not need a separate
completion path on each platform. `OpenWindow` requests are still rejected until
the hosts wire scene resolution and runtime slots into multiple platform windows
and renderer instances.
The current Web, macOS, and Windows entrypoints still create one primary window,
but they allocate that window through the registry, register the existing
runtime/driver as the primary `HostWindowRuntimeSlot`, bind the platform window
id to the host id, route platform window events through that mapping, apply
`HostEvent::Resized`, focus, and close events to it, sync the slot record after
lifecycle changes, and close/remove the slot, platform binding, and record
during host disposal. That keeps today's single-window apps on the same state
path future multi-window hosts will use.
Web also stores the active browser `Window` and `WebRenderer` in a local
per-window platform slot collection. `OpenWindow` is still rejected, but the Web
host no longer has to rewrite one global window/renderer pair before it can own
multiple canvases.

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
- Permission- or callback-driven host services can use `HostServiceAsyncQueue`
  and return `HostServiceResponse::Pending` instead of blocking the runtime.
  Hosts drain pending requests into in-flight platform work, complete them with
  the original request, and dispatch completions through `HostRuntimeDriver`
  when the response affects runtime state such as clipboard paste.
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
The active Web runtime now drains pending async service requests into browser
callbacks. Clipboard reads complete through exported wasm callback functions.
Open-file and directory dialogs use a hidden browser file input and return
browser-exposed file names or relative paths. Save dialogs use the File System
Access API when `showSaveFilePicker` is available and otherwise complete as an
unavailable service. Canceled file pickers return an empty selection.
The browser host import reads `prefers-color-scheme` at startup and listens for
media-query changes through `window/web`; MoUI maps those events into runtime
environment color-scheme updates.
Browser file drag/drop events on the canvas are normalized through
`HostEvent::DragDrop` and dispatched to `ViewSpec::on_file_drop` targets. The
Web platform receives browser-exposed file names or relative names rather than
native filesystem paths.
See [Text system](text-system.md) for the shared runtime and renderer text
contract.

The reusable browser runtime assets live under `backend/web/*.js`. Each
`examples/*/web_wasm/` package is only the app-specific Web entrypoint and
supplies the example-specific wasm URL. The canvas host reports logical event
coordinates after DPR mapping and avoids CSS transforms, borders, and padding so
resize and input coordinates stay stable.

## macOS Native

The macOS host uses `Milky2018/window/macos` for AppKit windows and installs a
`CAMetalLayer` on the window `NSView` for the native `render/wgpu` renderer.
Window events pass through the shared `backend/host` conversion helpers, and the
native host owns only AppKit window lifetime, CAMetalLayer surface creation,
text-input session synchronization, renderer resize, and redraw requests.
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
through `HostEvent::DragDrop` and dispatched to `ViewSpec::on_file_drop`
targets.
Native WGPU text can use either the shared Moon Cosmic provider or a platform
provider. macOS defaults to the CoreText/CoreGraphics provider for runtime
measurement and glyph rasterization, explicitly composed with the Moon Cosmic
provider as fallback; the Objective-C CoreText stub lives in
`render/wgpu/coretext`, while the selectable/composed Cosmic provider lives in
`render/wgpu/cosmic_text`. The CoreText provider consumes the shared native
`FontSpec` payload, attempts named families from the structured family stack,
maps generic CSS families such as `ui-monospace` and `serif` to suitable macOS
fonts, registers app-provided font bytes under their requested family alias when
CoreText accepts them, and falls back to the system font for unavailable names
before the renderer tries the composed Cosmic fallback.
`backend/macos` chooses between them through
`run_app_with_options(..., options=MacosAppOptions::new(text_engine=...))` when
creating the generic native WGPU renderer. `core` still owns only the neutral
`FontSpec`, `TextSystem` contract, and deterministic fallback text system; it
does not name concrete macOS font files.
The `examples/showcase/macos_cosmic` entrypoint selects `MoonCosmic`
explicitly for comparison with the platform-default CoreText path.

Packages that use `backend/macos` must link the macOS frameworks required by
the Objective-C stubs during the final native link step. Missing surface/window
symbols such as `_OBJC_CLASS_$_CAMetalLayer`, `_objc_msgSend`, or
`___CFConstantStringClassReference` usually mean that link step is missing the
backend flags:

```moonbit
link: {
  "native": {
    "cc-link-flags": "-framework AppKit -framework QuartzCore -framework UniformTypeIdentifiers -lz"
  },
},
```

Missing CoreText raster symbols mean the `render/wgpu/coretext` provider flags
are absent from the final link:

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

Windows native examples are built with MSYS2 UCRT64 and the static Windows GNU
`wgpu-native` release expected by
`scripts/windows/markdown_editor_windows_static.ps1`.
The Windows host follows the same `HostEvent` and `HostRuntimeDriver` path as
macOS, with platform-specific ownership limited to Win32 window handles, WGPU
surface creation, resize handling, text-input session synchronization, and redraw
requests. Text clipboard requests are implemented through the Win32
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
`ViewSpec::on_file_drop` targets, matching the macOS host path.
Windows installs the sibling `render/wgpu/directwrite` provider through the same
renderer/runtime boundary used by macOS CoreText and composes it with
`render/wgpu/cosmic_text` as fallback. That provider is currently an explicit
scaffold using `render/wgpu/text_protocol` for UTF-32 input encoding, private
versioned measurement payload parsing, a versioned registration payload, and a
generic shaped-run envelope for glyph placements plus DirectWrite-private raster
payloads. It also routes raster glyph bytes through the shared single-channel
raster parser. Its native stub advertises the DirectWrite integration point
while returning no platform layout/raster data, so the composed Cosmic fallback
handles native text until the real DirectWrite engine lands.
The `examples/showcase/windows_cosmic` entrypoint selects `MoonCosmic`
explicitly for comparison with the platform-default DirectWrite scaffold plus
Cosmic fallback path.

The expected archive extraction path is:

```text
.local_deps\wgpu-native\v27.0.4.0\wgpu-windows-x86_64-gnu-release
```

Download the archive from:

```text
https://github.com/gfx-rs/wgpu-native/releases/tag/v27.0.4.0
```

## Linux Scaffold

`backend/linux` intentionally preserves the host contract shape while reporting
that no Linux window backend is available yet. Its capability matrix currently
marks window, renderer, pointer, keyboard, text input, IME, clipboard,
drag/drop, accessibility, and scale-factor support as unavailable. It also exposes a
readiness report and an unavailable `HostServiceBridge`, so callers can inspect
blocked work without treating the scaffold as a runtime backend.

The Linux readiness blockers are:

- Add or consume a `window/linux` package that emits shared `HostEvent` values.
- Create a native WGPU surface path and resize contract for Linux.
- Map clipboard, menus, file dialogs, drag/drop, and accessibility through host
  contracts.
- Replace the existing `render/wgpu/fontconfig` native stub with a real
  fontconfig + HarfBuzz + FreeType implementation, or an equivalent toolkit text
  stack, without changing `core` font defaults. The scaffold already uses the
  same native-stub-backed `render/wgpu/text_protocol` measure/run/raster/register
  payload boundary as DirectWrite.

Keep the scaffold honest until those pieces exist.

## Platform Validation

Use focused platform validation instead of broad all-repository native checks:

```sh
moon test backend/host --target native
moon test backend/web --target wasm-gc
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
