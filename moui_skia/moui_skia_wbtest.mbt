///|
test "geometry default values follow skia empty conventions" {
  let point : IPoint = Default::default()
  let size : Size = Default::default()
  let irect : IRect = Default::default()
  let rect : Rect = Default::default()
  assert_true(point.is_zero())
  assert_true(size.is_empty())
  assert_true(irect.is_empty())
  assert_true(rect.is_empty())
}

///|
test "rect join ignores empty input" {
  let rect = Rect::from_xywh(1, 2, 3, 4)
  assert_true(Rect::empty().join(rect) == rect)
  assert_true(rect.join(Rect::empty()) == rect)
}

///|
test "color info opacity combines alpha and storage type" {
  assert_true(ColorInfo::new(color_type=RGB565, alpha_type=Premul).is_opaque())
  assert_true(
    ColorInfo::new(color_type=RGBA8888, alpha_type=Opaque).is_opaque(),
  )
  assert_true(
    !ColorInfo::new(color_type=RGBA8888, alpha_type=Premul).is_opaque(),
  )
}

///|
test "render frame validation reports missing present command" {
  let target = SurfaceTargetDescriptor::window_n32_premul(ISize::new(8, 8))
  let command_list = RenderCommandList::new(
    RenderPassDescriptor::for_target(target),
  )
  let frame : RenderFrameDescriptor = {
    target,
    command_list,
    resource_plan: RendererResourcePlan::empty(),
    stats: command_list.stats(),
    touched_bounds: command_list.touched_bounds(),
  }
  assert_true(frame.needs_present())
  assert_true(!frame.has_present())
  assert_true(frame.validation_status() == FrameMissingPresent)
  assert_true(!frame.is_ready())
}
