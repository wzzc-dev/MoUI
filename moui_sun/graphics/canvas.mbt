///|
/// 2D drawing canvas backed by a pixmap
pub struct Canvas {
  pixmap : Pixmap
  mut transform : Transform
  mut clip_rect : Rect?
  state_stack : Array[CanvasState]
  dirty_region : DirtyRegion
} derive(Debug)

///|
struct CanvasState {
  transform : Transform
  clip_rect : Rect?
} derive(Debug)

///|
/// Create a new canvas with the given dimensions
pub fn Canvas::new(width : Int, height : Int) -> Canvas {
  {
    pixmap: Pixmap::new(width, height),
    transform: Transform::identity(),
    clip_rect: None,
    state_stack: [],
    dirty_region: DirtyRegion::new(),
  }
}

///|
/// Get the underlying pixmap
pub fn Canvas::get_pixmap(self : Canvas) -> Pixmap {
  self.pixmap
}

///|
/// Clear the canvas with a color
pub fn Canvas::clear(self : Canvas, color : Color) -> Unit {
  self.pixmap.clear(color)
  self.dirty_region.add_all(self.pixmap.get_width(), self.pixmap.get_height())
}

///|
/// Get the accumulated dirty region for incremental rendering.
pub fn Canvas::get_dirty_region(self : Canvas) -> DirtyRegion {
  self.dirty_region
}

///|
/// Clear accumulated dirty rectangles.
pub fn Canvas::clear_dirty_region(self : Canvas) -> Unit {
  self.dirty_region.clear()
}

///|
/// Set the current transform
pub fn Canvas::set_transform(self : Canvas, transform : Transform) -> Unit {
  self.transform = transform
}

///|
/// Reset the current transform to identity.
pub fn Canvas::reset_transform(self : Canvas) -> Unit {
  self.transform = Transform::identity()
}

///|
/// Concatenate a transform onto the current transform.
pub fn Canvas::concat_transform(self : Canvas, transform : Transform) -> Unit {
  self.transform = self.transform.multiply(transform)
}

///|
/// Translate subsequent transformed drawing operations.
pub fn Canvas::translate(self : Canvas, tx~ : Double, ty~ : Double) -> Unit {
  self.concat_transform(Transform::translate(tx~, ty~))
}

///|
/// Scale subsequent transformed drawing operations.
pub fn Canvas::scale(self : Canvas, sx~ : Double, sy~ : Double) -> Unit {
  self.concat_transform(Transform::scale(sx~, sy~))
}

///|
/// Rotate subsequent transformed drawing operations by an angle in radians.
pub fn Canvas::rotate(self : Canvas, angle : Double) -> Unit {
  self.concat_transform(Transform::rotate(angle))
}

///|
/// Get the current transform
pub fn Canvas::get_transform(self : Canvas) -> Transform {
  self.transform
}

///|
/// Save the current transform and clip state.
pub fn Canvas::save(self : Canvas) -> Unit {
  self.state_stack.push({ transform: self.transform, clip_rect: self.clip_rect })
}

///|
/// Restore the most recently saved transform and clip state.
pub fn Canvas::restore(self : Canvas) -> Bool {
  guard self.state_stack.length() > 0 else { return false }
  let state = self.state_stack.remove(self.state_stack.length() - 1)
  self.transform = state.transform
  self.clip_rect = state.clip_rect
  true
}

///|
/// Get the number of saved canvas states.
pub fn Canvas::get_save_count(self : Canvas) -> Int {
  self.state_stack.length()
}

///|
/// Set the current clip rectangle in device coordinates.
pub fn Canvas::set_clip_rect(self : Canvas, rect : Rect) -> Unit {
  if !rect.is_empty() {
    self.clip_rect = Some(rect)
  } else {
    self.clip_rect = Some(Rect::new(x=0.0, y=0.0, width=0.0, height=0.0))
  }
}

///|
/// Intersect the current clip rectangle with a new device-space rectangle.
pub fn Canvas::intersect_clip_rect(self : Canvas, rect : Rect) -> Unit {
  guard !rect.is_empty() else {
    self.clip_rect = Some(Rect::new(x=0.0, y=0.0, width=0.0, height=0.0))
    return
  }
  match self.clip_rect {
    Some(current) =>
      match current.intersection(rect) {
        Some(intersection) => self.clip_rect = Some(intersection)
        None =>
          self.clip_rect = Some(Rect::new(x=0.0, y=0.0, width=0.0, height=0.0))
      }
    None => self.set_clip_rect(rect)
  }
}

///|
/// Clear the current clip rectangle.
pub fn Canvas::clear_clip(self : Canvas) -> Unit {
  self.clip_rect = None
}

///|
/// Get the current clip rectangle, if any.
pub fn Canvas::get_clip_rect(self : Canvas) -> Rect? {
  self.clip_rect
}

///|
/// Draw a single pixel (for testing)
pub fn Canvas::draw_pixel(
  self : Canvas,
  x : Int,
  y : Int,
  color : Color,
) -> Unit {
  guard is_pixel_in_clip(self, x, y) else { return }
  self.pixmap.set_pixel(x, y, color)
  self.mark_dirty_bounds(x, y, x + 1, y + 1)
}

///|
/// Draw placeholder text boxes at the given position.
pub fn Canvas::draw_placeholder_text(
  self : Canvas,
  text : String,
  x : Double,
  y : Double,
  font_size : Double,
  color : Color,
) -> Unit {
  let char_width = font_size * 0.6
  for i in 0..<text.length() {
    let px = (x + i.to_double() * char_width).to_int()
    let py = y.to_int()
    let size = font_size.to_int()
    blend_clipped_rect(self, px, py, size, size, color)
  }
}
