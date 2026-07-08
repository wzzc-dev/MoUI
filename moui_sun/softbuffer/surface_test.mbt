///|
test "NativeSurface exposes size and handle" {
  let surface = NativeSurface::new(42, 3, 2)
  assert_eq(surface.get_width(), 3)
  assert_eq(surface.get_height(), 2)
  assert_eq(surface.handle(), 42)
  surface.resize(4, 5)
  assert_eq(surface.get_width(), 4)
  assert_eq(surface.get_height(), 5)
}

///|
test "NativeSurface normalizes invalid stored dimensions" {
  let count = Ref(0)
  let surface = NativeSurface::new(42, -2, 3).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })
  assert_eq(surface.get_width(), 0)
  assert_eq(surface.get_height(), 3)
  assert_eq(surface.handle(), 42)

  let pixels : FixedArray[Byte] = FixedArray::make(12, 0)
  assert_true(
    surface.present(pixels) ==
    Err(@graphics.PresentError::InvalidDimensions(0, 3)),
  )
  assert_eq(count.val, 0)

  surface.resize(-4, -5)
  assert_eq(surface.get_width(), 0)
  assert_eq(surface.get_height(), 0)
  let empty_pixels : FixedArray[Byte] = FixedArray::make(0, 0)
  assert_true(
    surface.present(empty_pixels) ==
    Err(@graphics.PresentError::InvalidDimensions(0, 0)),
  )
  assert_eq(count.val, 0)

  surface.resize(2, 1)
  assert_eq(surface.get_width(), 2)
  assert_eq(surface.get_height(), 1)
  let valid_pixels : FixedArray[Byte] = FixedArray::make(8, 0)
  assert_true(surface.present(valid_pixels) == Ok(()))
  assert_eq(count.val, 1)
}

///|
test "NativeSurface syncs RenderFrame dimensions" {
  let surface = NativeSurface::new(42, 1, 1)
  let frame = @graphics.RenderFrame::new(3, 2)
  assert_true(!surface.matches_frame(frame))
  assert_true(surface.sync_frame_size(frame))
  assert_true(surface.matches_frame(frame))
  assert_eq(surface.get_width(), 3)
  assert_eq(surface.get_height(), 2)
  assert_true(!surface.sync_frame_size(frame))

  ignore(frame.resize(4, 1))
  assert_true(!surface.matches_frame(frame))
  assert_true(surface.sync_frame_size(frame))
  assert_true(surface.matches_frame(frame))
  assert_eq(surface.get_width(), 4)
  assert_eq(surface.get_height(), 1)
}

///|
test "NativeSurface validates present parameters" {
  let surface = NativeSurface::new(42, 2, 2)
  let pixels : FixedArray[Byte] = FixedArray::make(16, 0)
  assert_true(
    surface.present_pixels(0, 2, 8, pixels) ==
    Err(@graphics.PresentError::InvalidDimensions(0, 2)),
  )
  assert_true(
    surface.present_pixels(1, 2, 4, pixels) ==
    Err(@graphics.PresentError::SizeMismatch(2, 2, 1, 2)),
  )
  assert_true(
    surface.present_pixels_rect(2, 1, 1, 1, 4, pixels) ==
    Err(@graphics.PresentError::RectOutOfBounds(2, 1, 1, 1, 2, 2)),
  )
  assert_true(
    surface.present_pixels(2, 2, 4, pixels) ==
    Err(@graphics.PresentError::InvalidRowBytes(4, 8)),
  )
  assert_true(
    surface.present_pixels_rect(0, 0, 2, 2, 4, pixels) ==
    Err(@graphics.PresentError::InvalidRowBytes(4, 8)),
  )
  let short_pixels : FixedArray[Byte] = FixedArray::make(15, 0)
  assert_true(
    surface.present_pixels(2, 2, 8, short_pixels) ==
    Err(@graphics.PresentError::PixelBufferTooSmall(15, 16)),
  )
  let short_rect_pixels : FixedArray[Byte] = FixedArray::make(19, 0)
  assert_true(
    surface.present_pixels_rect(0, 0, 2, 2, 12, short_rect_pixels) ==
    Err(@graphics.PresentError::PixelBufferTooSmall(19, 20)),
  )
}

///|
test "NativeSurface dispatches through graphics Surface trait" {
  let surface = NativeSurface::new(42, 2, 2)
  let pixels : FixedArray[Byte] = FixedArray::make(16, 0)
  let result = @graphics.present_pixels(surface, 2, 2, 4, pixels)
  assert_true(result == Err(@graphics.PresentError::InvalidRowBytes(4, 8)))
  let rect_result = @graphics.present_pixels_rect(
    surface, 1, 1, 1, 1, 4, pixels,
  )
  assert_true(rect_result == Ok(()))
}

///|
test "NativeSurface accepts padded row bytes through shared validation" {
  let surface = NativeSurface::new(42, 1, 2)
  let pixels : FixedArray[Byte] = FixedArray::make(12, 0)
  let result = surface.present_pixels(1, 2, 8, pixels)
  assert_true(result == Ok(()))
}

///|
test "NativeSurface::present uses validated full-frame present path" {
  let count = Ref(0)
  let surface = NativeSurface::new(42, 2, 2).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })
  let pixels : FixedArray[Byte] = FixedArray::make(16, 0)
  assert_true(surface.present(pixels) == Ok(()))
  assert_eq(count.val, 1)

  let short_pixels : FixedArray[Byte] = FixedArray::make(15, 0)
  assert_true(
    surface.present(short_pixels) ==
    Err(@graphics.PresentError::PixelBufferTooSmall(15, 16)),
  )
  assert_eq(count.val, 1)

  let zero = NativeSurface::new(42, 0, 2).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })
  assert_true(
    zero.present(pixels) == Err(@graphics.PresentError::InvalidDimensions(0, 2)),
  )
  assert_eq(count.val, 1)
}

///|
test "NativeSurface calls pre-present hook only after validation" {
  let count = Ref(0)
  let surface = NativeSurface::new(42, 2, 2).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })
  let pixels : FixedArray[Byte] = FixedArray::make(16, 0)

  assert_true(
    surface.present_pixels(2, 2, 4, pixels) ==
    Err(@graphics.PresentError::InvalidRowBytes(4, 8)),
  )
  assert_eq(count.val, 0)

  assert_true(
    surface.present_pixels_rect(0, 0, 2, 2, 4, pixels) ==
    Err(@graphics.PresentError::InvalidRowBytes(4, 8)),
  )
  assert_eq(count.val, 0)

  let short_rect_pixels : FixedArray[Byte] = FixedArray::make(19, 0)
  assert_true(
    surface.present_pixels_rect(0, 0, 2, 2, 12, short_rect_pixels) ==
    Err(@graphics.PresentError::PixelBufferTooSmall(19, 20)),
  )
  assert_eq(count.val, 0)

  assert_true(surface.present_pixels(2, 2, 8, pixels) == Ok(()))
  assert_eq(count.val, 1)

  assert_true(surface.present_pixels_rect(1, 1, 1, 1, 4, pixels) == Ok(()))
  assert_eq(count.val, 2)

  let padded : FixedArray[Byte] = FixedArray::make(12, 0)
  assert_true(surface.present_pixels_rect(0, 0, 1, 2, 8, padded) == Ok(()))
  assert_eq(count.val, 3)

  let without_hook = surface.clear_pre_present_hook()
  assert_true(without_hook.present_pixels(2, 2, 8, pixels) == Ok(()))
  assert_eq(count.val, 3)
}

///|
test "NativeSurface builds from RenderFrame dimensions" {
  let frame = @graphics.RenderFrame::new(3, 2)
  let surface = NativeSurface::from_frame(42, frame)
  assert_eq(surface.handle(), 42)
  assert_eq(surface.get_width(), 3)
  assert_eq(surface.get_height(), 2)
}

///|
test "NativeSurface present_frame_all calls hook and consumes full-frame lifecycle" {
  let count = Ref(0)
  let frame = @graphics.RenderFrame::new(2, 1)
  let layer = @graphics.Layer::new(2, 1)
  layer.clear(@graphics.Color::white())
  layer.get_canvas().draw_pixel(1, 0, @graphics.Color::blue())
  ignore(frame.get_layer_tree().add_layer(layer))

  let surface = NativeSurface::from_frame(42, frame).with_pre_present_hook(fn() {
    count.val = count.val + 1
  })
  assert_eq(count.val, 0)
  assert_true(surface.present_frame_dirty(frame) == Ok(1))
  assert_eq(count.val, 1)
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(0, 0),
    @graphics.Color::white(),
  )
  assert_eq(
    frame.get_canvas().get_pixmap().get_pixel(1, 0),
    @graphics.Color::blue(),
  )
  assert_true(!frame.has_dirty())
  assert_true(surface.present_frame_dirty(frame) == Ok(0))
  assert_eq(count.val, 1)
  assert_true(surface.present_frame_all(frame) == Ok(1))
  assert_eq(count.val, 2)
  assert_true(!frame.has_dirty())
  assert_true(surface.present_frame_all(frame) == Ok(1))
  assert_eq(count.val, 3)
  assert_true(!frame.has_dirty())
}
