///|
/// Layout-side metadata for a single child of a custom children layout.
///
/// Replaces the previous parallel arrays (`child_sizes`, `child_baselines`,
/// `child_alignment_guides`) with a single, typed record per child. The
/// runtime fills this from the measured/placed child element, so custom
/// layouts no longer have to rely on guessed baseline values.
pub(all) struct ChildLayoutInfo {
  /// Measured size of the child after its own layout pass.
  size : Size
  /// First baseline of the child, relative to its top edge. `None` means the
  /// child does not expose a baseline; layout authors should fall back to a
  /// reasonable default (e.g. `size.height * 0.8`) rather than treating the
  /// child as baseline-less.
  first_baseline : Double?
  /// Alignment guides derived from the child size and baseline. Computed by
  /// the runtime so authors do not have to reconstruct them per child, and
  /// resolved in reading order: `leading` is the edge the text starts at, so
  /// it is the right edge under right-to-left layout.
  alignment_guides : AlignmentGuideSet
  /// Flex weight declared by the child. `0.0` means the child is not flex.
  flex_weight : Double
} derive(Eq, Debug)

///|
pub extend ChildLayoutInfo with Debug::{to_repr}

///|
pub extend ChildLayoutInfo with Eq::{not_equal, equal}

///|
/// Construct a `ChildLayoutInfo` from measured child data. The runtime uses
/// this when assembling `CustomLayoutContext.children`; downstream packages
/// use it when building tests for custom layout delegates.
pub fn ChildLayoutInfo::new(
  size~ : Size,
  first_baseline~ : Double? = None,
  flex_weight~ : Double = 0.0,
  direction~ : LayoutDirection = LeftToRight,
) -> ChildLayoutInfo {
  {
    size,
    first_baseline,
    flex_weight,
    alignment_guides: AlignmentGuideSet::from_size(
      size,
      first_baseline~,
      direction~,
    ),
  }
}

///|
/// Convenience accessor: the child's resolved baseline, falling back to the
/// historical `size.height * 0.8` estimate when the child does not expose one.
/// Keeping the fallback here lets custom layouts stop special-casing the
/// "no baseline" branch while still preserving prior behavior for children
/// that genuinely lack a baseline.
pub fn ChildLayoutInfo::baseline_or_estimate(self : ChildLayoutInfo) -> Double {
  self.first_baseline.unwrap_or(self.size.height * 0.8)
}

///|
pub(all) struct AlignmentGuideSet {
  leading : Double
  center : Double
  trailing : Double
  first_baseline : Double?
} derive(Eq, Debug, ToJson)

///|
pub extend AlignmentGuideSet with Debug::{to_repr}

///|
pub extend AlignmentGuideSet with Eq::{not_equal, equal}

///|
pub extend AlignmentGuideSet with ToJson::{to_json}

///|
/// Layout context for a custom children-layout delegate. The runtime measures
/// each child first, then hands the resulting `children` array (plus the
/// ambient environment, viewport and reading direction) to the delegate's
/// `measure` callback.
///
/// The previous API exposed `cache` / `cache_key` and several parallel arrays
/// (`child_sizes`, `child_baselines`, …). The cache was mutable state stored
/// on the immutable declaration node (a violation of `view_node.mbt`'s contract)
/// and the parallel arrays made it easy to read the wrong index. Both are gone
/// in favor of `children : Array[ChildLayoutInfo]`.
pub(all) struct CustomLayoutContext {
  constraints : Constraints
  children : Array[ChildLayoutInfo]
  layout_direction : LayoutDirection
  safe_area : Insets
  viewport : Size?
}

///|
/// Placement context handed to a custom children-layout delegate's `place`
/// callback. `children` mirrors the order of `CustomLayoutContext.children`;
/// the delegate returns one `Rect` per child in that same order.
pub(all) struct CustomPlacementContext {
  frame : Rect
  measured_size : Size
  children : Array[ChildLayoutInfo]
  layout_direction : LayoutDirection
  safe_area : Insets
  viewport : Size?
}

///|
pub fn AlignmentGuideSet::from_size(
  size : Size,
  first_baseline~ : Double? = None,
  direction~ : LayoutDirection = LeftToRight,
) -> AlignmentGuideSet {
  // `leading` and `trailing` are reading-order words, so under right-to-left
  // layout they sit on the opposite physical edge. `center` and the baseline
  // are direction-free.
  let (leading, trailing) = match direction {
    LeftToRight => (0.0, size.width)
    RightToLeft => (size.width, 0.0)
  }
  { leading, center: size.width / 2.0, trailing, first_baseline, }
}

///|
/// Mirror an x coordinate into the RTL frame. Layout authors should pass every
/// child x through this helper so a single placement routine works in both
/// reading directions; it is the delegate-facing spelling of
/// `Rect::mirrored_x`, which is where the formula lives.
pub fn CustomPlacementContext::mirror_x(
  self : CustomPlacementContext,
  x~ : Double,
  width~ : Double,
) -> Double {
  self.frame.mirrored_x(x~, width~, direction=self.layout_direction)
}
