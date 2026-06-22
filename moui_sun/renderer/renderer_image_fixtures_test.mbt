///|
fn make_renderer_test_nine_patch_source() -> @graphics.Pixmap {
  let src = @graphics.Pixmap::new(3, 3)
  src.set_pixel(0, 0, @graphics.Color::new(r=10, g=0, b=0))
  src.set_pixel(1, 0, @graphics.Color::new(r=20, g=0, b=0))
  src.set_pixel(2, 0, @graphics.Color::new(r=30, g=0, b=0))
  src.set_pixel(0, 1, @graphics.Color::new(r=40, g=0, b=0))
  src.set_pixel(1, 1, @graphics.Color::new(r=50, g=0, b=0))
  src.set_pixel(2, 1, @graphics.Color::new(r=60, g=0, b=0))
  src.set_pixel(0, 2, @graphics.Color::new(r=70, g=0, b=0))
  src.set_pixel(1, 2, @graphics.Color::new(r=80, g=0, b=0))
  src.set_pixel(2, 2, @graphics.Color::new(r=90, g=0, b=0))
  src
}

///|
fn make_renderer_test_tile_source() -> @graphics.Pixmap {
  let src = @graphics.Pixmap::new(2, 1)
  src.set_pixel(0, 0, @graphics.Color::red())
  src.set_pixel(1, 0, @graphics.Color::green())
  src
}

///|
fn must_renderer_test_png_bytes(pixmap : @graphics.Pixmap) -> Bytes {
  match pixmap.to_png_bytes() {
    Ok(bytes) => bytes
    Err(_) => abort("expected PNG fixture encode")
  }
}

///|
fn make_renderer_test_bicubic_source() -> @graphics.Pixmap {
  let src = @graphics.Pixmap::new(4, 1)
  src.set_pixel(0, 0, @graphics.Color::black())
  src.set_pixel(1, 0, @graphics.Color::red())
  src.set_pixel(2, 0, @graphics.Color::black())
  src.set_pixel(3, 0, @graphics.Color::red())
  src
}
