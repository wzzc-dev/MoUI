# Platform Notes

## Window Package Dependency

MoUI resolves the modified window host as `wzzc-dev/window@0.5.4-0.1.6` from
the MoonBit registry. A repo-local window checkout is no longer part of normal
development. The fork package currently supplies target support that the
upstream package does not yet cover for MoUI.
The main checkout now includes `moui_skia`, which provides the editable Skia
binding used by the native Skia raster mainline renderer.

## Shared Host Contract

Platform backends normalize window, input, surface, focus, text input, redraw,
and close events through `backend`. App code receives the same core event
model across Web, macOS, Windows, and the current Linux Wayland scaffold.
`WindowRegistry` also provides shared bookkeeping for window ids, primary
windows, focused windows, close requests, closed-window cleanup, and per-window
surface metrics so future multi-window platform hosts do not duplicate lifecycle
state machines. `WindowRequestQueue` is the matching platform-neutral
request channel for opening, focusing, closing, resizing, minimizing, showing,
and changing the primary window. `OpenWindow` requests include a scene id and
payload in addition to title, metrics, and primary-window intent, giving future
multi-window hosts a stable app-level key for selecting content/runtime when a
new platform window is created. `WindowSceneResolver` resolves those
requests into new `AppRuntime` instances or explicit scene rejections without
embedding platform policy in app code. `@backend_common.resolve_open_request`
then binds a resolved runtime to the registry record that owns the new window
id, and `WindowRuntimeSlot` wraps the record with its `HostRuntimeDriver`.
`WindowRuntimeSlots` stores those per-window drivers, supports lookup and
primary/focused slot selection, syncs updated lifecycle records from the
registry, provides shared insert/sync/request/lifecycle-event helpers for
active backends, and removes closed slots. `PlatformWindowMap` binds
platform `WindowId` values to `WindowId` values, giving multi-window
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
resolver-backed `OpenWindow` requests through `WebAppOptions` captured by
`@web.entry`. Native host cores create platform windows through the same path
but do not choose concrete renderer families. Application entrypoints supply
ordered `RendererProvider` values and one platform `PlatformEntry` to
`@runtime.run_app`. A resolved native window creates an opaque `HostSurface`,
binds the first accepting provider to a `RendererSession`, then registers a `HostRuntimeDriver`,
platform binding, and platform slot, and routes redraw, events, context menus,
host service completions, IME sync, and disposal by `WindowId`. Without a
scene resolver, hosts reject `OpenWindow` with the shared unavailable-resolver
response.

Native renderer choice is application composition, not a field on host-core app
options. Use `@render_skia.from_env(platform=...)` with the composition root's
explicit `NativeGpuPlatform` for the native Skia mainline and
`@render_wgpu.native(...)` only for native WGPU experimental diagnostics.
Android, iOS, and HarmonyOS use `wzzc-dev/window` as the embedded runtime
backend's embedder. The template sends `HostCmd` through its `EventLoop` to the
matching `*EmbeddedRuntimeBackend`, which assembles the MoUI runtime session and
attaches the `RendererSession` resolved from application-supplied providers.
`wzzc-dev/window/internal/embedded_dispatch` is stateless physical callback
dispatch for all three packages; platform `HostCmd` adapters retain only
native payload decoding and nominal `ApplicationHandler`/`Window` effects.
`common/lifecycle::EmbeddedLifecycle` owns logical phase, surface generation,
primary window, detach, and application exit. `EmbeddedSession` composes it
with the shared frame/image/input/services owners plus renderer, IME,
semantics, platform-view, and transport capabilities without duplicating
lifecycle or frame-loop state.
Lifecycle, surface, and input must not bypass this route. HarmonyOS
XComponent callbacks are the sole source for surface, pointer, resize, and
detach. Fallback builds are build-system evidence only; matching-device or
simulator smoke is still required for a runtime claim.

Current-platform backend and renderer tests are included by
`sh scripts/check.sh --profile platform`. Run matching-host renderer smoke only
when the required host and toolchain are available.

The boundary is:

```text
platform window event -> Event -> AppRuntime -> DrawCommand -> renderer
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
- Native `web_view` is a platform-view contract rather than a renderer command.
  `moui/views` emits platform-view placements through the
  View paint plan, backend host contracts own WebView specs/events, and
  `DrawFrame.platform_views` carries rectangles that native hosts sync to real platform WebView
  objects after rendering the MoUI frame. Navigation is controlled: page/user
  navigation emits `WebViewEvent::NavigationRequested`, and the app commits by
  updating the view `url` or sending `WebViewCommand::LoadUrl` through the host
  command queue.
- The Sun provider forwards offscreen platform-view pixels through the neutral
  `RendererSession` capability. This is renderer composition wiring;
  matching-host runtime smoke is still required before making a broader
  platform runtime readiness claim.
- Typed host services are routed through `HostServiceBridge`, with explicit
  capability flags for clipboard, menus, file dialogs, text-file access, URL
  opening, and system theme. Unsupported services should return `Unavailable` responses instead of
  leaking platform checks into `core` or `views`.
- App-owned route history lives in `views` as `RouteHistoryState`, where it can
  model deep-link strings, back/forward cursors, and `RouterSnapshot`
  restoration without depending on a platform host. `moui/services` provides
  `RouteSource` for typed route/deep-link fanout through
  `Subscription::route_event`. `backend/web` wires browser
  `pushState`/`replaceState`/`popstate` into that route source and exposes Web
  history commands for app-owned route effects. Native URL bars, OS deep-link
  dispatch, and app history mutation remain separate platform/app
  integrations.
- `HostCapabilitySummary` is the app-facing diagnostics rollup over service,
  input, window, text-input, IME, drag/drop, async-service, accessibility, and
  native WebView readiness. Web, macOS, Windows, and Linux expose package-local
  summary helpers, and Showcase displays the injected summary in its Runtime
  section.
  `HostCapabilitySummary::preflight_fields()` provides a renderer-neutral
  ready/gap field string for diagnostics without importing concrete renderer
  policy into host cores.
- Permission- or callback-driven host services can use `ServiceAsyncQueue`
  and return `HostServiceResponse::Pending` instead of blocking the runtime.
  Hosts drain pending requests into in-flight platform work, complete them with
  the original request, and record completions. Runtime-owned responses such as
  clipboard paste are dispatched through `HostRuntimeDriver`; app-owned flows
  receive typed `ServiceTaskResult` messages. Request ids and completion queues
  remain private to the host adapter.
- Host service bridges can apply a reported light/dark system theme to a runtime
  `Environment`. Web, macOS, and Windows do this once at startup before the
  first layout/redraw pass. Runtime `ThemeChanged` window events are normalized
  to `Event::ThemeChanged` and update the environment through
  `HostRuntimeDriver`.
- Web, macOS, and Windows route copy/cut/paste keyboard shortcuts through the
  active service bridge. When that bridge exposes clipboard support, focused
  text controls read or write the platform clipboard; app action commands still
  receive the intent when no text command handles it. Pending clipboard reads
  are treated as handled until the async completion arrives, so paste commands
  are not dispatched twice.
- Secondary mouse-button presses are treated as context-menu requests at the
  host edge. Web, macOS, Windows, and Linux skip normal pointer dispatch for
  those events so right-click does not activate regular controls; macOS,
  Windows, and Linux then route the runtime action command menu through their
  native menu service.
  When a text input is focused, the host driver prepends MoUI's default text
  commands to that menu so native context menus can copy, cut, paste, undo,
  redo, and select text through the same clipboard and command path as keyboard
  shortcuts.

## Platform-Specific Notes

For detailed platform-specific setup, requirements, and runtime evidence:

- [Web Wasm-GC](platform-notes-web.md) — browser WebGPU, clipboard, file system access,
  route history, and touch scroll.
- [macOS](platform-notes-macos.md) — AppKit host, Skia/WGPU diagnostics, link flags,
  and service bridge details.
- [Windows](platform-notes-windows.md) — MSVC toolchain, Skia/WGPU setup, WebView2
  auto-detection, and host architecture.
- [Linux](platform-notes-linux.md) — Wayland host, runtime requirements, Skia composition,
  runtime evidence, and remaining gaps.
- [Android](android-support.md) (**experimental**) — window-hosted Activity,
  APK packaging, and matching-device evidence requirements.
- [iOS](ios-support.md) (**experimental**) — window-hosted UIKit template,
  simulator packaging, and matching-device evidence requirements.
- [HarmonyOS](harmonyos-support.md) (**experimental**) — window-hosted
  Stage Ability/XComponent template, HAP packaging, and signed-device evidence requirements.
- [WeChat Mini Program](wechat-support.md) (**experimental**) — Skyline Canvas 2D + wasm-gc,
  window-hosted app, touch events, WeChat Mini Program project template.

Product-class summary: [platform readiness declaration](platform-readiness-declaration.md).

## Platform Validation

Use focused platform validation instead of broad all-repository native checks:

```sh
moon test moui/backend --target native
moon test moui/backend/web --target wasm-gc
sh scripts/check.sh --profile platform
```

Before release-style validation on a configured host, include platform example
builds:

```sh
sh scripts/check.sh --profile full
```

When changing event conversion, also run the affected backend package tests. When
changing renderer surface creation or WGPU setup, build at least one native
example for the current platform.
