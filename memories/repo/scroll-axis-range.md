# Scroll axes and the rangeless-axis gate

- **Code**: `moui/views/controls/scroll_view_layout.mbt`,
  `moui/views/controls/scroll_view_motion.mbt`.
- **Plan**: `docs/plans/active/pointer-input-parity.md` (§3).

## Standing facts

- `scroll_container` is a two-axis pan surface. No API declares an axis: the
  authoritative offset is clamped per axis against `child.size - viewport.size`,
  and the drag path reads the raw pointer vector.
- Since 2026-10-24 the horizontal axis is gated by `scroll_axis_has_range`
  (`child.width > viewport.width`): travel along a rangeless axis neither
  accumulates into `raw_offset` nor pulls a band. The vertical axis stays
  ungated on purpose — a `scroll_view` is always declared as a vertical
  scroller, so its rebound is intended even when a short list has no range.
- Band extent is per axis from the **viewport** size
  (`max(24, min(120, axis * 0.25))`), so before the gate a 560px card offered
  120px of sideways rubber band with nothing overflowing.
- The slop test still reads the physical pointer, so a drag starting on a scroll
  surface cancels a child control on either axis. Gating an axis removes motion,
  not the gesture.
- A child that measures wider than its `scroll_view` width is a real defect, not
  only a clipped pixel: a flex `row` reports its children's total width, so the
  overflow becomes genuine scroll range that has to be dragged to reach.
  `section_header` is the recurring trap — an `action` needs a matching
  `action_width`.

## Why

Both failure classes look like "the widget moved when I did not ask it to", and
the fix is on the app side half the time. Measuring the laid-out tree (see
`examples/new_world/app/layout_probe_test.mbt`) distinguishes a band from a
range; the painted-shift assertion in `scroll_view_wbtest.mbt` pins the gate.

## How to apply

Before adding scroll behavior to a control, ask which axis the caller declared.
When a surface "can be dragged the wrong way", first check whether the content
overflows that axis at all — if it does not, only the band was moving.
