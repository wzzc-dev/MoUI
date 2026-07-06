///|
test "sun image placement records contain cover and axis-fit sampling geometry" {
  let frame = @core.Rect::new(x=10.0, y=20.0, width=100.0, height=100.0)

  let wide_contain = sun_image_placement(
    frame,
    @core.Size::new(width=200.0, height=100.0),
    @core.ImageFit::Contain,
  )
  inspect(wide_contain.frame.origin.x, content="10")
  inspect(wide_contain.frame.origin.y, content="45")
  inspect(wide_contain.frame.size.width, content="100")
  inspect(wide_contain.frame.size.height, content="50")
  guard wide_contain.src_rect is None else {
    fail("expected contain to sample full source")
  }

  let tall_contain = sun_image_placement(
    frame,
    @core.Size::new(width=100.0, height=200.0),
    @core.ImageFit::Contain,
  )
  inspect(tall_contain.frame.origin.x, content="35")
  inspect(tall_contain.frame.origin.y, content="20")
  inspect(tall_contain.frame.size.width, content="50")
  inspect(tall_contain.frame.size.height, content="100")
  guard tall_contain.src_rect is None else {
    fail("expected contain to sample full source")
  }

  let wide_cover = sun_image_placement(
    frame,
    @core.Size::new(width=200.0, height=100.0),
    @core.ImageFit::Cover,
  )
  inspect(wide_cover.frame.origin.x, content="10")
  inspect(wide_cover.frame.origin.y, content="20")
  inspect(wide_cover.frame.size.width, content="100")
  inspect(wide_cover.frame.size.height, content="100")
  guard wide_cover.src_rect is Some(wide_cover_src) else {
    fail("expected wide cover source crop")
  }
  assert_true(
    wide_cover_src ==
    @sun_graphics.PixelRect::new(x=50, y=0, width=100, height=100),
  )

  let tall_cover = sun_image_placement(
    frame,
    @core.Size::new(width=100.0, height=200.0),
    @core.ImageFit::Cover,
  )
  guard tall_cover.src_rect is Some(tall_cover_src) else {
    fail("expected tall cover source crop")
  }
  assert_true(
    tall_cover_src ==
    @sun_graphics.PixelRect::new(x=0, y=50, width=100, height=100),
  )

  let stretch = sun_image_placement(
    frame,
    @core.Size::new(width=200.0, height=100.0),
    @core.ImageFit::Stretch,
  )
  inspect(stretch.frame.origin.x, content="10")
  inspect(stretch.frame.origin.y, content="20")
  inspect(stretch.frame.size.width, content="100")
  inspect(stretch.frame.size.height, content="100")
  guard stretch.src_rect is None else {
    fail("expected stretch to sample full source")
  }

  let small_scale_down = sun_image_placement(
    frame,
    @core.Size::new(width=40.0, height=20.0),
    @core.ImageFit::ScaleDown,
  )
  inspect(small_scale_down.frame.origin.x, content="40")
  inspect(small_scale_down.frame.origin.y, content="60")
  inspect(small_scale_down.frame.size.width, content="40")
  inspect(small_scale_down.frame.size.height, content="20")
  guard small_scale_down.src_rect is None else {
    fail("expected small scale-down to sample full source")
  }

  let large_scale_down = sun_image_placement(
    frame,
    @core.Size::new(width=200.0, height=100.0),
    @core.ImageFit::ScaleDown,
  )
  inspect(large_scale_down.frame.origin.x, content="10")
  inspect(large_scale_down.frame.origin.y, content="45")
  inspect(large_scale_down.frame.size.width, content="100")
  inspect(large_scale_down.frame.size.height, content="50")
  guard large_scale_down.src_rect is None else {
    fail("expected large scale-down contain path to sample full source")
  }

  let fit_width_short = sun_image_placement(
    frame,
    @core.Size::new(width=200.0, height=100.0),
    @core.ImageFit::FitWidth,
  )
  inspect(fit_width_short.frame.origin.x, content="10")
  inspect(fit_width_short.frame.origin.y, content="45")
  inspect(fit_width_short.frame.size.width, content="100")
  inspect(fit_width_short.frame.size.height, content="50")
  guard fit_width_short.src_rect is None else {
    fail("expected fit-width short image to sample full source")
  }

  let fit_width_tall = sun_image_placement(
    frame,
    @core.Size::new(width=100.0, height=200.0),
    @core.ImageFit::FitWidth,
  )
  inspect(fit_width_tall.frame.origin.x, content="10")
  inspect(fit_width_tall.frame.origin.y, content="20")
  inspect(fit_width_tall.frame.size.width, content="100")
  inspect(fit_width_tall.frame.size.height, content="100")
  guard fit_width_tall.src_rect is Some(fit_width_tall_src) else {
    fail("expected tall fit-width source crop")
  }
  assert_true(
    fit_width_tall_src ==
    @sun_graphics.PixelRect::new(x=0, y=50, width=100, height=100),
  )

  let fit_height_narrow = sun_image_placement(
    frame,
    @core.Size::new(width=100.0, height=200.0),
    @core.ImageFit::FitHeight,
  )
  inspect(fit_height_narrow.frame.origin.x, content="35")
  inspect(fit_height_narrow.frame.origin.y, content="20")
  inspect(fit_height_narrow.frame.size.width, content="50")
  inspect(fit_height_narrow.frame.size.height, content="100")
  guard fit_height_narrow.src_rect is None else {
    fail("expected fit-height narrow image to sample full source")
  }

  let fit_height_wide = sun_image_placement(
    frame,
    @core.Size::new(width=200.0, height=100.0),
    @core.ImageFit::FitHeight,
  )
  inspect(fit_height_wide.frame.origin.x, content="10")
  inspect(fit_height_wide.frame.origin.y, content="20")
  inspect(fit_height_wide.frame.size.width, content="100")
  inspect(fit_height_wide.frame.size.height, content="100")
  guard fit_height_wide.src_rect is Some(fit_height_wide_src) else {
    fail("expected wide fit-height source crop")
  }
  assert_true(
    fit_height_wide_src ==
    @sun_graphics.PixelRect::new(x=50, y=0, width=100, height=100),
  )

  let degenerate = sun_image_placement(
    frame,
    @core.Size::new(width=0.0, height=200.0),
    @core.ImageFit::Cover,
  )
  inspect(degenerate.frame.origin.x, content="10")
  inspect(degenerate.frame.origin.y, content="20")
  inspect(degenerate.frame.size.width, content="100")
  inspect(degenerate.frame.size.height, content="100")
  guard degenerate.src_rect is None else {
    fail("expected degenerate placement to avoid source crop")
  }
}

///|
test "sun renderer dispose clears cached image resources and records disposal" {
  let source = sun_image_placement_wbtest_png_data_uri()
  let target = SunPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=4.0, height=4.0),
    ),
    target,
  )
  renderer.render([
    @core.DrawCommand::DrawImage(@core.ImageRun::{
      source,
      frame: @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      opacity: 1.0,
      fit: @core.ImageFit::Contain,
    }),
  ])
  assert_true(renderer.resources.get_image_cache().get(source) is Some(_))
  guard renderer.image_lifecycle.lookup(source) is Some(ready) else {
    fail("expected ready Sun image lifecycle record before dispose")
  }
  assert_true(ready.status == @render.ImageResourceStatus::ImageReady)
  renderer.dispose()
  assert_true(renderer.resources.get_image_cache().get(source) is None)
  guard renderer.image_lifecycle.lookup(source) is Some(disposed) else {
    fail("expected disposed Sun image lifecycle record after dispose")
  }
  assert_true(disposed.status == @render.ImageResourceStatus::ImageDisposed)
  inspect(renderer.image_resources().length(), content="1")
}

///|
fn sun_image_placement_wbtest_png_data_uri() -> String {
  "data:image/png;base64," +
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg=="
}
