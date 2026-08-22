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
pub struct VariableListMetrics {
  keys : Array[String]
  heights : Array[Double]
  offsets : Array[Double]
  spacing : Double
  total_extent : Double
}

///|
pub fn[T] variable_list_metrics(
  items : Array[T],
  key : (T) -> String,
  item_height : (T) -> Double,
  spacing? : Double = 0.0,
) -> VariableListMetrics {
  let keys : Array[String] = []
  let heights : Array[Double] = []
  for item in items {
    keys.push(key(item))
    heights.push(item_height(item).max(0.0))
  }
  variable_list_metrics_from_parts(keys, heights, spacing.max(0.0))
}

///|
fn variable_list_metrics_from_parts(
  keys : Array[String],
  heights : Array[Double],
  spacing : Double,
) -> VariableListMetrics {
  let offsets : Array[Double] = []
  let mut cursor = 0.0
  for index, height in heights {
    offsets.push(cursor)
    cursor = cursor + height
    if index + 1 < heights.length() {
      cursor = cursor + spacing
    }
  }
  { keys, heights, offsets, spacing, total_extent: cursor }
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
pub fn VariableListMetrics::offset_at(
  self : VariableListMetrics,
  index : Int,
) -> Double? {
  self.offsets.get(index)
}

///|
pub fn VariableListMetrics::offset_for_key(
  self : VariableListMetrics,
  key : String,
) -> Double? {
  for index, item_key in self.keys {
    if item_key == key {
      return self.offsets.get(index)
    }
  }
  None
}

///|
pub fn VariableListMetrics::with_height(
  self : VariableListMetrics,
  key : String,
  height : Double,
) -> VariableListMetrics {
  let heights = self.heights.copy()
  for index, item_key in self.keys {
    if item_key == key {
      heights[index] = height.max(0.0)
      return variable_list_metrics_from_parts(
        self.keys.copy(),
        heights,
        self.spacing,
      )
    }
  }
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
    let item_end = self.offsets[middle] + self.heights[middle] + self.spacing
    if item_end <= target {
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
    if self.offsets[middle] < offset {
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
  let before_extent = if first == 0 {
    0.0
  } else {
    (self.offsets[first] - self.spacing).max(0.0)
  }
  let item_end = self.offsets[last] + self.heights[last]
  let after_extent = if last + 1 == count {
    0.0
  } else {
    (self.total_extent - item_end - self.spacing).max(0.0)
  }
  Some({ first_index: first, last_index: last, before_extent, after_extent })
}
