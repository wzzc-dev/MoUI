///|
test "Pixmap::new creates pixmap with correct dimensions" {
  let pixmap = Pixmap::new(100, 50)
  assert_eq(pixmap.get_width(), 100)
  assert_eq(pixmap.get_height(), 50)
}

///|
test "Pixmap::set_pixel and get_pixel" {
  let pixmap = Pixmap::new(10, 10)
  let color = Color::new(r=255, g=0, b=0)
  pixmap.set_pixel(5, 5, color)
  let got = pixmap.get_pixel(5, 5)
  assert_eq(got, color)
}

///|
test "Pixmap::copy duplicates raw pixel storage" {
  let pixmap = Pixmap::new(2, 1)
  pixmap.set_pixel(0, 0, Color::red())
  let copy = pixmap.copy()
  assert_eq(copy.get_width(), 2)
  assert_eq(copy.get_height(), 1)
  assert_eq(copy.get_pixel(0, 0), Color::red())
  let copy_pixels = copy.get_pixels()
  copy_pixels[0] = 0
  assert_eq(pixmap.get_pixel(0, 0), Color::red())
  assert_eq(copy.get_pixel(0, 0), Color::new(r=0, g=0, b=0, a=255))
}

///|
test "Pixmap::checksum reports deterministic raw byte checksum" {
  let pixmap = Pixmap::new(2, 1)
  pixmap.set_pixel(0, 0, Color::new(r=1, g=2, b=3, a=4))
  pixmap.set_pixel(1, 0, Color::new(r=5, g=6, b=7, a=8))
  assert_eq(pixmap.checksum(), 204)
}
