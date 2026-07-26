///|
/// Layout-side metadata for a single child of a custom children layout.
///
/// Replaces the previous parallel arrays (`child_sizes`, `child_baselines`,
/// `child_priorities`, `child_alignment_guides`) with a single, typed record
/// per child. The runtime fills this from the measured/placed child element,
/// so custom layouts no longer have to rely on guessed baseline values or
/// hard-coded priorities.
pub(all) struct ChildLayoutInfo {
  /// Measured size of the child after its own layout pass.
  size : Size
  /// First baseline of the child, relative to its top edge. `None` means the
  /// child does not expose a baseline; layout authors should fall back to a
  /// reasonable default (e.g. `size.height * 0.8`) rather than treating the
  /// child as baseline-less.
  first_baseline : Double?
  /// Layout priority declared by the child (higher wins space disputes).
  /// Children that do not declare a priority report `0.0`.
  priority : Double
  /// Alignment guides derived from the child size and baseline. Computed by
  /// the runtime so authors do not have to reconstruct them per child.
  alignment_guides : AlignmentGuideSet
  /// Flex weight declared by the child. `0.0` means the child is not flex.
  flex_weight : Double
} derive(Eq, Debug)

///|
/// Construct a `ChildLayoutInfo` from measured child data. The runtime uses
/// this when assembling `CustomLayoutContext.children`; downstream packages
/// use it when building tests for custom layout delegates.
pub fn ChildLayoutInfo::new(
  size~ : Size,
  first_baseline? : Double? = None,
  priority? : Double = 0.0,
  flex_weight? : Double = 0.0,
) -> ChildLayoutInfo {
  {
    size,
    first_baseline,
    priority,
    flex_weight,
    alignment_guides: AlignmentGuideSet::from_size(
      size,
      first_baseline=first_baseline,
    ),
  }
}

///|
/// Convenience accessor: the child's resolved baseline, falling back to the
/// historical `size.height * 0.8` estimate when the child does not expose one.
/// Keeping the fallback here lets custom layouts stop special-casing the
/// "no baseline" branch while still preserving prior behavior for children
/// that genuinely lack a baseline.
pub fn ChildLayoutInfo::baseline_or_estimate(
  self : ChildLayoutInfo,
) -> Double {
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
  first_baseline? : Double? = None,
) -> AlignmentGuideSet {
  {
    leading: 0.0,
    center: size.width / 2.0,
    trailing: size.width,
    first_baseline,
  }
}

///|
/// Mirror an LTR x coordinate into the RTL frame. Layout authors should pass
/// every child x through this helper so a single placement routine works in
/// both reading directions.
pub fn CustomPlacementContext::mirror_x(
  self : CustomPlacementContext,
  x~ : Double,
  width~ : Double,
) -> Double {
  match self.layout_direction {
    LeftToRight => x
    RightToLeft =>
      self.frame.origin.x +
      self.frame.size.width -
      (x - self.frame.origin.x) -
      width
  }
}
