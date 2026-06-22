///|
/// Pixel-aligned rectangle used for dirty-region tracking.
pub struct PixelRect {
  x : Int
  y : Int
  width : Int
  height : Int
} derive(Eq, Debug)

///|
/// Strategy selected for submitting a dirty region to a Surface.
pub(all) enum DirtyPresentPlanMode {
  Empty
  Rects
  Bounds
} derive(Eq, Debug)

///|
/// Scheduler-facing present strategy chosen from a dirty present plan and the
/// full-frame pixel budget.
pub(all) enum DirtyPresentStrategy {
  Skip
  Partial
  Full
} derive(Eq, Debug)

///|
/// Scheduler-facing state for a dirty submit snapshot.
pub(all) enum DirtySubmitState {
  Clean
  Present
  DirtyClippedAway
} derive(Eq, Debug)

///|
/// A concrete dirty-present plan after clipping to the target bounds and
/// applying a rectangle-count limit.
pub struct DirtyPresentPlan {
  mode : DirtyPresentPlanMode
  rects : Array[PixelRect]
} derive(Debug)

///|
/// Dirty state snapshot for schedulers: logical dirty bounds plus the clipped
/// present plan that would be submitted to the current surface.
pub struct DirtySubmitPlan {
  dirty_bounds : PixelRect?
  present_plan : DirtyPresentPlan
} derive(Debug)

///|
/// Result of submitting a dirty frame: the scheduler-visible plan snapshot plus
/// the number of rectangles actually presented to the surface.
pub struct DirtySubmitResult {
  submit_plan : DirtySubmitPlan
  presented_rect_count : Int
} derive(Debug)

///|
pub fn DirtyPresentPlan::get_mode(
  self : DirtyPresentPlan,
) -> DirtyPresentPlanMode {
  self.mode
}

///|
pub fn DirtyPresentPlan::get_rects(self : DirtyPresentPlan) -> Array[PixelRect] {
  copy_pixel_rects(self.rects)
}

///|
pub fn DirtyPresentPlan::get_rect_count(self : DirtyPresentPlan) -> Int {
  self.rects.length()
}

///|
pub fn DirtyPresentPlan::get_present_bounds(
  self : DirtyPresentPlan,
) -> PixelRect? {
  guard !self.is_empty() else { return None }
  pixel_rect_array_bounds(self.rects)
}

///|
pub fn DirtyPresentPlan::get_present_pixel_count(
  self : DirtyPresentPlan,
) -> Int {
  guard !self.is_empty() else { return 0 }
  let mut pixels = 0
  for rect in self.rects {
    pixels = pixels + rect.area()
  }
  pixels
}

///|
pub fn DirtyPresentPlan::get_present_byte_count(self : DirtyPresentPlan) -> Int {
  self.get_present_pixel_count() * 4
}

///|
pub fn DirtyPresentPlan::saves_full_present_pixels(
  self : DirtyPresentPlan,
  width : Int,
  height : Int,
) -> Bool {
  guard !self.is_empty() else { return false }
  let full_pixels = PixelRect::new(x=0, y=0, width~, height~).area()
  full_pixels > 0 && self.get_present_pixel_count() < full_pixels
}

///|
pub fn DirtyPresentPlan::get_present_strategy(
  self : DirtyPresentPlan,
  width : Int,
  height : Int,
) -> DirtyPresentStrategy {
  guard !self.is_empty() else { return DirtyPresentStrategy::Skip }
  if self.saves_full_present_pixels(width, height) {
    DirtyPresentStrategy::Partial
  } else {
    DirtyPresentStrategy::Full
  }
}

///|
pub fn DirtyPresentPlan::is_empty(self : DirtyPresentPlan) -> Bool {
  self.mode == DirtyPresentPlanMode::Empty || self.rects.length() == 0
}

///|
pub fn DirtyPresentPlan::uses_bounds_fallback(self : DirtyPresentPlan) -> Bool {
  self.mode == DirtyPresentPlanMode::Bounds
}

///|
pub fn DirtySubmitPlan::get_dirty_bounds(self : DirtySubmitPlan) -> PixelRect? {
  self.dirty_bounds
}

///|
pub fn DirtySubmitPlan::get_present_plan(
  self : DirtySubmitPlan,
) -> DirtyPresentPlan {
  self.present_plan
}

///|
pub fn DirtySubmitPlan::has_dirty(self : DirtySubmitPlan) -> Bool {
  match self.dirty_bounds {
    Some(_) => true
    None => false
  }
}

///|
pub fn DirtySubmitPlan::needs_present(self : DirtySubmitPlan) -> Bool {
  !self.present_plan.is_empty()
}

///|
pub fn DirtySubmitPlan::get_state(self : DirtySubmitPlan) -> DirtySubmitState {
  if self.needs_present() {
    return DirtySubmitState::Present
  }
  if self.has_dirty() {
    return DirtySubmitState::DirtyClippedAway
  }
  DirtySubmitState::Clean
}

///|
pub fn DirtySubmitPlan::get_present_rect_count(self : DirtySubmitPlan) -> Int {
  self.present_plan.get_rect_count()
}

///|
pub fn DirtySubmitPlan::get_present_pixel_count(self : DirtySubmitPlan) -> Int {
  self.present_plan.get_present_pixel_count()
}

///|
pub fn DirtySubmitPlan::get_present_byte_count(self : DirtySubmitPlan) -> Int {
  self.present_plan.get_present_byte_count()
}

///|
pub fn DirtySubmitPlan::get_present_bounds(
  self : DirtySubmitPlan,
) -> PixelRect? {
  self.present_plan.get_present_bounds()
}

///|
pub fn DirtySubmitPlan::saves_full_present_pixels(
  self : DirtySubmitPlan,
  width : Int,
  height : Int,
) -> Bool {
  self.present_plan.saves_full_present_pixels(width, height)
}

///|
pub fn DirtySubmitPlan::get_present_strategy(
  self : DirtySubmitPlan,
  width : Int,
  height : Int,
) -> DirtyPresentStrategy {
  self.present_plan.get_present_strategy(width, height)
}

///|
pub fn DirtySubmitPlan::uses_bounds_fallback(self : DirtySubmitPlan) -> Bool {
  self.present_plan.uses_bounds_fallback()
}

///|
pub fn DirtySubmitResult::get_submit_plan(
  self : DirtySubmitResult,
) -> DirtySubmitPlan {
  self.submit_plan
}

///|
pub fn DirtySubmitResult::get_dirty_bounds(
  self : DirtySubmitResult,
) -> PixelRect? {
  self.submit_plan.get_dirty_bounds()
}

///|
pub fn DirtySubmitResult::get_state(
  self : DirtySubmitResult,
) -> DirtySubmitState {
  self.submit_plan.get_state()
}

///|
pub fn DirtySubmitResult::has_dirty(self : DirtySubmitResult) -> Bool {
  self.submit_plan.has_dirty()
}

///|
pub fn DirtySubmitResult::needs_present(self : DirtySubmitResult) -> Bool {
  self.submit_plan.needs_present()
}

///|
pub fn DirtySubmitResult::was_clipped_away(self : DirtySubmitResult) -> Bool {
  self.get_state() == DirtySubmitState::DirtyClippedAway
}

///|
pub fn DirtySubmitResult::uses_bounds_fallback(
  self : DirtySubmitResult,
) -> Bool {
  self.submit_plan.uses_bounds_fallback()
}

///|
pub fn DirtySubmitResult::did_present(self : DirtySubmitResult) -> Bool {
  self.presented_rect_count > 0
}

///|
pub fn DirtySubmitResult::get_presented_rect_count(
  self : DirtySubmitResult,
) -> Int {
  self.presented_rect_count
}

///|
pub fn DirtySubmitResult::get_present_pixel_count(
  self : DirtySubmitResult,
) -> Int {
  self.submit_plan.get_present_pixel_count()
}

///|
pub fn DirtySubmitResult::get_present_byte_count(
  self : DirtySubmitResult,
) -> Int {
  self.submit_plan.get_present_byte_count()
}

///|
pub fn DirtySubmitResult::get_present_bounds(
  self : DirtySubmitResult,
) -> PixelRect? {
  self.submit_plan.get_present_bounds()
}

///|
pub fn DirtySubmitResult::saves_full_present_pixels(
  self : DirtySubmitResult,
  width : Int,
  height : Int,
) -> Bool {
  self.submit_plan.saves_full_present_pixels(width, height)
}

///|
pub fn DirtySubmitResult::get_present_strategy(
  self : DirtySubmitResult,
  width : Int,
  height : Int,
) -> DirtyPresentStrategy {
  self.submit_plan.get_present_strategy(width, height)
}

///|
pub fn PixelRect::new(
  x~ : Int,
  y~ : Int,
  width~ : Int,
  height~ : Int,
) -> PixelRect {
  { x, y, width, height }
}

///|
pub fn PixelRect::right(self : PixelRect) -> Int {
  self.x + self.width
}

///|
pub fn PixelRect::bottom(self : PixelRect) -> Int {
  self.y + self.height
}

///|
pub fn PixelRect::is_empty(self : PixelRect) -> Bool {
  self.width <= 0 || self.height <= 0
}

///|
pub fn PixelRect::area(self : PixelRect) -> Int {
  if self.is_empty() {
    return 0
  }
  self.width * self.height
}

///|
pub fn PixelRect::contains(self : PixelRect, x : Int, y : Int) -> Bool {
  !self.is_empty() &&
  x >= self.x &&
  x < self.right() &&
  y >= self.y &&
  y < self.bottom()
}

///|
pub fn PixelRect::intersects(self : PixelRect, other : PixelRect) -> Bool {
  match self.intersection(other) {
    Some(_) => true
    None => false
  }
}

///|
pub fn PixelRect::intersection(
  self : PixelRect,
  other : PixelRect,
) -> PixelRect? {
  let left = self.x.max(other.x)
  let top = self.y.max(other.y)
  let right = self.right().min(other.right())
  let bottom = self.bottom().min(other.bottom())
  let width = right - left
  let height = bottom - top
  guard width > 0 && height > 0 else { return None }
  Some(PixelRect::new(x=left, y=top, width~, height~))
}

///|
pub fn PixelRect::union(self : PixelRect, other : PixelRect) -> PixelRect {
  if self.is_empty() {
    return other
  }
  if other.is_empty() {
    return self
  }
  let left = self.x.min(other.x)
  let top = self.y.min(other.y)
  let right = self.right().max(other.right())
  let bottom = self.bottom().max(other.bottom())
  PixelRect::new(x=left, y=top, width=right - left, height=bottom - top)
}

///|
pub fn PixelRect::clip_to(self : PixelRect, bounds : PixelRect) -> PixelRect? {
  self.intersection(bounds)
}

///|
fn pixel_rect_array_bounds(rects : Array[PixelRect]) -> PixelRect? {
  let mut has_bounds = false
  let mut bounds = PixelRect::new(x=0, y=0, width=0, height=0)
  for rect in rects {
    if !rect.is_empty() {
      if has_bounds {
        bounds = bounds.union(rect)
      } else {
        bounds = rect
        has_bounds = true
      }
    }
  }
  if has_bounds {
    Some(bounds)
  } else {
    None
  }
}

///|
fn copy_pixel_rects(rects : Array[PixelRect]) -> Array[PixelRect] {
  let copied = []
  for rect in rects {
    copied.push(rect)
  }
  copied
}

///|
fn pixel_rects_can_merge(a : PixelRect, b : PixelRect) -> Bool {
  guard !a.is_empty() && !b.is_empty() else { return false }
  if a.intersects(b) {
    return true
  }
  let horizontal_touch = a.right() == b.x || b.right() == a.x
  let vertical_touch = a.bottom() == b.y || b.bottom() == a.y
  (horizontal_touch && ranges_overlap(a.y, a.bottom(), b.y, b.bottom())) ||
  (vertical_touch && ranges_overlap(a.x, a.right(), b.x, b.right()))
}

///|
fn ranges_overlap(
  a_start : Int,
  a_end : Int,
  b_start : Int,
  b_end : Int,
) -> Bool {
  a_start.max(b_start) < a_end.min(b_end)
}

///|
/// Accumulates pixel-aligned dirty rectangles for incremental rendering.
pub struct DirtyRegion {
  mut rects : Array[PixelRect]
} derive(Debug)

///|
pub fn DirtyRegion::new() -> DirtyRegion {
  { rects: [] }
}

///|
pub fn DirtyRegion::is_empty(self : DirtyRegion) -> Bool {
  self.rects.length() == 0
}

///|
pub fn DirtyRegion::clear(self : DirtyRegion) -> Unit {
  self.rects = []
}

///|
pub fn DirtyRegion::get_rect_count(self : DirtyRegion) -> Int {
  self.rects.length()
}

///|
pub fn DirtyRegion::get_rects(self : DirtyRegion) -> Array[PixelRect] {
  copy_pixel_rects(self.rects)
}

///|
pub fn DirtyRegion::add_rect(self : DirtyRegion, rect : PixelRect) -> Unit {
  guard !rect.is_empty() else { return }
  let mut merged = rect
  let mut pending = self.rects
  let mut changed = true
  while changed {
    changed = false
    let remaining = []
    for existing in pending {
      if pixel_rects_can_merge(merged, existing) {
        merged = merged.union(existing)
        changed = true
      } else {
        remaining.push(existing)
      }
    }
    pending = remaining
  }
  pending.push(merged)
  self.rects = pending
}

///|
pub fn DirtyRegion::add_clipped_rect(
  self : DirtyRegion,
  rect : PixelRect,
  bounds : PixelRect,
) -> Unit {
  match rect.clip_to(bounds) {
    Some(clipped) => self.add_rect(clipped)
    None => ()
  }
}

///|
pub fn DirtyRegion::add_all(
  self : DirtyRegion,
  width : Int,
  height : Int,
) -> Unit {
  self.add_rect(PixelRect::new(x=0, y=0, width~, height~))
}

///|
pub fn DirtyRegion::bounds(self : DirtyRegion) -> PixelRect? {
  pixel_rect_array_bounds(self.rects)
}

///|
pub fn DirtyRegion::present_rects(
  self : DirtyRegion,
  bounds : PixelRect,
  max_rects : Int,
) -> Array[PixelRect] {
  self.present_plan(bounds, max_rects).get_rects()
}

///|
pub fn DirtyRegion::present_plan(
  self : DirtyRegion,
  bounds : PixelRect,
  max_rects : Int,
) -> DirtyPresentPlan {
  let clipped = []
  for rect in self.rects {
    match rect.clip_to(bounds) {
      Some(value) => clipped.push(value)
      None => ()
    }
  }
  guard clipped.length() > 0 else {
    return { mode: DirtyPresentPlanMode::Empty, rects: [] }
  }
  guard max_rects <= 0 || clipped.length() <= max_rects else {
    let region = DirtyRegion::new()
    for rect in clipped {
      region.add_rect(rect)
    }
    match region.bounds() {
      Some(value) => { mode: DirtyPresentPlanMode::Bounds, rects: [value] }
      None => { mode: DirtyPresentPlanMode::Empty, rects: [] }
    }
  }
  { mode: DirtyPresentPlanMode::Rects, rects: clipped }
}
