///|
/// Scanline rasterizer for vector path filling
pub struct ScanlineRasterizer {
  width : Int
  height : Int
  pixels : FixedArray[Byte]
}

///|
/// Create a new scanline rasterizer
pub fn ScanlineRasterizer::new(width : Int, height : Int) -> ScanlineRasterizer {
  let size = width * height * 4 // RGBA
  { width, height, pixels: FixedArray::make(size, 0) }
}

///|
/// Get the pixel buffer (RGBA)
pub fn ScanlineRasterizer::get_pixels(
  self : ScanlineRasterizer,
) -> FixedArray[Byte] {
  self.pixels
}

///|
/// Clear the buffer
pub fn ScanlineRasterizer::clear(
  self : ScanlineRasterizer,
  color : Color,
) -> Unit {
  for i in 0..<(self.width * self.height) {
    let idx = i * 4
    self.pixels[idx] = color.r
    self.pixels[idx + 1] = color.g
    self.pixels[idx + 2] = color.b
    self.pixels[idx + 3] = color.a
  }
}

///|
/// Set a pixel
fn ScanlineRasterizer::set_pixel(
  self : ScanlineRasterizer,
  x : Int,
  y : Int,
  color : Color,
) -> Unit {
  guard x >= 0 && x < self.width && y >= 0 && y < self.height else { return }
  let idx = (y * self.width + x) * 4
  self.pixels[idx] = color.r
  self.pixels[idx + 1] = color.g
  self.pixels[idx + 2] = color.b
  self.pixels[idx + 3] = color.a
}

///|
/// Fill a triangle using scanline algorithm
pub fn ScanlineRasterizer::fill_triangle(
  self : ScanlineRasterizer,
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  color : Color,
) -> Unit {
  // Sort vertices by y coordinate using local mutable variables
  let mut ax = x0
  let mut ay = y0
  let mut bx = x1
  let mut by = y1
  let mut cx = x2
  let mut cy = y2

  // Sort so that ay <= by <= cy
  if ay > by {
    let tx = ax
    let ty = ay
    ax = bx
    ay = by
    bx = tx
    by = ty
  }
  if ay > cy {
    let tx = ax
    let ty = ay
    ax = cx
    ay = cy
    cx = tx
    cy = ty
  }
  if by > cy {
    let tx = bx
    let ty = by
    bx = cx
    by = cy
    cx = tx
    cy = ty
  }

  let ay_int = ay.to_int()
  let cy_int = cy.to_int()

  // Fill scanlines
  for y in ay_int..<=cy_int {
    let y_double = y.to_double()

    // Find x intersections
    let mut x_left = 0.0
    let mut x_right = 0.0

    if y_double < by {
      // Upper half
      let t1 = if by == ay { 0.0 } else { (y_double - ay) / (by - ay) }
      let t2 = if cy == ay { 0.0 } else { (y_double - ay) / (cy - ay) }
      x_left = ax + t1 * (bx - ax)
      x_right = ax + t2 * (cx - ax)
    } else {
      // Lower half
      let t1 = if cy == by { 0.0 } else { (y_double - by) / (cy - by) }
      let t2 = if cy == ay { 0.0 } else { (y_double - ay) / (cy - ay) }
      x_left = bx + t1 * (cx - bx)
      x_right = ax + t2 * (cx - ax)
    }

    // Ensure x_left <= x_right
    if x_left > x_right {
      let temp = x_left
      x_left = x_right
      x_right = temp
    }

    // Fill the scanline
    let x_start = x_left.to_int()
    let x_end = x_right.to_int()
    for x in x_start..<=x_end {
      self.set_pixel(x, y, color)
    }
  }
}

///|
/// Draw a line using Bresenham's algorithm
pub fn ScanlineRasterizer::draw_line(
  self : ScanlineRasterizer,
  x0 : Int,
  y0 : Int,
  x1 : Int,
  y1 : Int,
  color : Color,
) -> Unit {
  let dx = (x1 - x0).abs()
  let dy = (y1 - y0).abs()
  let sx = if x0 < x1 { 1 } else { -1 }
  let sy = if y0 < y1 { 1 } else { -1 }
  let mut err = dx - dy

  let mut x = x0
  let mut y = y0

  while true {
    self.set_pixel(x, y, color)

    if x == x1 && y == y1 {
      break
    }

    let e2 = 2 * err
    if e2 > -dy {
      err = err - dy
      x = x + sx
    }
    if e2 < dx {
      err = err + dx
      y = y + sy
    }
  }
}

///|
/// Fill a convex polygon (works for any convex shape)
pub fn ScanlineRasterizer::fill_polygon(
  self : ScanlineRasterizer,
  points : Array[(Double, Double)],
  color : Color,
) -> Unit {
  let len = points.length()
  guard len >= 3 else { return }

  // Find bounding box
  let (_, first_y) = points[0]
  let mut min_y = first_y
  let mut max_y = first_y
  for i in 1..<len {
    let (_, y) = points[i]
    if y < min_y {
      min_y = y
    }
    if y > max_y {
      max_y = y
    }
  }

  let y_start = min_y.to_int()
  let y_end = max_y.to_int()

  // Scanline fill
  for y in y_start..<=y_end {
    let y_double = y.to_double()
    let intersections = []

    // Find intersections with polygon edges
    for i in 0..<len {
      let j = (i + 1) % len
      let (x1, y1) = points[i]
      let (x2, y2) = points[j]

      if (y1 <= y_double && y2 > y_double) || (y2 <= y_double && y1 > y_double) {
        let t = (y_double - y1) / (y2 - y1)
        let x = x1 + t * (x2 - x1)
        intersections.push(x)
      }
    }

    // Sort intersections
    let int_len = intersections.length()
    for i in 0..<int_len {
      for j in (i + 1)..<int_len {
        if intersections[i] > intersections[j] {
          let temp = intersections[i]
          intersections[i] = intersections[j]
          intersections[j] = temp
        }
      }
    }

    // Fill between pairs of intersections
    let mut k = 0
    while k + 1 < int_len {
      let x_start = intersections[k].to_int()
      let x_end = intersections[k + 1].to_int()
      for x in x_start..<=x_end {
        self.set_pixel(x, y, color)
      }
      k = k + 2
    }
  }
}
