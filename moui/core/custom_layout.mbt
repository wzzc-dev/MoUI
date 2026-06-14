///|
struct CustomLayoutCacheEntry {
  key : String
  mut value : String
} derive(Eq, Debug, ToJson)

///|
struct CustomLayoutCache {
  entries : Array[CustomLayoutCacheEntry]
}

///|
pub(all) struct AlignmentGuideSet {
  leading : Double
  center : Double
  trailing : Double
  first_baseline : Double?
} derive(Eq, Debug, ToJson)

///|
pub(all) struct CustomLayoutContext {
  constraints : Constraints
  child_sizes : Array[Size]
  child_baselines : Array[Double?]
  child_priorities : Array[Double]
  child_alignment_guides : Array[AlignmentGuideSet]
  cache : CustomLayoutCache
  cache_key : String
  layout_direction : LayoutDirection
  safe_area : Insets
  viewport : Size?
}

///|
pub(all) struct CustomPlacementContext {
  frame : Rect
  measured_size : Size
  child_sizes : Array[Size]
  child_baselines : Array[Double?]
  child_priorities : Array[Double]
  child_alignment_guides : Array[AlignmentGuideSet]
  cache : CustomLayoutCache
  cache_key : String
  layout_direction : LayoutDirection
  safe_area : Insets
  viewport : Size?
}

///|
priv struct CustomLayoutSpec {
  key : Key?
  children : Array[ViewSpec]
  cache : CustomLayoutCache
  measure : (CustomLayoutContext) -> Size
  place : (CustomPlacementContext) -> Array[Rect]
  paint : (Rect) -> Array[DrawCommand]
  semantics_role : SemanticsRole
  semantics_label : String
}

///|
pub fn CustomLayoutCache::new() -> CustomLayoutCache {
  { entries: [] }
}

///|
pub fn CustomLayoutCache::get(
  self : CustomLayoutCache,
  key : String,
) -> String? {
  for entry in self.entries {
    if entry.key == key {
      return Some(entry.value)
    }
  }
  None
}

///|
pub fn CustomLayoutCache::set(
  self : CustomLayoutCache,
  key : String,
  value : String,
) -> Unit {
  for entry in self.entries {
    if entry.key == key {
      entry.value = value
      return
    }
  }
  self.entries.push({ key, value })
}

///|
pub fn CustomLayoutCache::clear(self : CustomLayoutCache) -> Unit {
  self.entries.clear()
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
