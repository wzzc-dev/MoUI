# Nested scroll release routing

- **Code**: `moui/runtime/input_pointer.mbt`
  (`dispatch_pointer_to_target_with_scroll_ancestor`),
  `moui/views/controls/scroll_view_layout.mbt`.
- **Plan**: `docs/plans/active/pointer-input-parity.md` (§3 follow-up,
  2026-10-24).

## Standing facts

- A pointer capture routes `Up`/`Cancel` to the pressed control; the unwind
  delivers the release to ancestors. Captured `Move` is deduplicated to the
  **first** scroll-view ancestor (two live scrollers must not recognize one
  gesture), but a **release bypasses that dedup**: every scroll-view ancestor
  that armed on the `Down` must see the matching `Up`/`Cancel`, or it keeps a
  stale `drag.active`.
- The scroll drag `Move` path does not check whether a button is still pressed
  (that state is not carried on `Move` events — DOM reports `button: 0` for
  hover and drag alike). The invariant "armed ⇒ between `Down` and its
  release" is what keeps mouse hover from scrolling, so the release side of
  that invariant is load-bearing, not optional.
- The scroll drag slop is measured from the `Down` position, so a stale-armed
  container starts scrolling after ~4px of ordinary hover movement.

## Why

The symptom looked app-specific (new_world settings page scrolled under the
pointer after clicking a world entry) but was two independent defects: the
release-routing gap above, and a row budget overflow (`wide - 104 + gap + 104 =
wide + 8`) that became real horizontal drag range. Framework rule: when a press
starts inside nested scrollable ancestors, every one of them arms; the release
must disarm all of them. App rule (see `memories/repo/scroll-axis-range.md`):
a `row`'s fixed child widths plus its spacing must fit the scroll viewport, or
the overflow turns into drag range.

## How to apply

Regression tests: `moui/runtime/nested_scroll_release_test.mbt` (click on an
inner control, then button-less hover; drag from an inner control routes to
the inner scroller only) and the layout probe
`examples/new_world/app/layout_probe_test.mbt` ("设置页内容不横向溢出滚动视口",
asserts no frame width lands strictly between the content budget and the card
width).
