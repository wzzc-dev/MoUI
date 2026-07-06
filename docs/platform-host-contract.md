# Platform Host Contract

> 本文档描述 `moui/backend/host` 的共享边界契约。概述见
> [Architecture](../architecture.md)。

`backend/host` is the shared boundary between platform packages and the
platform-neutral runtime. It defines `HostSurfaceMetrics`, input capabilities,
coordinate policies, `HostEvent`, text input session synchronization,
`HostRuntimeDriver`, file drag/drop normalization, and `HostWindowRegistry` for
platform-neutral window lifecycle and multi-window bookkeeping. It also exposes
`HostWindowRequestQueue` so app/runtime or higher-level host code can enqueue
open, focus, close, resize, minimize, show, and primary-window requests without
embedding those requests in a platform backend. `OpenWindow` requests carry a
platform-neutral scene id and payload alongside title and metrics, so future
multi-window hosts have enough app-level identity to choose the runtime/content
for the new platform window. `HostWindowSceneResolver` is the matching shared
contract for resolving those scene requests into new `AppRuntime` instances or
explicit scene rejections before a platform backend allocates a native window.
`HostEventSource` is the host-layer subscription adapter for app-owned
host-event fanout: platform code can publish normalized `HostEvent` values,
while apps map selected events back into typed `Program` messages through
`Subscription::host_event`; cancellation removes the publisher handler so late
host events do not re-enter stale app state.
`HostWindowEventSource` is the matching host-layer subscription adapter for
window-scoped platform events: platform code can publish a `HostWindowId` plus
normalized `HostEvent`, while apps map those `HostWindowEvent` values through
`Subscription::window_event`; cancellation removes the publisher handler so late
window events do not re-enter stale app state.
`HostPlatformEventSources` bundles the host-event and window-event sources for
platform runtimes. Web, macOS, Windows, and Linux app options can carry that
bundle; after a raw platform event is normalized and dispatched through the
matching `HostRuntimeDriver`, the backend publishes the same `HostEvent` with
its `HostWindowId` so app-owned `Subscription::host_event` and
`Subscription::window_event` adapters can observe real runtime events without
moving platform event conversion into `core`.
`HostTimerSource` is the matching host-layer subscription adapter for app-owned
timer ticks: host/platform code provides the scheduler callback, while apps map
`@core.Frame` ticks back into typed `Program` messages through
`Subscription::timer`; cancellation runs the scheduler cleanup so late timer
callbacks are ignored by the stale-dispatch guard.
`HostRouteSource` is the matching host-layer subscription adapter for app-owned
route/deep-link streams: host/platform code can publish `HostRouteEvent` values
carrying `@core.RouteLocation` plus a source label, while apps map those events
through `Subscription::route_event`; cancellation removes the publisher handler
so late route events do not re-enter stale app state. The adapter does not
mutate `RouteHistoryState` or synchronize browser/native history by itself.
`HostWindowRegistry::resolve_open_request` pairs a successful scene resolution
with the created registry record so the host can keep window id, scene metadata,
and runtime together. `HostWindowRuntimeSlot` then wraps that record with a
`HostRuntimeDriver`, giving future multi-window hosts a shared per-window
runtime/driver shape before platform-specific window and renderer handles are
attached. `HostWindowRuntimeSlots` is the matching collection for lookup,
primary/focused slot selection, record synchronization, and closed-window
cleanup, including shared helpers for inserting and syncing slots from
`HostWindowRegistry`, applying platform-neutral window requests, and applying
host lifecycle events while keeping the slot record aligned.
`HostPlatformWindowMap` binds platform window ids from `wzzc-dev/window` to
MoUI `HostWindowId` values so event dispatch can route through the host registry
instead of assuming one global window.
`HostWebViewCapabilities`, `HostWebViewCommandQueue`, and
`HostWebViewEventSource` are the host-side contract for native platform
WebViews. Hosts report whether native embedding is available, sync
`DrawFrame.platform_views` to concrete WebView objects, dispatch
`HostEvent::WebView` back into the runtime, and drain queued commands at the
platform edge. Browser Web wasm reports unavailable instead of creating an
iframe overlay.
Web, macOS, Windows, and Linux should convert their native window events into
`HostEvent` and then let `AppRuntime` update state, rebuild, and emit
`DrawCommand` values.
The active Web, macOS, Windows, and Linux hosts all open a primary
`HostWindowRecord`, register the existing runtime/driver as a primary
`HostWindowRuntimeSlot`, bind the platform window id to the host id, route
incoming platform window events through that mapping, apply resize/focus/close
`HostEvent` values through the registry, sync slot records after lifecycle
changes, and remove slot, platform binding, and record when a host window is
disposed. That makes multi-window lifecycle state a shared host concern instead
of a future platform-specific rewrite. Platform entrypoints also accept a
shared `HostWindowRequestQueue` through their options-bearing runner and drain
focus, close, resize, minimize, show, and set-primary requests at the platform
edge. The same queue records ordered request completions, making accepted
operations and explicit rejections observable. Active backends use the shared
queue drain helper so completion recording stays a host contract instead of a
platform-local loop.
`HostWindowCommands` is the higher-level command facade over the same queue for
app-facing open/focus/resize/minimize/show/close helpers and shared draining
into a registry or window runtime slots.
Web exposes `run_app_with_options` directly because the browser renderer is part
of that host. Native host cores instead expose
`run_app_with_renderer_provider`; public native entrypoints live in
`backend/<platform>/wgpu` and `backend/<platform>/skia`. Those provider packages
carry the user-facing `run_app`, `run_app_with_options`, renderer-specific
options, and `renderer_provider` constructor. With a resolver, `OpenWindow`
requests resolve a scene into a new `AppRuntime`, create another platform
window, ask the provider for a `HostWindowRenderer`, register a per-window
`HostRuntimeDriver`, bind the platform id, and then route redraw, events,
context menus, service completions, IME sync, and disposal through
window-indexed slots. Without a resolver, hosts reject `OpenWindow` with the
shared unavailable-resolver message.

`HostWindowRenderer` is the renderer-neutral runtime handle used by native host
cores. It is a record of closures for resize, render, text-system access,
image-resource diagnostics, present-count diagnostics, and disposal. The shared
image repaint tracker consumes renderer-neutral image snapshots to route
late-image redraws per open window and expose tracked-window revision plus
loading/ready/failed/disposed status-count diagnostics, including
previous/current counts on repaint results. Host cores depend only on
`core`/`backend/host` plus the platform `window` package; they do not import
`render/wgpu`, `render/skia`, `wgpu_mbt`, or `moui_skia`. Skia provider
packages own the native mainline renderer creation, pixel presenter bridges,
and Skia availability diagnostics. WGPU provider packages retain GPU surface
bridges, `wgpu-native`, and native WGPU text provider composition as
experimental diagnostics.

`HostImageResourceCompletionSource` is the host-layer boundary for native async
image loader completions. Native provider/platform loaders publish
`@render.ImageResourceLoadCompletion` ready/failed results through
`HostWindowRenderer::apply_image_resource_load_completion`, which returns a revisioned
`@render.ImageResourceSnapshot`; the host routes that snapshot through
`HostImageResourceRepaintTracker`, requests redraw only for matching open
windows, ignores stale lower revisions, and discards closed-window completions.
`HostAsyncImageLoader` is the host-side scheduler adapter for that boundary: it
scans renderer snapshots for loading records, starts a platform/provider loader,
deduplicates in-flight `(window, source)` work, and gates late or cancelled
completion callbacks before they can apply to a renderer. `HostNativeAsyncImageSource`
is the host-owned deferred request source for platform loaders that need to
record pending `(window, source)` work and deliver a completion later from an
independent native callback. It proves the host boundary can receive late
completion callbacks after scheduling returns, and platform runtime artifacts
record host-level observation separately from renderer capability status. The native macOS,
Windows, and Linux host cores call the optional provider-owned loader hook after
the presented image-resource revision has been baselined, then cancel in-flight
window loads during disposal. Native WGPU provider packages now supply a
provider-owned loader that turns renderer-owned PNG/JPEG/BMP source decode
results into `ImageResourceLoadCompletion` payloads. Native Skia provider
packages now install the same provider-owned loader
boundary around decoded image completions, and provider-created Skia renderers
opt into post-present async image loading so the first presented snapshot can
contain loading records before the host routes ready/failed completions into a
repaint. Local-file provider workers read and decode Skia images off the main
thread, then deliver decoded RGBA pixels, dimensions, row bytes,
`background_io`, and `background_decode` through `ImageResourceLoadCompletion`.
Skia applies decoded ready completions directly into the renderer image cache,
while data URI sources complete through the renderer decode path. This is
provider completion and smoke-log evidence at the renderer/host boundary. The
host source and scheduler do not decode images, mutate renderer caches, or live
in `core`;
renderer/provider packages still own concrete loading and lifecycle records.

`RendererDescriptor` and `RendererSelection` remain renderer facade reporting tools:
they describe static capability identity and matching, not native host runtime
assembly. `View` still describes UI declaration trees only, and
`Binding[T]` remains the TEA/control/state two-way binding term.

Typed host services live on the same boundary. `HostServiceBridge` exposes
capability-checked dispatch for clipboard, file dialogs, menus, open-URL, and
system-theme requests. Backends can report unavailable services without
pretending that app code can call platform APIs directly.
`HostCapabilitySummary` folds those service flags together with input,
window-lifecycle, text-input, IME, drag/drop, async-service, and native
accessibility readiness. It is a high-level reporting API for apps, diagnostics,
and Showcase. Its `preflight_fields()` helper emits a renderer-neutral ready/gap
field string for provider/package audits such as native Skia preflight logs;
`HostServiceBridge`, `HostInputContract`, and platform backend setup remain the
source of truth for actual behavior.
`HostAppServices` is the app-facing facade over that same bridge, with helper
methods for clipboard, file dialogs, URL opening, system theme, context menus,
optional async queue completion handling, and an app-level
`completion_subscription` adapter; the bridge remains the source of truth for
capability routing and platform dispatch.
Services that cannot finish synchronously, especially browser clipboard reads
and file dialogs that need a permission or picker callback, can return
`HostServiceResponse::Pending` through `HostServiceAsyncQueue`. The host drains
pending requests into an in-flight set at the platform edge, completes them with
the original request attached, and records the completion. Runtime-owned
effects such as async paste are handed to `HostRuntimeDriver`, while app-owned
service flows should store pending request ids in model state and declare
`HostAppServices::completion_subscription` from `Program` subscriptions so the
completion re-enters the typed message loop without exposing platform APIs to
`core`. When that subscription is canceled because the model leaves the pending
state or the runtime is destroyed, the host queue releases its completion
handler; a later platform response is retained as a normal completed record
instead of dispatching through a dead app callback. The lower-level
`HostAppServices::on_completed` callback remains available for custom adapters.
The Web backend wires that queue to browser host imports and exported wasm
completion callbacks for clipboard reads and file pickers.
Web, macOS, and Windows entrypoints query that bridge at startup and install
the reported light/dark scheme into `AppRuntime` before the first host driver
layout/redraw pass, so initial view builds see the platform color scheme through
`ComponentContext` environment reads.
`ThemeChanged` window events are also normalized into `HostEvent::ThemeChanged`;
`HostRuntimeDriver` applies them to runtime environment instead of leaking a
platform-specific event into app code.

Keyboard shortcuts, menus, and host command responses share the
`ActionCommand`/`CommandIntent` model. `ActionCommandMap` is the platform-neutral
dispatcher for matching shortcuts and invoking enabled command handlers.
Application-facing command metadata aliases are exported from `moui/views`
alongside the command palette and menu constructors; lower-level runtime and
host integration can still use the `core` contract directly.
The `views` package also provides view-level menu helpers over the same
metadata: `menu_bar`, `command_menu`, and `context_menu_region` render buttons,
rows, surfaces, and overlays as ordinary `View[Msg]` values. They are fallback
or app-authored menu UI, not platform menu services.
Copy, cut, and paste shortcuts are routed through `HostRuntimeDriver` with the
active `HostServiceBridge` so focused text controls use the platform clipboard
when that service is available, while app-level command handlers still run when
no text command handles the intent.
Secondary-button context-menu requests are recognized by the host event layer:
platform backends skip ordinary pointer dispatch for those events, then native
menu-capable hosts ask `HostServiceBridge::ShowMenu` to present the current
runtime action commands and dispatch the selected intent back through
`HostRuntimeDriver`.
File drop targets use the `View::on_file_drop` modifier; hosts normalize native
file drag/drop positions and paths before the runtime dispatches typed messages
to the hit view. `views.drop_zone` and `views.file_import_panel` are view-level
workflow shells over that modifier; their browse action remains an app message,
so effect-capable app code can return an `Effect::host_service` runner that calls
`HostAppServices::open_file`, dispatch typed completion messages for
unavailable or synchronous file dialog responses, and declare
`HostAppServices::completion_subscription` for pending dialogs. Web file import may
expose browser-selected file names or handles rather than native filesystem
paths, while native hosts can return platform paths through the same selection
array.

See [Platform notes](platform-notes.md) for setup, backend-specific constraints,
and validation commands.
