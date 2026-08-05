///|
test "shared image placement geometry matches renderer expectations" {
  let frame = @core.Rect::new(x=10.0, y=20.0, width=100.0, height=100.0)

  let wide_contain = image_placement(
    frame,
    @core.Size::new(width=200.0, height=100.0),
    @core.ImageFit::Contain,
  )
  inspect(wide_contain.frame.origin.x, content="10")
  inspect(wide_contain.frame.origin.y, content="45")
  inspect(wide_contain.frame.size.width, content="100")
  inspect(wide_contain.frame.size.height, content="50")
  guard wide_contain.crop_axis is ImageCropAxis::None else {
    fail("expected contain to sample full source")
  }

  let tall_contain = image_placement(
    frame,
    @core.Size::new(width=100.0, height=200.0),
    @core.ImageFit::Contain,
  )
  inspect(tall_contain.frame.origin.x, content="35")
  inspect(tall_contain.frame.origin.y, content="20")
  inspect(tall_contain.frame.size.width, content="50")
  inspect(tall_contain.frame.size.height, content="100")

  let wide_cover = image_placement(
    frame,
    @core.Size::new(width=200.0, height=100.0),
    @core.ImageFit::Cover,
  )
  inspect(wide_cover.frame.origin.x, content="10")
  inspect(wide_cover.frame.origin.y, content="20")
  inspect(wide_cover.frame.size.width, content="100")
  inspect(wide_cover.frame.size.height, content="100")
  guard wide_cover.crop_axis is ImageCropAxis::Horizontal else {
    fail("expected wide cover to crop horizontally")
  }
  inspect(wide_cover.visible, content="0.5")

  let tall_cover = image_placement(
    frame,
    @core.Size::new(width=100.0, height=200.0),
    @core.ImageFit::Cover,
  )
  guard tall_cover.crop_axis is ImageCropAxis::Vertical else {
    fail("expected tall cover to crop vertically")
  }
  inspect(tall_cover.visible, content="0.5")

  let stretch = image_placement(
    frame,
    @core.Size::new(width=200.0, height=100.0),
    @core.ImageFit::Stretch,
  )
  inspect(stretch.frame.origin.x, content="10")
  inspect(stretch.frame.origin.y, content="20")
  inspect(stretch.frame.size.width, content="100")
  inspect(stretch.frame.size.height, content="100")
  guard stretch.crop_axis is ImageCropAxis::None else {
    fail("expected stretch to sample full source")
  }

  let small_scale_down = image_placement(
    frame,
    @core.Size::new(width=40.0, height=20.0),
    @core.ImageFit::ScaleDown,
  )
  inspect(small_scale_down.frame.origin.x, content="40")
  inspect(small_scale_down.frame.origin.y, content="60")
  inspect(small_scale_down.frame.size.width, content="40")
  inspect(small_scale_down.frame.size.height, content="20")

  let large_scale_down = image_placement(
    frame,
    @core.Size::new(width=200.0, height=100.0),
    @core.ImageFit::ScaleDown,
  )
  inspect(large_scale_down.frame.origin.x, content="10")
  inspect(large_scale_down.frame.origin.y, content="45")
  inspect(large_scale_down.frame.size.width, content="100")
  inspect(large_scale_down.frame.size.height, content="50")

  let fit_width_short = image_placement(
    frame,
    @core.Size::new(width=200.0, height=100.0),
    @core.ImageFit::FitWidth,
  )
  inspect(fit_width_short.frame.origin.x, content="10")
  inspect(fit_width_short.frame.origin.y, content="45")
  inspect(fit_width_short.frame.size.width, content="100")
  inspect(fit_width_short.frame.size.height, content="50")
  guard fit_width_short.crop_axis is ImageCropAxis::None else {
    fail("expected short fit-width to sample full source")
  }

  let fit_width_tall = image_placement(
    frame,
    @core.Size::new(width=100.0, height=200.0),
    @core.ImageFit::FitWidth,
  )
  inspect(fit_width_tall.frame.origin.x, content="10")
  inspect(fit_width_tall.frame.origin.y, content="20")
  inspect(fit_width_tall.frame.size.width, content="100")
  inspect(fit_width_tall.frame.size.height, content="100")
  guard fit_width_tall.crop_axis is ImageCropAxis::Vertical else {
    fail("expected tall fit-width to crop vertically")
  }
  inspect(fit_width_tall.visible, content="0.5")

  let fit_height_narrow = image_placement(
    frame,
    @core.Size::new(width=100.0, height=200.0),
    @core.ImageFit::FitHeight,
  )
  inspect(fit_height_narrow.frame.origin.x, content="35")
  inspect(fit_height_narrow.frame.origin.y, content="20")
  inspect(fit_height_narrow.frame.size.width, content="50")
  inspect(fit_height_narrow.frame.size.height, content="100")

  let fit_height_wide = image_placement(
    frame,
    @core.Size::new(width=200.0, height=100.0),
    @core.ImageFit::FitHeight,
  )
  inspect(fit_height_wide.frame.origin.x, content="10")
  inspect(fit_height_wide.frame.origin.y, content="20")
  inspect(fit_height_wide.frame.size.width, content="100")
  inspect(fit_height_wide.frame.size.height, content="100")
  guard fit_height_wide.crop_axis is ImageCropAxis::Horizontal else {
    fail("expected wide fit-height to crop horizontally")
  }
  inspect(fit_height_wide.visible, content="0.5")

  let degenerate = image_placement(
    frame,
    @core.Size::new(width=0.0, height=200.0),
    @core.ImageFit::Cover,
  )
  inspect(degenerate.frame.origin.x, content="10")
  inspect(degenerate.frame.origin.y, content="20")
  inspect(degenerate.frame.size.width, content="100")
  inspect(degenerate.frame.size.height, content="100")
  guard degenerate.crop_axis is ImageCropAxis::None else {
    fail("expected degenerate placement to avoid source crop")
  }
}
