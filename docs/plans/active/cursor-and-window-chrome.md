# Cursor Style API and Window Chrome Controls

- **Status**: active
- **Slices**: `#25` cursor style API (first), `#24` window chrome controls (second)
- **Issue links**: `wzzc-dev/MoUI#25`, `wzzc-dev/MoUI#24`
- **Owner surface**: `moui/core` (declaration + view protocol), `moui/runtime`
  (hit-chain resolution), `moui/backend` + `moui/backend/common` (host
  contracts and sync workflows), `moui/backend/{macos,windows,linux,web}`
  (native projection), `moui/services` (app-facing chrome requests/capabilities)
- **Compatibility**: additive. New enums/requests/actions only; every host that
  cannot honor a request keeps a documented no-op, and every platform backend
  that is not wired today keeps the previous behaviour until it is.

## Shared decision: window state vs. surface actions

Both issues ask the same question — *where does a per-window presentation fact
live?* — so it is decided once here and both slices follow it.

| Fact | Owner | Reason |
|---|---|---|
| Cursor style currently in effect | **runtime** (resolved from the view tree), **concrete host** projects it | The declaration is per-element and per-frame; only the runtime knows the hit chain. A host literally cannot derive it. |
| "this surface last pushed cursor X" | `backend/common/lifecycle` per window | Exactly-once dispatch is a host workflow concern, not a view concern. |
| Maximize / restore / fullscreen / decorations *requested* | `WindowRequest` (`moui/backend`) | These are logical window-state transitions, queued like `MinimizeWindow`/`ShowWindow`, and they must survive before a surface exists. |
| Actual native call | `WindowSurfaceActions` closure | Surface projection stays in the platform backend (invariant P10); root/common never names a native API. |
| Window chrome ownership (native decorations vs. content-under-chrome vs. app-drawn) | **per window, chosen by the composition root**, reported to apps as capabilities | Apps must degrade honestly; only the host knows what it negotiated with the compositor. |
| "is this window maximized" | `WindowRecord` (observed state), updated by the host | A read that cannot be answered by the declaration alone; the host observes it. |

Rules that follow from the table:

1. A **view declaration never carries host state**. `.cursor(style)` declares
   intent only; the runtime resolves it against the current hit chain and the
   host pushes the result at most once per change.
2. **Surface actions take resolved values**, never `Inherit` or "please ask the
   view tree". `WindowSurfaceActions.set_cursor` receives a final
   `CursorStyle` whose only variants left are `Default` and `Icon`.
3. **Requests are window-lifecycle states**; actions are the projection. A
   request that has no active platform window is rejected by the existing
   `apply_platform_window_request` path instead of silently doing nothing.
4. **Capabilities are reported, not guessed**: no `supports_*()` probing on the
   view side, no per-platform branch in app code.

## Slice 1 — `#25` cursor style API

### Type placement

`CursorStyle` lives in `moui/core` because `View::cursor` must be declared on
`View` (core owns the modifier vtable). It is a three-state value plus a neutral
icon enum:

```moonbit
// moui/core/cursor.mbt
pub(all) enum CursorStyle { Inherit; Default; Icon(CursorIcon) }

pub(all) enum CursorIcon { CursorDefault; CursorContextMenu; ... }  // 34
```

The icon variants mirror the platform `wzzc-dev/window/core` `CursorIcon` set
one-to-one (`CursorColResize` ↔ `ColResize`), and `moui/backend/common/
window_cursor.mbt` owns the single upward mapping table. Two alternatives were
implemented and rejected during the change, with evidence:

1. **Re-export the upstream type** (`pub type CursorIcon = @window_core.CursorIcon`).
   This is the most faithful wrapping, but it (a) makes the cross-runtime
   contract layer depend on the platform window crate, (b) forces the interface
   generator to fully qualify every `@core` reference once `views` re-exports
   the alias (403 changed lines in `moui/views/pkg.generated.mbti`), and (c) the
   repo's `validate-api-surface.mjs` pins the app facades to `@core` aliases and
   the root facade to its 14-alias app-loop set, so the export is rejected
   outright. Verified by running the gate.
2. **Declare the upstream names bare** (`CursorIcon::Pointer`, `Move`, `Text`,
   …) in core. MoonBit constructors share one package-wide namespace, so bare
   `Pointer` collides with `AppEvent::Pointer` and broke existing
   `@core.Pointer(...)` call sites in `moui_richtext` on `moon check`. The
   `Cursor` prefix is the mechanical fix; the mapping table keeps the
   correspondence explicit.

Two states are deliberately non-negotiable:

- `Inherit` — without it a child inside a `col_resize` splitter cannot say
  "back to the arrow".
- `Default` — an explicit stop for inheritance, distinct from `Inherit`.

Icon identity is a closed enum, not a capability probe: unknown/unsupported
shapes degrade to the arrow at the host boundary, and hosts without cursor
support leave `set_cursor` a no-op.

### Resolution

- Declaration: `AnyModifier.pointer_cursor` (default `Inherit`) →
  `ModifierViewNode::pointer_cursor` → `View::pointer_cursor` →
  `RuntimeViewNode::pointer_cursor`. `ViewNode::pointer_cursor` is an optional
  trait method with an inert `Inherit` default, so no existing node changes.
- Runtime: a read-only hit-chain walk (`runtime/cursor_resolution.mbt`) that
  mirrors the pointer dispatch order (hoisted overlays first, topmost-first,
  clipped frames) and returns the deepest declared style; `Inherit` keeps
  walking to the ancestor. Nothing is dispatched on pointer move, so cursor
  resolution cannot dirty layout, paint, or semantics.
- While a press is active the **press origin** is used instead of the latest
  pointer sample, so a splitter drag that leaves the 8px gutter keeps
  `col_resize` without the framework inventing drag-time styles.
- `AppRuntime::pointer_cursor()` exposes the result. `AppRuntime` is already the
  single runtime surface the host pump talks to.

### Reset

Three resets are explicit, not emergent:

| Case | Mechanism |
|---|---|
| Pointer leaves the window | host emits `Exit` / the last position no longer hits a declaration → resolution is `Default` |
| Declaring view unmounts | resolution is recomputed from the live tree; `run_window_redraw` re-syncs it after a frame |
| Window loses focus | `dispatch_host_event` pushes `Default` on `Focus(false)` |

### Dispatch discipline

`backend/common/input` gains a `CursorSession` (the `TextInputSession` shape:
remember last applied style, return `Some(style)` only on change).
`backend/common` gains `sync_pointer_cursor(lifecycle, input, id)`, called from
`dispatch_host_event` and after a redraw. A pointer stream that stays inside one
declaration performs exactly zero native calls.

### Platform projection

| Host | Projection |
|---|---|
| macOS / Linux / Windows | `Window::set_cursor_icon` |
| Web | `Window::set_cursor_icon` (canvas CSS cursor) |
| Embedded / terminal / agent | no `set_cursor` implementation requirement; hosts that do not wire it keep a no-op |

No capability query is added: mainstream toolkits do not expose one, unsupported
hosts degrade to a no-op, and an unknown value degrades to `Default`.

### Non-goals in this slice

- Built-in controls do **not** set cursors by default (`opt-in`), so existing
  visuals and behaviour are unchanged. `Button`→`Pointer`,
  `text_input`→`Text` remain an explicit follow-up once the API has shipped.
- A framework cursor *overlay stack* (busy `wait`, invalid-drop `not-allowed`)
  is not added; the press-origin rule covers drag cursors, and apps declare
  busy/not-allowed on the hovered region. Recorded as a follow-up, not a claim.

## Slice 2 — `#24` window chrome controls

Landed in the same change (the two slices share `WindowSurfaceActions` and the
window-host workflows, so splitting them would have produced two PRs editing the
same structs in conflicting directions).

### Requests

`WindowRequest` gains four logical transitions, queued exactly like
`MinimizeWindow`/`ShowWindow`:

```moonbit
MaximizeWindow(WindowId)
RestoreWindow(WindowId)              // clears maximized *and* fullscreen
SetFullscreenWindow(WindowId, Bool)
SetDecorationsWindow(WindowId, Bool)
```

`WindowRequestQueue` and `WindowCommands` gain matching helpers, so hosts and
in-repo integrations do not hand-assemble variants.

### Observed state

`WindowRecord` gains `maximized` / `fullscreen`. They are separate fields rather
than more `WindowLifecyclePhase` variants: "focused + maximized" is a real
combination and does not fit a single enum. The registry applies the transitions
(`RestoreWindow` clears both; entering fullscreen clears `maximized` because a
fullscreen window is not a maximized one for chrome purposes) and rejects them
for closed windows through the existing `apply_platform_window_request` path.

### Surface projection

`WindowSurfaceActions` gains `set_maximized`, `set_fullscreen`,
`set_decorations`. macOS / Windows / Linux map them onto
`Window::{set_maximized,set_fullscreen,set_decorations}`; Web maps fullscreen to
the browser Element Fullscreen API and leaves the other two as upstream no-ops.

### App-facing controls and honest degradation

`moui/services` gains `WindowControlSource`:

- capabilities (`minimize` / `maximize` / `fullscreen` / `decorations`), set by
  the host, never probed by the view layer;
- observed `maximized` / `fullscreen` plus a revision counter chrome can compare;
- `maximize()` / `restore()` / `toggle_fullscreen()` / `set_fullscreen()` /
  `set_decorations()` intents, **dropped at the source when the capability is
  `false`** — a host that cannot do the operation never accumulates a queue
  nobody drains;
- `drain()` for the host, gated on being hosted at all.

Host side: `backend/common` gains `apply_window_control_requests` /
`sync_window_controls`, called from each desktop backend's existing
`drain_window_requests` tick. Backends publish their capability set each tick
(deduped by the source), so a window that appears after the first tick still gets
reported. Web reports `fullscreen: true`, `minimize/maximize/decorations: false`.

Composition roots opt in by passing `window_controls=services.platform().window_controls()`
into their host options; it defaults to `None`, which keeps every intent a no-op.

### Linux client-side decorations

The real regression: the painted close/minimize/maximize dots had their pointer
and scroll input silently dropped.

- `linux_titlebar_button_slot_rect` is the single geometry source for both paint
  and hit testing (28pt clickable slot, 12pt dot), so they cannot drift.
- `linux_titlebar_pointer_action` classifies a pointer event:
  `Press` on a button slot → `Activate` on release in the same slot → a
  `CloseWindow` / `MinimizeWindow` / maximize-or-restore request;
  `Down` on the titlebar body → native `drag_window()`;
  scroll and moves over the band are consumed; below the band and inactive-CSD
  states pass through rebased.
- Secondary-button presses are consumed but never start a drag.

### Not in this change

- Double-click-titlebar zoom: the CSD band now has a drag/activate state machine
  but no click timing (the normalized `Event` carries no timestamp), so a
  correct double-click needs a clock input first. The capability + request path
  it needs exists now.
- macOS secondary-window chrome policy and the measured immersive-chrome
  constants (traffic-light inset) stay as the issue describes them.
- Matching-host Wayland CSD smoke: this sandbox has no compositor, so the
  behaviour is unit-tested (`linux_titlebar_test.mbt`) and the runtime claim is
  "implemented, needs matching-host smoke".

## Testing plan

- `moui/core`: modifier unit tests (transparent, no semantics, no focus stop,
  `Inherit` vs `Default` identity, member access).
- `moui/runtime`: hit-chain resolution tests — child overrides ancestor,
  `Inherit` falls back, `Default` stops inheritance, press-origin stickiness,
  reset to `Default` after leave/unmount.
- `moui/backend/common`: exactly-once push (no repeat while unchanged, one push
  per change), focus-loss reset, redraw re-sync.
- Platform backends: compile-level coverage plus the shared workflow tests;
  matching-host pixel/cursor proof stays manual smoke (recorded in the PR, not
  claimed as CI evidence).
- Gates: `moon check` / `moon test --target native` for every touched package,
  the `pr` profile validators from `AGENTS.md`, `moon info` interface refresh.

## Risks

- The neutral icon set duplicates the upstream variant list; drift is contained
  to one mapping table and surfaces as a missing arm (compile error), not as a
  silent wrong cursor.
- Cursor resolution walks the tree on pointer move; it is read-only and O(depth),
  the same order as the existing focus picker. If profiling ever shows it, it can
  be memoized on the last pointer position.
- Linux CSD input has no matching-host Wayland evidence in this change; the
  behaviour is unit-tested and the runtime claim stays "implemented, needs
  matching-host smoke".
