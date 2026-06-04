///|
#cfg(any(target="native", target="llvm"))
#borrow(message)
extern "c" fn smoke_mark(message : Bytes) -> Unit = "skia_mbt_native_smoke_mark"

///|
#cfg(not(any(target="native", target="llvm")))
fn smoke_mark(message : Bytes) -> Unit {
  ignore(message)
}

///|
fn fail_smoke(message : String) -> Unit {
  println(message)
  abort("native smoke test failed")
}

///|
fn assert_pixel(
  pixmap : @skia.Pixmap,
  point : @skia.IPoint,
  b0 : Byte,
  b1 : Byte,
  b2 : Byte,
  b3 : Byte,
) -> Unit {
  let expected = Bytes::from_array([b0, b1, b2, b3])
  if !pixmap.matches_sample(point, expected) {
    println(
      "unexpected pixel at " + point.x.to_string() + "," + point.y.to_string(),
    )
    println("expected")
    println(
      b0.to_hex() + " " + b1.to_hex() + " " + b2.to_hex() + " " + b3.to_hex(),
    )
    println("actual")
    match pixmap.sample(point) {
      None => println("missing")
      Some(actual) =>
        if actual.length() >= 4 {
          println(
            actual[0].to_hex() +
            " " +
            actual[1].to_hex() +
            " " +
            actual[2].to_hex() +
            " " +
            actual[3].to_hex(),
          )
        } else {
          println("short sample")
        }
    }
    fail_smoke("unexpected pixel value in native smoke test")
  }
}

///|
fn assert_png_signature(bytes : Bytes) -> Unit {
  if bytes.length() < 8 {
    fail_smoke("encoded PNG data is too small")
  }
  if bytes[0] != 0x89 ||
    bytes[1] != 0x50 ||
    bytes[2] != 0x4e ||
    bytes[3] != 0x47 ||
    bytes[4] != 0x0d ||
    bytes[5] != 0x0a ||
    bytes[6] != 0x1a ||
    bytes[7] != 0x0a {
    fail_smoke("encoded image does not have a PNG signature")
  }
}

///|
fn assert_smoke_pixels(pixmap : @skia.Pixmap) -> Unit {
  assert_pixel(pixmap, @skia.IPoint::new(0, 0), 0xff, 0xff, 0xff, 0xff)
  assert_pixel(pixmap, @skia.IPoint::new(8, 8), 0xff, 0x00, 0x00, 0xff)
  assert_pixel(pixmap, @skia.IPoint::new(22, 8), 0x00, 0xff, 0x00, 0xff)
  assert_pixel(pixmap, @skia.IPoint::new(8, 22), 0x00, 0x00, 0xff, 0xff)
}

///|
fn smoke_text_bytes() -> Bytes {
  Bytes::from_array([0x53, 0x6b, 0x69, 0x61])
}
