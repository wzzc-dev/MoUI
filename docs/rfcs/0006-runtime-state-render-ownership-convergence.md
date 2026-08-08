# RFC 0006: Runtime Neutrality, State Ownership, and Render Resources

Status: Accepted (2026-08-07)

## Decision

MoUI makes `moui/runtime` platform-neutral. Runtime owns semantics trees,
layout, event dispatch, reconciliation, damage, and TEA execution. AccessKit
node/action/tree translation and bridge state move to
`moui/backend/accesskit`; concrete backends retain platform availability,
native binding, and diagnostic names.

Application state has one mutation/effect loop: `Program<Model, Msg>`,
`Effect<Msg>`, and `Subscription<Msg>`, evaluated with `ViewEnvironment`.
Element-owned interaction transients use typed `ViewStateSlot` contexts.
Generic app-facing mutable holders, component watch/effect/saveable lifecycle,
and arbitrary model setters are removed. Controlled controls receive immutable
values and produce typed messages. Uncontrolled scroll, caret, selection, IME,
hover, pressed, and drag state stay in runtime slots; observable scroll/focus
uses model values and monotonic immutable requests.

Renderer sessions uniquely own decoded images, GPU/CPU resources, retained
layer admission/residency/eviction, and render-resource diagnostics. Backend
frame state owns pending frame tokens and completion ordering. Backend image
state owns cancellable I/O tasks only. Runtime owns UI computation and damage,
but does not mirror renderer cache residency.

Each frame submission carries a surface-generation/sequence token. Renderer
events report present completions or tokenized image-load requests. The backend
loads bytes, returns the same opaque token, and requests redraw only when the
session reports an applied change. Stale and disposed completions are inert.

Retained layers always include a complete declaration and payload in the
current frame. A renderer may skip a hit or rebuild after eviction from that
same payload; no host command-cache fallback or residency mirror is required.

## Compatibility

This is an atomic, unpublished 0.2 breaking migration. The removed state,
component, image-loader/callback/revision, and cached-layer APIs receive no
deprecated aliases or wrappers. Repository consumers migrate in the same
change.

## Consequences

Runtime can be reused without AccessKit or platform vocabulary. Application
state transitions and effects have one traceable path while low-level controls
retain ergonomic local state with element lifetime. Frame/image teardown and
stale completion behavior become explicit, and renderer eviction cannot make a
frame unreconstructable.

RFC 0002's state guidance is narrowed to the Program Model. ADR 0015's public
component-state mechanism and ADR 0027's frame/image subcontracts are revised;
the two-level provider/session lifecycle remains unchanged. Release topology,
renderer classification, and platform readiness do not change.
