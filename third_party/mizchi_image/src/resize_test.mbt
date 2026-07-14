///|
/// Helper to create a 2x2 RGBA test image:
///   (255,0,0,255)   (0,255,0,255)
///   (0,0,255,255)   (255,255,0,255)
fn make_2x2_image() -> ImageData {
  let arr : FixedArray[Byte] = [
    b'\xFF', b'\x00', b'\x00', b'\xFF', // red
     b'\x00', b'\xFF', b'\x00', b'\xFF', // green
     b'\x00', b'\x00', b'\xFF', b'\xFF', // blue
     b'\xFF', b'\xFF', b'\x00', b'\xFF', // yellow
  ]
  { width: 2, height: 2, data: Bytes::from_array(arr) }
}

///|
fn pixel_at(img : ImageData, x : Int, y : Int) -> (Int, Int, Int, Int) {
  let idx = (y * img.width + x) * 4
  (
    img.data[idx].to_int(),
    img.data[idx + 1].to_int(),
    img.data[idx + 2].to_int(),
    img.data[idx + 3].to_int(),
  )
}

///|
test "nearest 2x2 -> 4x4" {
  let img = make_2x2_image()
  let out = resize(img, 4, 4, Nearest)
  assert_eq(out.width, 4)
  assert_eq(out.height, 4)
  // top-left 2x2 block should be red
  assert_eq(pixel_at(out, 0, 0), (255, 0, 0, 255))
  assert_eq(pixel_at(out, 1, 0), (255, 0, 0, 255))
  assert_eq(pixel_at(out, 0, 1), (255, 0, 0, 255))
  assert_eq(pixel_at(out, 1, 1), (255, 0, 0, 255))
  // top-right 2x2 block should be green
  assert_eq(pixel_at(out, 2, 0), (0, 255, 0, 255))
  assert_eq(pixel_at(out, 3, 0), (0, 255, 0, 255))
  // bottom-left 2x2 block should be blue
  assert_eq(pixel_at(out, 0, 2), (0, 0, 255, 255))
  assert_eq(pixel_at(out, 1, 2), (0, 0, 255, 255))
  // bottom-right 2x2 block should be yellow
  assert_eq(pixel_at(out, 2, 2), (255, 255, 0, 255))
  assert_eq(pixel_at(out, 3, 3), (255, 255, 0, 255))
}

///|
test "bilinear 2x2 -> 4x4" {
  let img = make_2x2_image()
  let out = resize(img, 4, 4, Bilinear)
  assert_eq(out.width, 4)
  assert_eq(out.height, 4)
  // corner pixels should be close to the original colors
  let (r, _, _, _) = pixel_at(out, 0, 0)
  assert_true(r > 180) // red-ish
  let (_, g, _, _) = pixel_at(out, 3, 0)
  assert_true(g > 180) // green-ish
  let (_, _, b, _) = pixel_at(out, 0, 3)
  assert_true(b > 180) // blue-ish
  // center pixels should be blended
  let (rc, gc, bc, _) = pixel_at(out, 1, 1)
  assert_true(rc > 30 && rc < 225)
  assert_true(gc > 30 && gc < 225)
  assert_true(bc < 200) // not dominant blue
}

///|
test "bicubic 2x2 -> 4x4" {
  let img = make_2x2_image()
  let out = resize(img, 4, 4, Bicubic)
  assert_eq(out.width, 4)
  assert_eq(out.height, 4)
  // corner pixels should be close to original
  let (r, _, _, _) = pixel_at(out, 0, 0)
  assert_true(r > 150) // red-ish
  let (_, g, _, _) = pixel_at(out, 3, 0)
  assert_true(g > 150) // green-ish
  let (_, _, b, _) = pixel_at(out, 0, 3)
  assert_true(b > 150) // blue-ish
  // alpha should stay solid
  let (_, _, _, a) = pixel_at(out, 2, 2)
  assert_eq(a, 255)
}

///|
test "identity resize" {
  let img = make_2x2_image()
  let out = resize(img, 2, 2, Nearest)
  assert_eq(out.width, img.width)
  assert_eq(out.height, img.height)
  assert_eq(out.data, img.data)
}

///|
test "downscale 4x4 -> 2x2" {
  // create a uniform 4x4 red image
  let arr = FixedArray::make(4 * 4 * 4, b'\x00')
  for i in 0..<(4 * 4) {
    arr[i * 4] = b'\xFF'
    arr[i * 4 + 3] = b'\xFF'
  }
  let img : ImageData = { width: 4, height: 4, data: Bytes::from_array(arr) }
  let out = resize(img, 2, 2, Nearest)
  assert_eq(out.width, 2)
  assert_eq(out.height, 2)
  for y in 0..<2 {
    for x in 0..<2 {
      assert_eq(pixel_at(out, x, y), (255, 0, 0, 255))
    }
  }
}

///|
test "1x1 -> 3x3" {
  let arr : FixedArray[Byte] = [b'\x80', b'\x40', b'\xC0', b'\xFF']
  let img : ImageData = { width: 1, height: 1, data: Bytes::from_array(arr) }
  // nearest should replicate the single pixel
  let out_nn = resize(img, 3, 3, Nearest)
  for y in 0..<3 {
    for x in 0..<3 {
      assert_eq(pixel_at(out_nn, x, y), (128, 64, 192, 255))
    }
  }
  // bilinear should also replicate (clamp-to-edge)
  let out_bl = resize(img, 3, 3, Bilinear)
  for y in 0..<3 {
    for x in 0..<3 {
      assert_eq(pixel_at(out_bl, x, y), (128, 64, 192, 255))
    }
  }
  // bicubic should replicate too
  let out_bc = resize(img, 3, 3, Bicubic)
  for y in 0..<3 {
    for x in 0..<3 {
      assert_eq(pixel_at(out_bc, x, y), (128, 64, 192, 255))
    }
  }
}

///|
test "invalid dimensions" {
  let img = make_2x2_image()
  let r1 : Result[ImageData, _] = try? resize(img, 0, 4, Nearest)
  assert_true(r1 is Err(_))
  let r2 : Result[ImageData, _] = try? resize(img, 4, -1, Nearest)
  assert_true(r2 is Err(_))
  let r3 : Result[ImageData, _] = try? resize(img, 0, 0, Nearest)
  assert_true(r3 is Err(_))
}

///|
test "PNG roundtrip resize" {
  let img = make_2x2_image()
  let resized = resize(img, 4, 4, Bilinear)
  let encoded = encode_png(resized)
  let decoded = decode_png(encoded)
  assert_eq(decoded.width, 4)
  assert_eq(decoded.height, 4)
  assert_eq(decoded.data, resized.data)
}
