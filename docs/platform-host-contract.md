# Platform Host Contract

> This document describes the shared boundary contract of `moui/backend`. For an overview,
> see [Architecture](architecture.md).

Root `backend` defines platform-neutral protocols and DTOs: input capabilities,
coordinate policies, `Event`, `WindowId`, window requests, services, IME,
accessibility, and platform views. `SurfaceMetrics` lives in `core`. Per ADR 0018,
`HostRuntimeDriver`, `RedrawScheduler`, and `HostWallClock` live in
`moui/runtime`; `backend` consumes them as contracts but does not own
them.

`backend/common` implements the contract. It owns `WindowRegistry`,
`WindowRequestQueue`, the unique platform-window map, lifecycle/frame/input
state, text-input synchronization, and service adapters. It converts
already-neutral Close, Focus, resize/scale, redraw, and surface lifecycle facts
to `Event`, keeps surface lifecycle state, and normalizes logical
coordinates. It imports this contract but is not imported by it. Raw native
pointer, keyboard, IME, drag, and modifier decoding belongs to the concrete
platform backend; WeChat's direct Canvas2D callbacks remain a deliberately
non-window-hosted exception.

Root `backend` exposes the closure-based `WindowRequests` port;
`backend/common` implements it with `WindowRequestQueue` so runtime or platform code can enqueue
open, focus, close, resize, minimize, show, and primary-window requests without
embedding those requests in a platform backend. `OpenWindow` requests carry a
platform-neutral scene id and payload alongside title and metrics, so future
multi-window hosts have enough app-level identity to choose the runtime/content
for the new platform window. `WindowSceneResolver` is the matching shared
contract for resolving those scene requests into new `AppRuntime` instances or
explicit scene rejections before a platform backend allocates a native window.
`HostEventSource` in `runtime` is the subscription adapter for app-owned
host-event fanout: platform code can publish normalized `Event` values,
while apps map selected events back into typed `Program` messages through
`Subscription::host_event`; cancellation removes the publisher handler so late
host events do not re-enter stale app state.
`HostWindowEventSource` is the matching host-layer subscription adapter for
window-scoped platform events: platform code can publish a `WindowId` plus
normalized `Event`, while apps map those `HostWindowEvent` values through
`Subscription::window_event`; cancellation removes the publisher handler so late
window events do not re-enter stale app state.
`HostPlatformEventSources` bundles the host-event and window-event sources for
platform runtimes. Web, macOS, Windows, and Linux app options can carry that
bundle; after a raw platform event is normalized and dispatched through the
matching `HostRuntimeDriver`, the backend publishes the same `Event` with
its `WindowId` so app-owned `Subscription::host_event` and
`Subscription::window_event` adapters can observe real runtime events without
moving platform event conversion into `core`.
`@services.TimerSource` and `@services.RouteSource` are the app-facing
subscription adapters. Platform schedulers and history/deep-link integrations
adapt into those sources at the composition edge; cancellation runs their
cleanup and stale callbacks cannot re-enter the Program. `backend` does not
export a second app-facing timer or route model.
`backend/common.resolve_open_request` pairs a successful scene resolution
with the created registry record so the host can keep window id, scene metadata,
and runtime together. `WindowRuntimeSlot` then wraps that record with a
`HostRuntimeDriver`, giving future multi-window hosts a shared per-window
runtime/driver shape before platform-specific window and renderer handles are
attached. `WindowRuntimeSlots` is the matching collection for lookup,
primary/focused slot selection, record synchronization, and closed-window
cleanup, including shared helpers for inserting and syncing slots from
`WindowRegistry`, applying platform-neutral window requests, and applying
host lifecycle events while keeping the slot record aligned.
`PlatformWindowMap` binds platform window ids from `wzzc-dev/window` to
MoUI `WindowId` values so event dispatch can route through the host registry
instead of assuming one global window.
`HostWebViewCapabilities` is the capability contract for native platform
WebViews. The independent `moui_webview` addon owns `WebViewHost` and
`WebViewController`; hosts sync `DrawFrame.platform_views` to concrete WebView
objects, validate and dispatch `WebViewEvent` values, and drain controller tasks
at the platform edge. Browser Web wasm reports unavailable instead of creating
an iframe overlay. On macOS, the WKWebView host also consumes
`DrawFrame.overlay_bounds`: for a full-surface WebView it keeps the active
transparent Skia presenter above the WebView and excludes that sibling region
from WebView hit testing, so
already-rendered MoUI dialogs, sheets, and popovers remain visible and
interactive while the page stays visible underneath. Ordinary full-surface
platform-view frames clear transparently and pass presenter hit testing through
to WKWebView, so modal transitions do not reattach the WebView's remote layer.
This is currently macOS-only;
Web, Windows, and Linux do not expose MoUI overlays over native platform
views. The macOS WebView reserves a fixed 32-point top drag region. Blank
space there starts native window dragging, while interactive DOM controls and
elements marked `data-moui-no-drag` report no-drag rectangles and keep normal
WebView clicks.
Web, macOS, Windows, and Linux should convert their native window events into
`Event` and then let `AppRuntime` update state, rebuild, and emit
`DrawCommand` values.
The active Web, macOS, Windows, and Linux hosts all open a primary
`WindowRecord`, register the existing runtime/driver as a primary
`WindowRuntimeSlot`, bind the platform window id to the host id, route
incoming platform window events through that mapping, apply resize/focus/close
`Event` values through the registry, sync slot records after lifecycle
changes, and remove slot, platform binding, and record when a host window is
disposed. That makes multi-window lifecycle state a shared host concern instead
of a future platform-specific rewrite. Platform entries also accept a shared
`WindowRequestQueue` through `AppBuilder::window_requests` and drain
focus, close, resize, minimize, show, and set-primary requests at the platform
edge. The same queue records ordered request completions, making accepted
operations and explicit rejections observable. Active backends use the shared
queue drain helper so completion recording stays a host contract instead of a
platform-local loop.
`WindowCommands` is the higher-level command facade over the same queue for
app-facing open/focus/resize/minimize/show/close helpers and shared draining
into a registry or window runtime slots.
Every application entrypoint calls `@runtime.run_app`, supplies ordered
`RendererProvider` values, supplies one platform `entry`, and calls
`run`. Renderer-specific options and native-handle policy are captured by
renderer providers; platform-
specific options are captured by the platform entry. With a resolver, `OpenWindow`
requests resolve a scene into a new `AppRuntime`, create another platform
window, create an opaque `HostSurface`, bind the first accepting provider to a
`RendererSession`, register a per-window
`HostRuntimeDriver`, bind the platform id, and then route redraw, events,
context menus, service completions, IME sync, and disposal through
window-indexed slots. Without a resolver, hosts reject `OpenWindow` with the
shared unavailable-resolver message.

`RendererSession` is the renderer-neutral live handle used by native host
cores. Its stable constructor core contains resize, frame rendering,
present-completion drain, text-system access, present-count diagnostics, and
disposal. Image decoding, resource status, cache, and retained-layer residency
belong exclusively to the session. Host cores depend on `core`,
`runtime`, `backend`, the neutral `render` contract, and the platform
`window` package. They do not import `moui_wgpu_renderer`, `moui_skia_renderer`, `wgpu_mbt`,
`moui_skia`, or another concrete renderer. Platform backends own native window
handles, neutral CPU presenters, opaque native surface/display handles, and
lifecycle/I/O callbacks.
`render/common` owns provider negotiation and shared algorithms; renderer
modules own decode, native bindings, platform route policy, and renderer
diagnostics. Rejection leaves no persistent resources; a bound session is the
sole owner of accepted renderer/native-surface resources and disposes them
idempotently.

Renderer image work is event-driven. A session emits an opaque
`RendererImageLoadRequest` with a source and token through `RendererEvent`.
`backend/common/image` stores only cancellable I/O tasks, reads bytes from
`HostImageSource`, and sends an `ImageResourceLoadCompletion` with the same
token back to `RendererSession::apply_image_load_completion`. The session
returns whether the completion was applied; stale, duplicate, or disposed
tokens are inert and only an applied change requests redraw. Platform backends
never store renderer resource status or revisions. Each renderer provider
supplies a `RendererImageDecoder` that owns format detection, decode, and
resource cache updates. The host source and scheduler do not decode images,
mutate renderer caches, or live in `core`.

`RendererDescriptor` and `RendererSelection` remain renderer facade reporting tools:
they describe static capability identity and matching, not native host runtime
assembly. `View` still describes UI declaration trees only, and
`ControlledValue[T, Msg]` is the immutable TEA/control value bridge; it has no
setter path into an application model.

## Shell Embedding Bridge

`moui/backend` is the only owner of the neutral `HostServiceRequest`,
`HostServiceResponse`, `HostServiceCapabilities`, `HostServiceBridge`, request-id,
and completion contracts. The internal implementations are deliberately
asymmetric where the hosts are asymmetric:

- `backend/common/services/desktop` owns the synchronous desktop router. macOS, Windows,
  and Linux provide native clipboard, URL, dialog, menu, and settings closures;
  the package routes shared text/binary file and directory implementations from
  `backend/common/services/native`.
- `backend/common/services/native` owns native `@fs` service I/O shared by
  desktop and embedded backends. `backend/common/image/native` owns the
  renderer-neutral raw-byte `HostImageSource`.
- `backend/common/services/embedded` owns the callback queue. Clipboard and platform
  channel requests return `Pending(id)` in FIFO order, complete at most once,
  reject duplicate/late responses, and are cancelled during dispose. Other
  desktop-only requests return `Unavailable` synchronously.

`EmbeddedRuntimeHostBridge` is the private Android/iOS/HarmonyOS runtime
aggregation boundary and composes `backend/common/services/embedded`. It
coalesces `EmbeddedImeRequest` updates, transports runtime-owned full/delta
semantics commits with `SemanticsNodeId` and `SemanticsGeneration`, synchronizes
platform-view placements/events, and maps pending service requests to the
unchanged native wire schema. Its cursor suppresses unchanged transport without
becoming a second revision authority. A disposed bridge cancels outstanding
services and rejects late responses.

## Window Host Owners

Platform backends hold narrow owners directly instead of delegating all state
to an aggregate coordinator:

- `common/lifecycle` owns records, runtime slots, requests, platform-window
  maps, logical phase/surface generation, re-entry blocking, exit intent, and
  exactly-once close;
- `common/frame` owns each live `RendererSession`, pending/present completion,
  redraw/resize, and IME frame hooks;
- `common/image` owns cancellable loader tasks, tokenized completion delivery,
  callback detach, and cancellation. It does not store renderer resource
  status, cache residency, repaint revisions, or a backend repaint tracker;
- `common/input` owns neutral conversion and pointer/text/IME session state;
- `common/services` owns the service facade, async completion, and bridge
  lifetime.

Platforms contribute `WindowSurfaceActions` for native operations. Root
`backend/common` exposes stateless workflows that take the relevant owners and
actions explicitly; it retains no window state and is not another aggregate
coordinator. Close order is fixed: block lifecycle re-entry; detach image
callbacks and cancel work; close embedded and service channels; dispose the
renderer session; dispose platform views/native host resources; clear
mappings/runtime/registry; finish close.

Embedded-runtime backends share `moui/backend/common/embedded`
(`HostedWindowBackend`, `HostedWindow` projection closures, `HostedRuntimeSession`).
Android/iOS/HarmonyOS `window_hosted.mbt` are thin shells (platform window
creation, surface handles, six `ApplicationHandler` slots, host simulation
pump, IME sink injection) around that shared shell. Their `HostCmd` values are
decoded by the stateless `wzzc-dev/window/internal/embedded_dispatch` adapter.
`common/lifecycle::EmbeddedLifecycle` uniquely owns logical phase, surface
generation, primary-window routing, detach, and exit intent. `EmbeddedSession`
composes it with frame/image/input/services owners plus renderer, IME,
semantics, platform-view, and transport capabilities; it does not own another
phase or frame loop. Web stores the narrow owners directly and uses the same
stateless workflows; browser DOM routing stays in `moui/backend/web`.

`TextInputEvent::ReplaceText` and `SetSelection` preserve arbitrary native IME
replacement and UTF-16 selection updates. Mobile requests include text,
selection, composition, caret, and candidate rectangle without changing the
desktop `window_core.ImeRequest` contract.

Accessibility actions enter through
`AppRuntime::perform_semantics_action(PerformSemanticsActionRequest)`. Requests
carry a `SemanticsNodeId`, typed `SemanticsAction`, and exact runtime generation.
The runtime owns stale-generation, removed-node, enabled, capability, and
handler validation. Host adapters only transport the request and receipt; they
must not repeat validation or convert an action back into screen-coordinate
input. Web semantics-only commits are synchronized independently of redraw.

Typed wire services live on the same boundary. `HostServiceBridge` exposes
capability-checked dispatch for clipboard, file dialogs, menus, open-URL, and
system-theme requests. The app-facing `@services.PlatformServices` facade adds
neutral contracts for notifications, tray items, permission prompts, sharing,
printing, protocol/file associations, window-state persistence, and an
optional foreground/background lifecycle source. These operations use the
`PlatformChannel` extension point (`channel="moui.platform"`) so concrete
platform backends can add native behavior without importing platform types into
the app package. Backends can report unavailable services without
pretending that app code can call platform APIs directly.
`HostCapabilitySummary` folds those service flags together with input,
window-lifecycle, text-input, IME, drag/drop, async-service, and native
accessibility readiness. It is a high-level reporting API for apps, diagnostics,
and Showcase. Its `preflight_fields()` helper emits a renderer-neutral ready/gap
field string for provider/package audits such as native Skia preflight logs;
`HostServiceBridge`, `HostInputContract`, and platform backend setup remain the
source of truth for actual behavior.
Apps do not consume this bridge. `@backend_common.app_services(...)` adapts it to
`@services.AppServices`, and `@backend_common.app_environment(...)` combines those
services with optional `@services.TimerSource` and `@services.RouteSource`.
`PlatformServices::unavailable()` is the default, so a host must opt into each
new operation and may return an explicit `ServiceError::unavailable` when the
matching OS capability or permission is absent. `AppLifecycleSource` follows
the same subscription ownership and cancellation rules as route sources.
Platform backends expose `app_environment()` to composition roots; Program
closures capture the environment without placing it in business `Model` data.
Services that cannot finish synchronously, especially browser clipboard reads
and file dialogs that need a permission or picker callback, can return
`HostServiceResponse::Pending` through `@backend_common.ServiceAsyncQueue`. The host drains
pending requests into an in-flight set at the platform edge, completes them with
the original request attached, and records the completion. Runtime-owned
effects such as async paste are handed to `HostRuntimeDriver`. The host adapter
converts app-owned operations to `ServiceTask[T]`; apps receive
`ServiceTaskResult::Success`, `Failure`, or `Cancelled` through their typed
message loop. Request ids are protocol values; queue handlers stay in
`backend/common`, and
stale task dispatch is rejected by the runtime task lifecycle.
The Web backend wires that queue to browser host imports and exported wasm
completion callbacks for clipboard reads and file pickers.
Web, macOS, and Windows entrypoints query that bridge at startup and install
the reported light/dark scheme into `AppRuntime` before the first host driver
layout/redraw pass, so initial view builds see the platform color scheme through
`ViewEnvironment` reads during the initial Program view build.
`ThemeChanged` window events are also normalized into `Event::ThemeChanged`;
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
Application menus (L2) use `@services.MenuServices::install_application` with
`ApplicationMenu` descriptors derived from the same typed Program command
declarations. `ApplicationMenuPlacement::MenuBar` is the default and creates a
top-level menu. `ApplicationMenu::application(items=...)` selects
`ApplicationMenuPlacement::ApplicationMenu`; on macOS those commands are
inserted into the standard application menu after About and before Services,
without replacing Services, Hide, or Quit. macOS owns the AppKit target/action
bridge and retains the installed MoonBit callback until the menu is replaced.
Windows, Linux, and Web currently return `Unavailable`. Selection delivery for
top-level menus still uses the platform action handler installed by the
entrypoint (for example `@window_macos.set_system_menu_action_handler`). See
[Non-render cookbook](non-render-component-cookbook.md) and
Showcase's Platform workspace (`examples/showcase/app/platform`).
App-facing multi-window lifecycle requests go through `WindowActions`
(`open`, `close`, `focus`, `set_primary`, `resize`, `minimize`, `show`) on the
shared `WindowRequestQueue`. Each resolved scene remains an independent
`AppRuntime`; shared state is app-owned. See `examples/multi_window`.
File drop targets use the `View::on_file_drop` modifier; hosts normalize native
file drag/drop positions and paths before the runtime dispatches typed messages
to the hit view. `views.drop_zone` and `views.file_import_panel` are view-level
workflow shells over that modifier; their browse action remains an app message,
so effect-capable app code can call `AppServices::files().open_file(...)` and
return its typed `ServiceTask::effect`. Web file import may
expose browser-selected file names or handles rather than native filesystem
paths, while native hosts can return platform paths through the same selection
array.

See [Platform notes](platform-notes.md) for setup, backend-specific constraints,
and validation commands.
