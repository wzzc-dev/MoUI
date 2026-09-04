# TEA Program Model

> This document describes the TEA model for MoUI applications (`View`, `Program`, `Effect`, and `Subscription`).
> For an overview, see [Architecture](architecture.md).

**App-author recipes** (timer, clipboard, file open, window resize, shortcuts)
live in [Non-render component cookbook](non-render-component-cookbook.md) and
the runnable Showcase Platform package. This page is the lifecycle and
semantics reference, not a copy-paste cookbook.

MoUI app code builds UI with opaque `@moui.View[Msg]` values. The standard
shape is a typed TEA loop: `view : Model -> View[Msg]`, events carry typed
messages, `update` handles those messages, and explicit `Effect[Msg]` values
model follow-up work. App-level `Subscription[Msg]` values declare ongoing
event sources that should be started, reused by key, or canceled as the model
changes. Views that need viewport or platform inputs use
`view : (Model, ViewEnvironment) -> View[Msg]` through
`Program::simple_with_environment` or `Program::new_with_environment`. User code
does not call `lower`, `to_spec`, `ViewSpec`, or `ViewLoweringSink`; those names
are historical guardrail names, not supported app or control APIs.

`views/` is a facade over concrete custom view controls and higher-level compositions:

```moonbit
enum CounterMsg { Inc; Dec }

fn view(count : Int) -> @moui.View[CounterMsg] {
  @views.column([
    @views.text("Count: \{count}"),
    @views.row([
      @views.button("-", on_click=Dec),
      @views.button("+", on_click=Inc),
    ], spacing=8.0),
  ], spacing=12.0)
}
```

Function components are ordinary functions returning `View[Msg]`. Child
messages are lifted with `View::map`, for example
`todo_row(todo).map(TodoRowMsg)`. Child updates that return follow-up work lift
their effects with `Effect::map`, so a parent update can preserve typed child
message composition and structured effect descriptors without exposing runtime
dispatch. Ordinary controls are TEA-first controlled views: app code passes the
current value plus `on_input`,
`on_change`, or `on_select`, then updates the model from the emitted message.
Controls that require complex local state, such as rich text editing or
virtualized resources, keep it in typed runtime slots owned by the control.
They receive controlled values and emit typed messages; they do not receive a
setter or a mutable application-state holder.

Runtime-owned, node-scoped state remains compatible with TEA because it is not
application model state. Hover, focus, pressed state, caret/selection, and
scroll position may live in a transient runtime slot tied to one reconciled
element lifetime. Semantic actions can update that transient state and enqueue
typed messages, but only the application's `update` function changes the app
model. Rebuilds re-declare the view from the resulting model; unmounting drops
the runtime slot.

Agent actions follow the same loop. Runtime commits the current semantics,
validates a generation-tagged typed action, applies transient UI state, delivers
typed messages FIFO, drains synchronous TEA work, and commits again. It never
manufactures pointer or keyboard events for semantic activation. See
[Committed Semantics And Agent Actions](agent-semantics.md).

Custom-control entrypoints are app-facing in `moui/views`. App code,
host tests, smoke checks, and example apps should use helpers such as
`@views.text_field`, `@views.checkbox`, `@views.picker`, and
`@moui_richtext.markdown_editor` (rich text lives in the `moui_richtext`
addon, not `moui/views`). Concrete built-in control implementations should live
in `moui/views`, implement the message-independent `@core.ViewNode` trait, and
attach typed children/events/text commands with `@core.View::from_node(...)`.
They should not add `@core.View::primitive_*_view` constructors or runtime
lowering table entries.

Shared app packages should use `Program::simple` factories and let platform
entrypoints create `AppRuntime` values through `moui/runtime`. Effect-capable
apps should use `Program::new` when
`update` returns follow-up work: `Effect::send` re-enters the typed message loop
directly, and `Effect::dispatch` gives an effect runner the typed message
dispatcher for app-owned host-service bridges or other callbacks without making
`core` platform-specific. `Effect::run` is the structured form for ordinary
one-shot runners that should appear in diagnostics; it adds a stable key, kind,
and label while leaving concrete async execution outside `core`.
`moui/services.ServiceTask::effect` is the app-facing helper for files,
clipboard, URLs, settings, appearance, and menus. It turns typed success,
failure, and cancellation into `Msg` without exposing host request ids, bridge
objects, or completion queues. `Effect::task` starts a one-shot
cancellable task from an effect update, and `Effect::service_task` is the
standard helper for service-like one-shot tasks that need the same runtime-owned
cancellation lifecycle plus a stable `service` descriptor kind: the runtime
records an active task descriptor, completes it on the first typed dispatch,
cancels an older active task when a new task with the same key starts, cancels
active tasks when the runtime is destroyed, and ignores stale task dispatches
after completion or cancellation. Same-key task replacements that change the
descriptor kind are recorded with `EffectTaskKindChanged`, so tooling can
distinguish a service-like task being swapped for another task category from an
ordinary same-kind restart.

Supersession itself stays silent (last writer wins), but reusing one key for a
different descriptor is an accident worth catching: when the live task's `kind`
or `label` differs from the incoming one, the runtime records one entry per
distinct collision shape in the program diagnostics snapshot
(`superseded_effect_task_key_count` / `superseded_effect_task_keys`), exposed on
`AppRuntime::program_runtime_snapshot` and the inspector snapshot. Treat an
effect key as a namespaced identity rather than a display label: prefix it with
the owning module and purpose (for example `import.raster.page-3` or
`settings.load.theme`), never share one key across different kinds or labels,
and keep key, kind, and label identical when intentionally restarting the same
operation so the restart stays a plain last-writer replacement without a
collision record.
`@runtime.effect_plan_summary` exposes the runtime-owned diagnostic summary of
the effect tree, including batch, send, anonymous dispatch, structured run,
task, none, scheduled leaf count, max depth, structured effect descriptors, and
duplicate descriptor-key counts/names, without running effect callbacks.
Program runtime snapshots also report message queue enqueue, drain, pending,
max-pending, and ignored program-dispatch counters without requiring `Msg`
values to be serializable. Each program-message drain is bounded as a runtime
turn: messages synchronously queued by clicks, `Effect::send` /
`Effect::dispatch`, structured runners, effect tasks, or subscriptions keep
their FIFO order, but work beyond the per-turn bound remains pending for the
next host/runtime entry instead of keeping the current call stack alive
forever. Dispatch closures captured by anonymous
`Effect::dispatch` or structured `Effect::run` callbacks are ignored after
`AppRuntime::destroy()` so late app-owned callbacks cannot re-enter a destroyed
program runtime.
`Program` constructors also accept
`subscriptions=model => ...`; each `Subscription::listen` / `Subscription::run`
uses a stable key, receives the typed dispatcher, and may return a cleanup
callback. `Subscription::timer`, `Subscription::animation_tick`,
`Subscription::window_event`, `Subscription::host_event`, and
`Subscription::route_event` standardize descriptor kinds for common ongoing
source categories without starting any concrete platform work in `core`.
`@runtime.subscription_plan_summary` exposes the declared none, batch,
source, duplicate-key counts/names, max-depth, and declared source descriptor
structure without starting sources. Existing keys are reused across model changes only
when their descriptor kind still matches, missing keys are canceled, and a
source that keeps the same key but changes kind is restarted with a
`SubscriptionKindChanged` lifecycle reason so an app cannot silently keep an old
timer, host-event, or service adapter running under a reused key. Duplicate keys
in one subscription batch are ignored after the first and reported in runtime
diagnostics, and `Subscription::map` preserves child feature message and
descriptor identity while lifting messages to a parent type. Dispatchers
captured by canceled or destroyed subscriptions are ignored, so stale callbacks
cannot re-enter the model loop after their subscription lifetime ends; program
runtime and inspector snapshots count those ignored subscription dispatches
separately from normal typed dispatch/update counters and expose planned
subscription descriptors, active subscription descriptors, active subscription
kind-count summaries, and lifecycle entries for tooling. Concrete timer,
window, host-event, route, or host-service adapters remain outside `core`; the
core subscription runtime only owns the platform-neutral lifecycle,
subscription plan diagnostics, and typed dispatch contract. `backend`
provides the integration-only `HostEventSource` fanout adapter for
`Subscription::host_event`, `HostWindowEventSource` for
`Subscription::window_event`; `@services.TimerSource` and
`@services.RouteSource` are the app-facing adapters for timer ticks and route
events. Browser
history, native URL bars, and OS deep-link dispatch remain platform/app-layer
follow-up work.
`Program::with_commands` declares typed `ProgramCommand[Msg]` values alongside
the Program. Runtime keeps the current command map synchronized with the model;
keyboard shortcuts, native application menus, and context-menu selections all
enqueue the declared `Msg` in FIFO order and pass through the same `update`.
Apps must not install command closures that mutate model state outside TEA.
Environment-aware TEA apps should use
the `*_with_environment` constructors instead of taking `ComponentContext` in their
view layer. In both cases event dispatch flows through typed messages instead of
exposing the runtime tree.
