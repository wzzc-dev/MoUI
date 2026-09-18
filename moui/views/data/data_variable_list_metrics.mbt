///|
pub struct VariableListAnchor {
  key : String
  inset : Double
}

///|
pub struct VariableListRange {
  first_index : Int
  last_index : Int
  before_extent : Double
  after_extent : Double
}

///|
pub struct VariableListGeometryChange {
  key : String
  index : Int
  old_height : Double
  new_height : Double
  delta : Double
  total_delta : Double
}

///|
/// Dynamic variable-height geometry backed by a Fenwick prefix structure.
pub struct VariableListMetrics {
  keys : Array[String]
  heights : Array[Double]
  estimated : Array[Double]
  measured : Array[Bool]
  mut tree : Array[Double]
  spacing : Double
  mut total_extent : Double
}

///|
pub fn[T] variable_list_metrics(
  items : Array[T],
  key : (T) -> String,
  estimated_height : (T) -> Double,
  spacing? : Double = 0.0,
) -> VariableListMetrics {
  let keys : Array[String] = []
  let heights : Array[Double] = []
  for item in items {
    keys.push(key(item))
    heights.push(estimated_height(item).max(0.0))
  }
  variable_list_metrics_from_parts(keys, heights, spacing.max(0.0))
}

///|
fn variable_list_metrics_from_parts(
  keys : Array[String],
  heights : Array[Double],
  spacing : Double,
) -> VariableListMetrics {
  let measured : Array[Bool] = []
  for _ in heights {
    measured.push(false)
  }
  {
    keys,
    heights,
    estimated: heights.copy(),
    measured,
    tree: variable_list_build_tree(heights, spacing),
    spacing,
    total_extent: variable_list_total_extent(heights, spacing),
  }
}

///|
fn variable_list_total_extent(
  heights : Array[Double],
  spacing : Double,
) -> Double {
  let mut total = 0.0
  for index, height in heights {
    total = total + height
    if index + 1 < heights.length() {
      total = total + spacing
    }
  }
  total
}

///|
fn variable_list_build_tree(
  heights : Array[Double],
  spacing : Double,
) -> Array[Double] {
  let tree : Array[Double] = []
  for _ in 0..<(heights.length() + 1) {
    tree.push(0.0)
  }
  for index, height in heights {
    let gap = if index + 1 < heights.length() { spacing } else { 0.0 }
    let value = height + gap
    let mut i = index + 1
    while i < tree.length() {
      tree[i] = tree[i] + value
      i = i + (i & -i)
    }
    continue
  }
  tree
}

///|
fn VariableListMetrics::prefix_at(
  self : VariableListMetrics,
  count : Int,
) -> Double {
  let mut i = count.min(self.count()).max(0)
  let mut result = 0.0
  while i > 0 {
    result = result + self.tree[i]
    i = i - (i & -i)
  }
  result
}

///|
fn VariableListMetrics::point_delta(
  self : VariableListMetrics,
  index : Int,
  delta : Double,
) -> Unit {
  let mut i = index + 1
  while i < self.tree.length() {
    self.tree[i] = self.tree[i] + delta
    i = i + (i & -i)
  }
}

///|
pub fn VariableListMetrics::count(self : VariableListMetrics) -> Int {
  self.keys.length()
}

///|
pub fn VariableListMetrics::total_extent(self : VariableListMetrics) -> Double {
  self.total_extent
}

///|
pub fn VariableListMetrics::height_at(
  self : VariableListMetrics,
  index : Int,
) -> Double? {
  self.heights.get(index)
}

///|
pub fn VariableListMetrics::is_measured(
  self : VariableListMetrics,
  index : Int,
) -> Bool {
  self.measured.get(index).unwrap_or(false)
}

///|
pub fn VariableListMetrics::offset_at(
  self : VariableListMetrics,
  index : Int,
) -> Double? {
  if index < 0 || index >= self.count() {
    None
  } else {
    Some(self.prefix_at(index))
  }
}

///|
pub fn VariableListMetrics::offset_for_key(
  self : VariableListMetrics,
  key : String,
) -> Double? {
  for index, item_key in self.keys {
    if item_key == key {
      return Some(self.prefix_at(index))
    }
  }
  None
}

///|
pub fn VariableListMetrics::update_height(
  self : VariableListMetrics,
  key : String,
  height : Double,
) -> VariableListGeometryChange? {
  for index, item_key in self.keys {
    if item_key == key {
      let old_height = self.heights[index]
      let new_height = height.max(0.0)
      let delta = new_height - old_height
      if delta != 0.0 {
        self.heights[index] = new_height
        self.measured[index] = true
        self.total_extent = self.total_extent + delta
        self.point_delta(index, delta)
      }
      return Some({
        key,
        index,
        old_height,
        new_height,
        delta,
        total_delta: delta,
      })
    }
  }
  None
}

///|
pub fn VariableListMetrics::update_heights(
  self : VariableListMetrics,
  updates : Array[(String, Double)],
) -> Array[VariableListGeometryChange] {
  let changes : Array[VariableListGeometryChange] = []
  for update in updates {
    let key = update.0
    let height = update.1
    match self.update_height(key, height) {
      Some(change) => changes.push(change)
      None => ()
    }
  }
  changes
}

///|
pub fn VariableListMetrics::insert(
  self : VariableListMetrics,
  index : Int,
  key : String,
  estimated_height : Double,
) -> Int {
  let at = index.max(0).min(self.count())
  self.keys.insert(at, key)
  self.heights.insert(at, estimated_height.max(0.0))
  self.estimated.insert(at, estimated_height.max(0.0))
  self.measured.insert(at, false)
  self.tree = variable_list_build_tree(self.heights, self.spacing)
  self.total_extent = variable_list_total_extent(self.heights, self.spacing)
  at
}

///|
pub fn VariableListMetrics::remove(
  self : VariableListMetrics,
  key : String,
) -> Int? {
  for index, item_key in self.keys {
    if item_key == key {
      ignore(self.keys.remove(index))
      ignore(self.heights.remove(index))
      ignore(self.estimated.remove(index))
      ignore(self.measured.remove(index))
      self.tree = variable_list_build_tree(self.heights, self.spacing)
      self.total_extent = variable_list_total_extent(self.heights, self.spacing)
      return Some(index)
    }
  }
  None
}

///|
/// Compatibility helper; updates the shared geometry in place.
pub fn VariableListMetrics::with_height(
  self : VariableListMetrics,
  key : String,
  height : Double,
) -> VariableListMetrics {
  ignore(self.update_height(key, height))
  self
}

///|
fn VariableListMetrics::first_index_at(
  self : VariableListMetrics,
  offset : Double,
) -> Int {
  let count = self.count()
  if count == 0 {
    return 0
  }
  let target = offset.max(0.0)
  let mut low = 0
  let mut high = count
  while low < high {
    let middle = low + (high - low) / 2
    if self.prefix_at(middle + 1) <= target {
      low = middle + 1
    } else {
      high = middle
    }
  }
  low.min(count - 1)
}

///|
fn VariableListMetrics::first_start_at_or_after(
  self : VariableListMetrics,
  offset : Double,
) -> Int {
  let mut low = 0
  let mut high = self.count()
  while low < high {
    let middle = low + (high - low) / 2
    if self.prefix_at(middle) < offset {
      low = middle + 1
    } else {
      high = middle
    }
  }
  low
}

///|
pub fn VariableListMetrics::visible_range(
  self : VariableListMetrics,
  offset_y~ : Double,
  viewport_height~ : Double,
  overscan? : Int = 1,
) -> VariableListRange? {
  let count = self.count()
  if count == 0 {
    return None
  }
  let first_visible = self.first_index_at(offset_y)
  let viewport_end = offset_y.max(0.0) + viewport_height.max(0.0)
  let after_visible = self.first_start_at_or_after(viewport_end)
  let last_visible = (after_visible - 1).max(first_visible).min(count - 1)
  let resolved_overscan = overscan.max(0)
  let first = (first_visible - resolved_overscan).max(0)
  let last = (last_visible + resolved_overscan).min(count - 1)
  let gap = if first > 0 { self.spacing } else { 0.0 }
  let before_extent = (self.prefix_at(first) - gap).max(0.0)
  let after_extent = (self.total_extent - self.prefix_at(last + 1)).max(0.0)
  Some({ first_index: first, last_index: last, before_extent, after_extent })
}

///|
pub fn VariableListMetrics::max_scroll_offset(
  self : VariableListMetrics,
  viewport_height : Double,
) -> Double {
  (self.total_extent - viewport_height.max(0.0)).max(0.0)
}

///|
pub fn VariableListMetrics::clamp_offset(
  self : VariableListMetrics,
  offset : Double,
  viewport_height : Double,
) -> Double {
  offset.max(0.0).min(self.max_scroll_offset(viewport_height))
}

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
    inset: (offset_y.max(0.0) - self.prefix_at(index))
    .max(0.0)
    .min(self.heights[index]),
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
      return self.prefix_at(index) +
        anchor.inset.max(0.0).min(self.heights[index])
    }
  }
  fallback.max(0.0).min(self.total_extent)
}

///|
pub fn VariableListMetrics::restore_offset_after_updates(
  self : VariableListMetrics,
  anchor : VariableListAnchor?,
  updates : Array[VariableListGeometryChange],
  current_offset : Double,
  viewport_height : Double,
) -> Double {
  let old_total = self.total_extent -
    updates.fold(init=0.0, (sum, item) => sum + item.total_delta)
  let at_bottom = current_offset >= (old_total - viewport_height).max(0.0) - 1.0
  let target = match anchor {
    Some(value) => self.offset_for_anchor(value, fallback=current_offset)
    None => current_offset
  }
  if at_bottom {
    self.max_scroll_offset(viewport_height)
  } else {
    self.clamp_offset(target, viewport_height)
  }
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

///|
pub fn VariableListGeometryChange::key(
  self : VariableListGeometryChange,
) -> String {
  self.key
}

///|
pub fn VariableListGeometryChange::index(
  self : VariableListGeometryChange,
) -> Int {
  self.index
}

///|
pub fn VariableListGeometryChange::old_height(
  self : VariableListGeometryChange,
) -> Double {
  self.old_height
}

///|
pub fn VariableListGeometryChange::new_height(
  self : VariableListGeometryChange,
) -> Double {
  self.new_height
}

///|
pub fn VariableListGeometryChange::delta(
  self : VariableListGeometryChange,
) -> Double {
  self.delta
}

///|
pub fn VariableListGeometryChange::total_delta(
  self : VariableListGeometryChange,
) -> Double {
  self.total_delta
}
