///|
fn clamp_int(v : Int, lo : Int, hi : Int) -> Int {
  if v < lo {
    lo
  } else if v > hi {
    hi
  } else {
    v
  }
}

///|
fn get_pixel(
  src : FixedArray[Byte],
  width : Int,
  height : Int,
  x : Int,
  y : Int,
) -> (Int, Int, Int, Int) {
  let cx = clamp_int(x, 0, width - 1)
  let cy = clamp_int(y, 0, height - 1)
  let idx = (cy * width + cx) * 4
  (
    src[idx].to_int(),
    src[idx + 1].to_int(),
    src[idx + 2].to_int(),
    src[idx + 3].to_int(),
  )
}

///|
fn clamp_to_byte(v : Double) -> Byte {
  if v < 0.0 {
    b'\x00'
  } else if v > 255.0 {
    b'\xFF'
  } else {
    v.to_int().to_byte()
  }
}

///|
fn cubic_weight(t : Double) -> Double {
  let a = -0.5
  let abs_t = if t < 0.0 { -t } else { t }
  if abs_t <= 1.0 {
    (a + 2.0) * abs_t * abs_t * abs_t - (a + 3.0) * abs_t * abs_t + 1.0
  } else if abs_t <= 2.0 {
    a * abs_t * abs_t * abs_t -
    5.0 * a * abs_t * abs_t +
    8.0 * a * abs_t -
    4.0 * a
  } else {
    0.0
  }
}

///|
fn resize_nearest(
  img : ImageData,
  new_width : Int,
  new_height : Int,
) -> ImageData {
  let src = img.data.to_fixedarray()
  let src_w = img.width
  let src_h = img.height
  let buf = FixedArray::make(new_width * new_height * 4, b'\x00')
  for dy in 0..<new_height {
    // (dy * 2 + 1) * src_h / (new_height * 2) = center-to-center mapping
    let sy = clamp_int((dy * 2 + 1) * src_h / (new_height * 2), 0, src_h - 1)
    let src_row = sy * src_w * 4
    for dx in 0..<new_width {
      let sx = clamp_int((dx * 2 + 1) * src_w / (new_width * 2), 0, src_w - 1)
      let si = src_row + sx * 4
      let di = (dy * new_width + dx) * 4
      buf[di] = src[si]
      buf[di + 1] = src[si + 1]
      buf[di + 2] = src[si + 2]
      buf[di + 3] = src[si + 3]
    }
  }
  { width: new_width, height: new_height, data: Bytes::from_array(buf) }
}

///|
fn resize_bilinear(
  img : ImageData,
  new_width : Int,
  new_height : Int,
) -> ImageData {
  let src = img.data.to_fixedarray()
  let src_w = img.width.to_double()
  let src_h = img.height.to_double()
  let dst_w = new_width.to_double()
  let dst_h = new_height.to_double()
  let buf = FixedArray::make(new_width * new_height * 4, b'\x00')
  for dy in 0..<new_height {
    for dx in 0..<new_width {
      let src_x = (dx.to_double() + 0.5) * src_w / dst_w - 0.5
      let src_y = (dy.to_double() + 0.5) * src_h / dst_h - 0.5
      let x0 = src_x.to_int() - (if src_x < 0.0 { 1 } else { 0 })
      let y0 = src_y.to_int() - (if src_y < 0.0 { 1 } else { 0 })
      let x1 = x0 + 1
      let y1 = y0 + 1
      let fx = src_x - x0.to_double()
      let fy = src_y - y0.to_double()
      let (r00, g00, b00, a00) = get_pixel(src, img.width, img.height, x0, y0)
      let (r10, g10, b10, a10) = get_pixel(src, img.width, img.height, x1, y0)
      let (r01, g01, b01, a01) = get_pixel(src, img.width, img.height, x0, y1)
      let (r11, g11, b11, a11) = get_pixel(src, img.width, img.height, x1, y1)
      let w00 = (1.0 - fx) * (1.0 - fy)
      let w10 = fx * (1.0 - fy)
      let w01 = (1.0 - fx) * fy
      let w11 = fx * fy
      let r = r00.to_double() * w00 +
        r10.to_double() * w10 +
        r01.to_double() * w01 +
        r11.to_double() * w11
      let g = g00.to_double() * w00 +
        g10.to_double() * w10 +
        g01.to_double() * w01 +
        g11.to_double() * w11
      let b = b00.to_double() * w00 +
        b10.to_double() * w10 +
        b01.to_double() * w01 +
        b11.to_double() * w11
      let a = a00.to_double() * w00 +
        a10.to_double() * w10 +
        a01.to_double() * w01 +
        a11.to_double() * w11
      let idx = (dy * new_width + dx) * 4
      buf[idx] = clamp_to_byte(r + 0.5)
      buf[idx + 1] = clamp_to_byte(g + 0.5)
      buf[idx + 2] = clamp_to_byte(b + 0.5)
      buf[idx + 3] = clamp_to_byte(a + 0.5)
    }
  }
  { width: new_width, height: new_height, data: Bytes::from_array(buf) }
}

///|
fn resize_bicubic(
  img : ImageData,
  new_width : Int,
  new_height : Int,
) -> ImageData {
  let src = img.data.to_fixedarray()
  let src_w = img.width.to_double()
  let src_h = img.height.to_double()
  let dst_w = new_width.to_double()
  let dst_h = new_height.to_double()
  let buf = FixedArray::make(new_width * new_height * 4, b'\x00')
  for dy in 0..<new_height {
    for dx in 0..<new_width {
      let src_x = (dx.to_double() + 0.5) * src_w / dst_w - 0.5
      let src_y = (dy.to_double() + 0.5) * src_h / dst_h - 0.5
      let ix = src_x.to_int() - (if src_x < 0.0 { 1 } else { 0 })
      let iy = src_y.to_int() - (if src_y < 0.0 { 1 } else { 0 })
      let fx = src_x - ix.to_double()
      let fy = src_y - iy.to_double()
      let mut r_sum = 0.0
      let mut g_sum = 0.0
      let mut b_sum = 0.0
      let mut a_sum = 0.0
      for j in -1..<=2 {
        let wy = cubic_weight(fy - j.to_double())
        for i in -1..<=2 {
          let wx = cubic_weight(fx - i.to_double())
          let w = wx * wy
          let (r, g, b, a) = get_pixel(
            src,
            img.width,
            img.height,
            ix + i,
            iy + j,
          )
          r_sum += r.to_double() * w
          g_sum += g.to_double() * w
          b_sum += b.to_double() * w
          a_sum += a.to_double() * w
        }
      }
      let idx = (dy * new_width + dx) * 4
      buf[idx] = clamp_to_byte(r_sum + 0.5)
      buf[idx + 1] = clamp_to_byte(g_sum + 0.5)
      buf[idx + 2] = clamp_to_byte(b_sum + 0.5)
      buf[idx + 3] = clamp_to_byte(a_sum + 0.5)
    }
  }
  { width: new_width, height: new_height, data: Bytes::from_array(buf) }
}

///|
pub fn resize(
  img : ImageData,
  new_width : Int,
  new_height : Int,
  resize_method : ResizeMethod,
) -> ImageData raise EncodeError {
  if new_width <= 0 || new_height <= 0 {
    raise InvalidDimensions(
      "width and height must be positive, got " +
      new_width.to_string() +
      "x" +
      new_height.to_string(),
    )
  }
  if new_width == img.width && new_height == img.height {
    let arr = img.data.to_fixedarray()
    return {
      width: img.width,
      height: img.height,
      data: Bytes::from_array(arr),
    }
  }
  match resize_method {
    Nearest => resize_nearest(img, new_width, new_height)
    Bilinear => resize_bilinear(img, new_width, new_height)
    Bicubic => resize_bicubic(img, new_width, new_height)
  }
}
