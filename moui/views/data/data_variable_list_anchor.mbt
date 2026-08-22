///|
pub fn VariableListMetrics::anchor_for_offset(
  self : VariableListMetrics,
  offset_y : Double,
) -> VariableListAnchor? {
  if self.count() == 0 {
    return None
  }
  let index = self.first_index_at(offset_y)
  Some({
    key: self.keys[index],
    inset: (offset_y.max(0.0) - self.offsets[index])
    .max(0.0)
    .min(self.heights[index] + self.spacing),
  })
}

///|
pub fn VariableListMetrics::offset_for_anchor(
  self : VariableListMetrics,
  anchor : VariableListAnchor,
  fallback? : Double = 0.0,
) -> Double {
  for index, key in self.keys {
    if key == anchor.key {
      let inset = anchor.inset.max(0.0).min(self.heights[index] + self.spacing)
      return (self.offsets[index] + inset).max(0.0)
    }
  }
  fallback.max(0.0).min(self.total_extent)
}

///|
pub fn VariableListAnchor::key(self : VariableListAnchor) -> String {
  self.key
}

///|
pub fn VariableListAnchor::inset(self : VariableListAnchor) -> Double {
  self.inset
}

///|
pub fn VariableListRange::first_index(self : VariableListRange) -> Int {
  self.first_index
}

///|
pub fn VariableListRange::last_index(self : VariableListRange) -> Int {
  self.last_index
}

///|
pub fn VariableListRange::before_extent(self : VariableListRange) -> Double {
  self.before_extent
}

///|
pub fn VariableListRange::after_extent(self : VariableListRange) -> Double {
  self.after_extent
}
