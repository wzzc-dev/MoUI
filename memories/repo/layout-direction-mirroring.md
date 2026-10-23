# Layout direction and mirroring

- **Plan**: `docs/plans/active/pointer-input-parity.md` (§9, landed 2026-10-23).

## Standing facts

- `Environment.layout_direction` (`moui/core/theme.mbt`) is the single source.
  Every `fn layout(self, ctx)` / `fn event(self, ctx)` already receives it on
  `ctx.environment`; nothing may take a direction parameter from a caller or
  cache-key on a second copy. The `layout_direction~` parameter
  `moui/runtime/layout.mbt` used to accept was inert and is deleted — do not
  reintroduce it.
- The reflection formula exists once: `Rect::mirrored_x(x~, width~, direction~)`
  (absolute-x point reflection about the frame's vertical centre) and
  `Insets::mirrored(direction)` (leading = `right` under RTL). `moui/views/*`
  subpackages cannot import each other, and `moui/core` needs the same math for
  alignment and guides, so a views-side helper always leaves a second copy —
  that is why canonical helpers live in core, not in `moui/views/common`.
- `CustomPlacementContext::mirror_x` is the delegate-facing spelling of
  `Rect::mirrored_x` and is the only way a `custom_children_layout` delegate can
  mirror (delegates never see a `ViewLayoutContext`). It is load-bearing: the
  framework's own baseline-form and responsive-grid delegates place through it.
- `Alignment.x` and `AlignmentGuideSet.leading`/`trailing` are **different kinds
  of names**. `Alignment.x` is a visual −1..1 axis, so RTL negates it; the guide
  set reports reading-order positions, so RTL swaps them to
  `size.width`/`0.0`. Do not unify them.
- Scroll `offset.x` is a **leading-edge distance**: `0` is flush with the
  reading edge, which is the left in LTR and the right in RTL.
  `scroll_clamp_offset` is therefore direction-free. Event vectors (wheel
  delta, finger travel) stay physical forever — a swipe right always moves
  content right — and `scroll_leading_x_delta` is the only place a physical
  vector is converted into a leading-distance change. Anything that dispatches
  physical wheel deltas (`moui/runtime/scroll_to_key.mbt`) needs no RTL work.
- Popup placement cannot default its direction: `PresentationPlacement::resolve`
  takes a **required** `direction~`, and `OverlayPlacementContext` carries
  `layout_direction` because overlays escape the base layout pass. A silent
  `LeftToRight` default compiles fine and lands RTL popups on the wrong side, so
  the label stays required.
- **Text runs are not mirrored.** `@core.TextLayoutInput` carries no direction,
  so `TextSystem` measurement always returns LTR-ordered glyph and caret
  offsets. Mirroring block x while offsets stay LTR puts the caret and the
  selection highlight on the wrong side of the glyphs, so `moui/views/text`
  placement must not read `layout_direction` until a direction-carrying
  `TextSystem` slice exists.
- Mirroring is verified as LTR/RTL **pairs**, never as single expected numbers:
  the same extents survive, the order reverses, and the untouched axis does not
  move. `moui/views/layout` had zero test files before §9; its
  `layout_direction_wbtest.mbt` is the baseline to extend.
