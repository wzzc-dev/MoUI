///|
/// CPU image filters for `Image` buffers (port of p5.js image/filters.js).
/// Filter name and parameters mirror p5's `filter()` calls.

///|
/// Converts to a byte like `Uint8ClampedArray`: clamp, round half to even.
fn filter_byte(value : Double) -> Byte {
  if value.is_nan() || value <= 0.0 {
    return (0 : Byte)
  }
  if value >= 255.0 {
    return (255 : Byte)
  }
  let floor = value.floor()
  let diff = value - floor
  let rounded = if diff > 0.5 {
    floor + 1.0
  } else if diff < 0.5 {
    floor
  } else if floor.to_int() % 2 == 0 {
    floor
  } else {
    floor + 1.0
  }
  rounded.to_int().to_byte()
}

///|
fn filter_luma(pixels : FixedArray[Byte], index : Int32) -> Double {
  0.2126 * pixels[index].to_uint().to_double() +
  0.7152 * pixels[index + 1].to_uint().to_double() +
  0.0722 * pixels[index + 2].to_uint().to_double()
}

///|
fn filter_threshold(pixels : FixedArray[Byte], level : Double) -> Unit {
  let threshold = (level * 255.0).floor()
  let mut index = 0
  while index + 3 < pixels.length() {
    let value : Byte = if filter_luma(pixels, index) >= threshold {
      (255 : Byte)
    } else {
      (0 : Byte)
    }
    pixels[index] = value
    pixels[index + 1] = value
    pixels[index + 2] = value
    index = index + 4
  }
}

///|
fn filter_gray(pixels : FixedArray[Byte]) -> Unit {
  let mut index = 0
  while index + 3 < pixels.length() {
    let value = filter_byte(filter_luma(pixels, index))
    pixels[index] = value
    pixels[index + 1] = value
    pixels[index + 2] = value
    index = index + 4
  }
}

///|
fn filter_opaque(pixels : FixedArray[Byte]) -> Unit {
  let mut index = 3
  while index < pixels.length() {
    pixels[index] = (255 : Byte)
    index = index + 4
  }
}

///|
fn filter_invert(pixels : FixedArray[Byte]) -> Unit {
  let mut index = 0
  while index + 3 < pixels.length() {
    pixels[index] = (255 - pixels[index].to_uint().reinterpret_as_int()).to_byte()
    pixels[index + 1] = (255 - pixels[index + 1].to_uint().reinterpret_as_int()).to_byte()
    pixels[index + 2] = (255 - pixels[index + 2].to_uint().reinterpret_as_int()).to_byte()
    index = index + 4
  }
}

///|
fn filter_posterize(pixels : FixedArray[Byte], levels : Int32) -> Unit {
  let levels = levels.max(2).min(255)
  let levels_minus = (levels - 1).to_double()
  let map = fn(value : Byte) {
    filter_byte(
      ((value.to_uint().reinterpret_as_int() * levels) >> 8).to_double() *
      255.0 /
      levels_minus,
    )
  }
  let mut index = 0
  while index + 3 < pixels.length() {
    pixels[index] = map(pixels[index])
    pixels[index + 1] = map(pixels[index + 1])
    pixels[index + 2] = map(pixels[index + 2])
    index = index + 4
  }
}

///|
fn filter_luma_index(pixels : FixedArray[Byte], pixel_index : Int32) -> Int32 {
  let index = pixel_index * 4
  77 * pixels[index].to_uint().reinterpret_as_int() +
  151 * pixels[index + 1].to_uint().reinterpret_as_int() +
  28 * pixels[index + 2].to_uint().reinterpret_as_int()
}

///|
fn filter_morph(
  pixels : FixedArray[Byte],
  width : Int32,
  dilate : Bool,
) -> Unit {
  let count = pixels.length() / 4
  if width <= 0 || count == 0 {
    return
  }
  let output = FixedArray::make(count, (0 : Int32))
  for index in 0..<count {
    let row_start = index / width * width
    let row_end = row_start + width
    let left = if index - 1 < row_start { index } else { index - 1 }
    let right = if index + 1 >= row_end { index } else { index + 1 }
    let up = if index - width < 0 { 0 } else { index - width }
    let down = if index + width >= count { index } else { index + width }
    let mut best = index
    let mut best_luma = filter_luma_index(pixels, index)
    for neighbor in [left, right, up, down] {
      let luma = filter_luma_index(pixels, neighbor)
      if (dilate && luma > best_luma) || (!dilate && luma < best_luma) {
        best = neighbor
        best_luma = luma
      }
    }
    output[index] = best
  }
  let source = pixels.copy()
  for index in 0..<count {
    let src = output[index] * 4
    let dst = index * 4
    pixels[dst] = source[src]
    pixels[dst + 1] = source[src + 1]
    pixels[dst + 2] = source[src + 2]
    pixels[dst + 3] = source[src + 3]
  }
}

///|
fn filter_blur(
  pixels : FixedArray[Byte],
  width : Int32,
  radius : Double,
) -> Unit {
  let radius = radius.round().to_int()
  if radius < 1 || width <= 0 {
    return
  }
  let height = pixels.length() / 4 / width
  let buffer = FixedArray::make(pixels.length(), 0.0)
  for index in 0..<(pixels.length() / 4) {
    let alpha = pixels[index * 4 + 3].to_uint().to_double() / 255.0
    buffer[index * 4] = pixels[index * 4].to_uint().to_double() * alpha
    buffer[index * 4 + 1] = pixels[index * 4 + 1].to_uint().to_double() * alpha
    buffer[index * 4 + 2] = pixels[index * 4 + 2].to_uint().to_double() * alpha
    buffer[index * 4 + 3] = alpha
  }
  let temp = FixedArray::make(pixels.length(), 0.0)
  let pass = fn(
    source : FixedArray[Double],
    destination : FixedArray[Double],
    horizontal : Bool,
  ) {
    let (outer, inner) = if horizontal {
      (height, width)
    } else {
      (width, height)
    }
    for o in 0..<outer {
      let index = fn(k : Int32) {
        if horizontal {
          (o * width + k) * 4
        } else {
          (k * width + o) * 4
        }
      }
      for channel in 0..<4 {
        let mut sum = 0.0
        let mut count = 0
        for k in 0..<=radius.min(inner - 1) {
          sum = sum + source[index(k) + channel]
          count = count + 1
        }
        for k in 0..<inner {
          destination[index(k) + channel] = sum / count.to_double()
          let add = k + radius + 1
          let subtract = k - radius
          if add < inner {
            sum = sum + source[index(add) + channel]
            count = count + 1
          }
          if subtract >= 0 {
            sum = sum - source[index(subtract) + channel]
            count = count - 1
          }
        }
      }
    }
  }
  for _ in 0..<3 {
    pass(buffer, temp, true)
    pass(temp, buffer, false)
  }
  for index in 0..<(pixels.length() / 4) {
    let alpha = buffer[index * 4 + 3]
    let inverse = if alpha > 0.0 { 1.0 / alpha } else { 0.0 }
    pixels[index * 4] = filter_byte(buffer[index * 4] * inverse)
    pixels[index * 4 + 1] = filter_byte(buffer[index * 4 + 1] * inverse)
    pixels[index * 4 + 2] = filter_byte(buffer[index * 4 + 2] * inverse)
    pixels[index * 4 + 3] = filter_byte(alpha * 255.0)
  }
}

///|
/// Applies a CPU filter in place, like p5's `filter()` on a graphics buffer.
pub fn Image::filter(self : Image, filter : Filter) -> Unit {
  match filter {
    Threshold(level) => filter_threshold(self.pixels, level)
    Gray => filter_gray(self.pixels)
    Opaque => filter_opaque(self.pixels)
    Invert => filter_invert(self.pixels)
    Posterize(levels) => filter_posterize(self.pixels, levels)
    Blur(radius) => filter_blur(self.pixels, self.width_, radius)
    Erode => filter_morph(self.pixels, self.width_, false)
    Dilate => filter_morph(self.pixels, self.width_, true)
  }
}

///|
/// Returns a tinted copy (RGB multiplied by `tint`; alpha multiplied too).
pub fn Image::tinted(self : Image, tint : Color) -> Image {
  let output = self.copy()
  let mut index = 0
  while index + 3 < output.pixels.length() {
    output.pixels[index] = filter_byte(
      output.pixels[index].to_uint().to_double() * tint.r,
    )
    output.pixels[index + 1] = filter_byte(
      output.pixels[index + 1].to_uint().to_double() * tint.g,
    )
    output.pixels[index + 2] = filter_byte(
      output.pixels[index + 2].to_uint().to_double() * tint.b,
    )
    output.pixels[index + 3] = filter_byte(
      output.pixels[index + 3].to_uint().to_double() * tint.a,
    )
    index = index + 4
  }
  output
}
