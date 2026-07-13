///|
test "skia picture producer records platform view pixels before handoff" {
  guard skia_available() else { return () }
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=8.0, height=8.0),
    ),
    SkiaPresentTarget::new(description="platform-view-picture", present=_ => {
      true
    }),
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  renderer.set_platform_view_draw_fn(
    Some(() => {
      renderer.draw_platform_view_pixels(
        [0x00, 0x00, 0x00, 0xff],
        1,
        1,
        4,
        2.0,
        2.0,
        4.0,
        4.0,
      )
    }),
  )
  let recorded = renderer.record_frame_picture(
    skia_test_draw_frame([@core.DrawCommand::Clear(@core.Color::white())]),
  )
  renderer.set_platform_view_draw_fn(None)
  guard recorded is Some(picture) else {
    fail("expected platform view pixels to remain on the GPU Picture path")
  }
  guard renderer.surface.canvas() is Some(canvas) else {
    fail("expected raster verification canvas")
  }
  canvas.clear(@moui_skia.Color::white())
  canvas.draw_picture(picture)
  assert_true(renderer.surface.flush_and_submit())
  guard renderer.surface.read_pixels(
      bounds=@moui_skia.IRect::from_xywh(3, 3, 1, 1),
    )
    is Some(pixmap) else {
    fail("expected recorded platform view pixel readback")
  }
  guard pixmap.sample(@moui_skia.IPoint::new(0, 0)) is Some(pixel) else {
    fail("expected platform view pixel sample")
  }
  assert_true(pixel[0] < 32 && pixel[1] < 32 && pixel[2] < 32)
  assert_eq(pixel[3], 0xff)
  renderer.dispose()
}
