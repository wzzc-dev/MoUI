# 0070: Control popups are presentation surfaces, not layout children

- **Date**: 2026-11-12
- **Status**: Accepted
- **Deciders**: wzzc-dev (agent-assisted control architecture review)
- **Related**: ADR 0069, ADR 0033 (overlay/dismissal), plan
  `macos-frame-pacing-and-transient-scroll`, `moui/views/presentation`

## Context

The picker and date picker modeled their popup as a real child of the trigger
node and positioned it with `place_overlays`. Open/close therefore changed the
parent's child frames, and a close branch that reported `ViewPaintDirty` left
the expanded placed tree in the place cache; the popup could stay painted and
the next open could look inert. This is the same failure class mature toolkits
avoid by keeping popups outside the parent layout: Qt's `QComboBox` popup is a
top-level window, Flutter's `showMenu` pushes an overlay route, SwiftUI uses a
presentation binding, and HTML popovers live in the top layer.

## Decision

Control popups use `popup_host` + `PresentationSpec`:

- the trigger is the host's base view and owns no popup child;
- the popup is a presentation surface anchored to `HostBase`, with placement,
  enter/exit lifecycle, outside-tap and Escape dismissal, and the top-most
  dismissal layer owned by the presentation host;
- open state is app-owned (`expanded` + `on_expanded_change`), because the
  presentation declaration is built at view-build time; this is the SwiftUI
  binding model and costs one rebuild per open/close, not per tick;
- item selection returns both the selection message and the close message from
  the popup content;
- the trigger requires its own Down before an Up toggles, so the Up that follows
  an outside-tap dismissal cannot reopen the popup through the barrier.

## Consequences

- Opening/closing a picker or date picker no longer dirties the parent layout or
  its place cache; the layout-state popup bug cannot recur on this path.
- Outside tap, Escape/Back, focus behavior, and enter/exit ghosts come from the
  shared presentation stack instead of per-control code.
- `picker` and `datepicker` gained required `expanded` / `on_expanded_change`
  parameters; call sites own one boolean and one message.
- Popover presentation is non-modal: focus stays on the trigger rather than
  being trapped inside the popup, which is the combobox behavior users expect.
- A control popup that genuinely must participate in parent layout remains
  possible, but its open/close is layout state and must report
  `ViewLayoutDirty` (see `docs/custom-control-sdk.md`).
