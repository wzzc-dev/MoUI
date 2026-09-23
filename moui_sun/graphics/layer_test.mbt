///|
test "Layer exposes local and translated bounds" {
  let layer = @graphics.Layer::new(4, 3).set_position(10, 20)
  assert_true(
    layer.bounds() == @graphics.PixelRect::new(x=0, y=0, width=4, height=3),
  )
  assert_true(
    layer.translated_bounds() ==
    @graphics.PixelRect::new(x=10, y=20, width=4, height=3),
  )

  ignore(layer.resize(-1, 2))
  assert_true(
    layer.bounds() == @graphics.PixelRect::new(x=0, y=0, width=0, height=2),
  )
  assert_true(
    layer.translated_bounds() ==
    @graphics.PixelRect::new(x=10, y=20, width=0, height=2),
  )
}

///|
test "Layer tracks dirty bounds in layer and target coordinates" {
  let layer = @graphics.Layer::new(4, 3).set_position(10, 20)
  layer.get_canvas().draw_pixel(1, 2, @graphics.Color::red())
  assert_true(
    layer.dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=1, y=2, width=1, height=1)),
  )
  assert_true(
    layer.translated_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=11, y=22, width=1, height=1)),
  )
  let rects = layer.translated_dirty_rects(8)
  assert_eq(rects.length(), 1)
  assert_true(
    rects[0] == @graphics.PixelRect::new(x=11, y=22, width=1, height=1),
  )
}

///|
test "Layer exposes dirty marking helpers" {
  let layer = @graphics.Layer::new(4, 3).set_position(10, 20)
  assert_true(!layer.has_dirty())
  assert_true(layer.dirty_bounds() == None)

  layer.mark_dirty_rect(@graphics.PixelRect::new(x=2, y=1, width=5, height=2))
  assert_true(layer.has_dirty())
  assert_true(
    layer.dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=2, y=1, width=2, height=2)),
  )
  assert_true(
    layer.translated_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=12, y=21, width=2, height=2)),
  )

  layer.clear_dirty_region()
  layer.mark_all_dirty()
  assert_true(
    layer.dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=4, height=3)),
  )

  let empty = @graphics.Layer::new(0, 2)
  empty.clear_dirty_region()
  empty.mark_all_dirty()
  empty.mark_dirty_rect(@graphics.PixelRect::new(x=0, y=0, width=1, height=1))
  assert_true(!empty.has_dirty())
}

///|
test "Layer style mutators mark clean cache dirty only on change" {
  let bounds = @graphics.PixelRect::new(x=0, y=0, width=1, height=1)

  let blend = @graphics.Layer::new(1, 1)
  blend.get_canvas().draw_pixel(0, 0, @graphics.Color::red())
  blend.clear_dirty_region()
  ignore(blend.set_blend_mode(SourceOver))
  assert_true(!blend.has_dirty())
  ignore(blend.set_blend_mode(Screen))
  assert_true(blend.dirty_bounds() == Some(bounds))

  let filter = @graphics.Layer::new(1, 1)
  filter.get_canvas().draw_pixel(0, 0, @graphics.Color::red())
  filter.clear_dirty_region()
  ignore(filter.clear_filter())
  assert_true(!filter.has_dirty())
  let invert = @graphics.PaintFilter::invert()
  ignore(filter.set_filter(invert))
  assert_true(filter.dirty_bounds() == Some(bounds))
  filter.clear_dirty_region()
  ignore(filter.set_filter(invert))
  assert_true(!filter.has_dirty())
  ignore(filter.clear_filter())
  assert_true(filter.dirty_bounds() == Some(bounds))

  let identity_filter = @graphics.Layer::new(1, 1)
  identity_filter.get_canvas().draw_pixel(0, 0, @graphics.Color::red())
  identity_filter.clear_dirty_region()
  ignore(identity_filter.set_filter(@graphics.PaintFilter::identity()))
  assert_true(!identity_filter.has_dirty())
  match identity_filter.get_filter() {
    Some(value) => assert_true(value.is_identity())
    None => abort("expected stored identity filter")
  }
  ignore(identity_filter.clear_filter())
  assert_true(!identity_filter.has_dirty())

  let visible_identity_replacement = @graphics.Layer::new(1, 1).set_filter(
    invert,
  )
  visible_identity_replacement
  .get_canvas()
  .draw_pixel(0, 0, @graphics.Color::red())
  visible_identity_replacement.clear_dirty_region()
  ignore(
    visible_identity_replacement.set_filter(@graphics.PaintFilter::identity()),
  )
  assert_true(visible_identity_replacement.dirty_bounds() == Some(bounds))

  let alpha_filter = make_layer_alpha_synthesizing_filter()
  let transparent_filter = @graphics.Layer::new(1, 1)
  transparent_filter.clear_dirty_region()
  ignore(transparent_filter.set_filter(alpha_filter))
  assert_true(transparent_filter.dirty_bounds() == Some(bounds))
  transparent_filter.clear_dirty_region()
  ignore(transparent_filter.set_filter(alpha_filter))
  assert_true(!transparent_filter.has_dirty())
  ignore(transparent_filter.clear_filter())
  assert_true(transparent_filter.dirty_bounds() == Some(bounds))

  let transparent_replaced_filter = @graphics.Layer::new(1, 1).set_filter(
    alpha_filter,
  )
  transparent_replaced_filter.clear_dirty_region()
  ignore(
    transparent_replaced_filter.set_filter(@graphics.PaintFilter::invert()),
  )
  assert_true(transparent_replaced_filter.dirty_bounds() == Some(bounds))

  let transparent_invisible = @graphics.Layer::new(1, 1).set_opacity(0.0)
  transparent_invisible.clear_dirty_region()
  ignore(transparent_invisible.set_filter(alpha_filter))
  assert_true(!transparent_invisible.has_dirty())

  let shader = @graphics.PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=1.0,
    y1=0.0,
    start_color=@graphics.Color::blue(),
    end_color=@graphics.Color::blue(),
  )
  let shaded = @graphics.Layer::new(1, 1)
  shaded.get_canvas().draw_pixel(0, 0, @graphics.Color::red())
  shaded.clear_dirty_region()
  ignore(shaded.clear_shader())
  assert_true(!shaded.has_dirty())
  ignore(shaded.set_shader(shader))
  assert_true(shaded.dirty_bounds() == Some(bounds))
  shaded.clear_dirty_region()
  ignore(shaded.set_shader(shader))
  assert_true(!shaded.has_dirty())
  ignore(shaded.clear_shader())
  assert_true(shaded.dirty_bounds() == Some(bounds))

  let masked_filter = @graphics.Layer::new(1, 1).set_shader(shader)
  masked_filter.clear_dirty_region()
  ignore(masked_filter.set_filter(alpha_filter))
  assert_true(!masked_filter.has_dirty())
  ignore(masked_filter.clear_filter())
  assert_true(!masked_filter.has_dirty())

  let shader_hides_filter = @graphics.Layer::new(1, 1).set_filter(alpha_filter)
  shader_hides_filter.clear_dirty_region()
  ignore(shader_hides_filter.set_shader(shader))
  assert_true(shader_hides_filter.dirty_bounds() == Some(bounds))

  let shader_reveals_filter = @graphics.Layer::new(1, 1)
    .set_shader(shader)
    .set_filter(alpha_filter)
  shader_reveals_filter.clear_dirty_region()
  ignore(shader_reveals_filter.clear_shader())
  assert_true(shader_reveals_filter.dirty_bounds() == Some(bounds))

  let faded = @graphics.Layer::new(1, 1)
  faded.get_canvas().draw_pixel(0, 0, @graphics.Color::blue())
  faded.clear_dirty_region()
  ignore(faded.set_opacity(2.0))
  assert_true(!faded.has_dirty())
  ignore(faded.set_opacity(0.5))
  assert_true(faded.dirty_bounds() == Some(bounds))
}

///|
test "Layer opacity normalizes invalid configured values" {
  let high = @graphics.Layer::new(1, 1).set_opacity(2.0)
  assert_eq(high.get_opacity(), 1.0)
  assert_true(high.is_compositable())

  let negative = @graphics.Layer::new(1, 1).set_opacity(-1.0)
  assert_eq(negative.get_opacity(), 0.0)
  assert_true(!negative.is_compositable())

  let nan = @graphics.Layer::new(1, 1).set_opacity(0.0 / 0.0)
  assert_eq(nan.get_opacity(), 0.0)
  assert_true(!nan.is_compositable())

  let cached = @graphics.Layer::new(1, 1)
  cached.get_canvas().draw_pixel(0, 0, @graphics.Color::red())
  cached.clear_dirty_region()
  ignore(cached.set_opacity(0.0 / 0.0))
  assert_eq(cached.get_opacity(), 0.0)
  assert_true(!cached.is_compositable())
  assert_true(!cached.has_dirty())
}

///|
test "Layer style dirty composition redraws clean cached pixels" {
  let blended_target = @graphics.Canvas::new(1, 1)
  blended_target.clear(@graphics.Color::blue())
  let blended = @graphics.Layer::new(1, 1)
  blended.get_canvas().draw_pixel(0, 0, @graphics.Color::red())
  blended.clear_dirty_region()
  ignore(blended.set_blend_mode(Screen))
  assert_eq(blended.composite_dirty_to(blended_target, 8), 1)
  assert_eq(
    blended_target.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=255, g=0, b=255, a=255),
  )

  let filtered_target = @graphics.Canvas::new(1, 1)
  let filtered = @graphics.Layer::new(1, 1)
  filtered.get_canvas().draw_pixel(0, 0, @graphics.Color::red())
  filtered.clear_dirty_region()
  ignore(filtered.set_filter(@graphics.PaintFilter::invert()))
  assert_eq(filtered.composite_dirty_to(filtered_target, 8), 1)
  assert_eq(
    filtered_target.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=0, g=255, b=255),
  )
  ignore(filtered.clear_filter())
  assert_eq(filtered.composite_dirty_to(filtered_target, 8), 1)
  assert_eq(
    filtered_target.get_pixmap().get_pixel(0, 0),
    @graphics.Color::red(),
  )

  let shader = @graphics.PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=1.0,
    y1=0.0,
    start_color=@graphics.Color::blue(),
    end_color=@graphics.Color::blue(),
  )
  let shaded_target = @graphics.Canvas::new(1, 1)
  let shaded = @graphics.Layer::new(1, 1)
  shaded.get_canvas().draw_pixel(0, 0, @graphics.Color::red())
  shaded.clear_dirty_region()
  ignore(shaded.set_shader(shader))
  assert_eq(shaded.composite_dirty_to(shaded_target, 8), 1)
  assert_eq(shaded_target.get_pixmap().get_pixel(0, 0), @graphics.Color::blue())
  ignore(shaded.clear_shader())
  assert_eq(shaded.composite_dirty_to(shaded_target, 8), 1)
  assert_eq(shaded_target.get_pixmap().get_pixel(0, 0), @graphics.Color::red())

  let faded_target = @graphics.Canvas::new(1, 1)
  faded_target.clear(@graphics.Color::white())
  let faded = @graphics.Layer::new(1, 1)
  faded.get_canvas().draw_pixel(0, 0, @graphics.Color::blue())
  faded.clear_dirty_region()
  ignore(faded.set_opacity(0.5))
  assert_eq(faded.composite_dirty_to(faded_target, 8), 1)
  assert_eq(
    faded_target.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=127, g=127, b=255, a=255),
  )
}

///|
test "Layer::resize preserves overlapping pixels and marks new bounds dirty" {
  let layer = @graphics.Layer::new(2, 1)
  layer.get_canvas().draw_pixel(0, 0, @graphics.Color::red())
  layer.get_canvas().draw_pixel(1, 0, @graphics.Color::blue())
  layer.clear_dirty_region()

  ignore(layer.resize(3, 2))
  assert_eq(layer.get_width(), 3)
  assert_eq(layer.get_height(), 2)
  assert_eq(layer.get_pixmap().get_pixel(0, 0), @graphics.Color::red())
  assert_eq(layer.get_pixmap().get_pixel(1, 0), @graphics.Color::blue())
  assert_eq(layer.get_pixmap().get_pixel(2, 1), @graphics.Color::transparent())
  assert_true(
    layer.dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=3, height=2)),
  )

  ignore(layer.resize(1, 1))
  assert_eq(layer.get_width(), 1)
  assert_eq(layer.get_height(), 1)
  assert_eq(layer.get_pixmap().get_pixel(0, 0), @graphics.Color::red())
  assert_true(
    layer.dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=1, height=1)),
  )
}

///|
test "Layer::resize preserves transparent RGB cache bytes" {
  let layer = @graphics.Layer::new(1, 1)
  layer.get_pixmap().set_pixel(0, 0, @graphics.Color::new(r=128, g=0, b=0, a=0))
  layer.clear_dirty_region()

  ignore(layer.resize(2, 1))
  assert_eq(
    layer.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=128, g=0, b=0, a=0),
  )
  assert_eq(layer.get_pixmap().get_pixel(1, 0), @graphics.Color::transparent())
  assert_true(
    layer.dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=2, height=1)),
  )

  let target = @graphics.Canvas::new(2, 1)
  target.clear(@graphics.Color::white())
  target.clear_dirty_region()
  layer.clear_dirty_region()
  ignore(layer.set_filter(make_layer_red_to_alpha_filter()))
  assert_true(
    layer.dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=2, height=1)),
  )

  assert_eq(layer.composite_dirty_to(target, 8), 1)
  assert_eq(
    target.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=127, g=127, b=127, a=255),
  )
  assert_eq(target.get_pixmap().get_pixel(1, 0), @graphics.Color::white())
  assert_true(
    target.get_dirty_region().bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=1, height=1)),
  )
  assert_true(!layer.has_dirty())
}

///|
test "Layer::composite_dirty_to draws only dirty cache pixels and clears dirty state" {
  let target = @graphics.Canvas::new(5, 3)
  target.clear(@graphics.Color::white())
  target.clear_dirty_region()

  let layer = @graphics.Layer::new(3, 2).set_position(1, 1)
  layer.get_canvas().draw_pixel(0, 0, @graphics.Color::red())
  layer.get_canvas().draw_pixel(2, 0, @graphics.Color::blue())

  let presented = layer.composite_dirty_to(target, 8)
  assert_eq(presented, 2)
  assert_eq(target.get_pixmap().get_pixel(1, 1), @graphics.Color::red())
  assert_eq(target.get_pixmap().get_pixel(3, 1), @graphics.Color::blue())
  assert_eq(target.get_pixmap().get_pixel(2, 1), @graphics.Color::white())
  assert_true(layer.get_dirty_region().is_empty())
  assert_true(
    target.get_dirty_region().bounds() ==
    Some(@graphics.PixelRect::new(x=1, y=1, width=3, height=1)),
  )
}

///|
test "Layer::composite_dirty_to_result reports composited bounds and cleanup" {
  let target = @graphics.Canvas::new(5, 3)
  target.clear(@graphics.Color::white())
  target.clear_dirty_region()

  let layer = @graphics.Layer::new(3, 2).set_position(1, 1)
  layer.get_canvas().draw_pixel(0, 0, @graphics.Color::red())
  layer.get_canvas().draw_pixel(2, 0, @graphics.Color::blue())

  let result = layer.composite_dirty_to_result(target, 8)
  assert_eq(result.get_composited_rect_count(), 2)
  assert_true(result.did_composite())
  assert_true(result.did_clear_dirty())
  assert_true(!result.uses_bounds_fallback())
  assert_true(
    result.get_local_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=3, height=1)),
  )
  assert_true(
    result.get_target_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=1, y=1, width=3, height=1)),
  )
  assert_eq(target.get_pixmap().get_pixel(1, 1), @graphics.Color::red())
  assert_eq(target.get_pixmap().get_pixel(3, 1), @graphics.Color::blue())
  assert_true(layer.get_dirty_region().is_empty())
}

///|
test "Layer::composite_dirty_to_result preserves skipped dirty telemetry" {
  let target = @graphics.Canvas::new(3, 1)
  target.clear(@graphics.Color::white())
  target.clear_dirty_region()

  let layer = @graphics.Layer::new(2, 1).set_position(1, 0).set_visible(false)
  layer.get_canvas().draw_pixel(0, 0, @graphics.Color::red())

  let result = layer.composite_dirty_to_result(target, 8)
  assert_eq(result.get_composited_rect_count(), 0)
  assert_true(!result.did_composite())
  assert_true(!result.did_clear_dirty())
  assert_true(!result.uses_bounds_fallback())
  assert_true(
    result.get_local_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=1, height=1)),
  )
  assert_true(
    result.get_target_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=1, y=0, width=1, height=1)),
  )
  assert_true(layer.has_dirty())
  assert_true(target.get_dirty_region().is_empty())
  assert_eq(target.get_pixmap().get_pixel(1, 0), @graphics.Color::white())
}

///|
test "Layer::composite_dirty_to uses bounds fallback over limit" {
  let target = @graphics.Canvas::new(8, 2)
  let layer = @graphics.Layer::new(8, 2)
  layer.get_canvas().draw_pixel(0, 0, @graphics.Color::red())
  layer.get_canvas().draw_pixel(3, 0, @graphics.Color::green())
  layer.get_canvas().draw_pixel(6, 0, @graphics.Color::blue())
  let result = layer.composite_dirty_to_result(target, 2)
  assert_eq(result.get_composited_rect_count(), 1)
  assert_true(result.did_composite())
  assert_true(result.did_clear_dirty())
  assert_true(result.uses_bounds_fallback())
  assert_true(
    result.get_local_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=7, height=1)),
  )
  assert_true(
    result.get_target_dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=7, height=1)),
  )
  assert_eq(target.get_pixmap().get_pixel(0, 0), @graphics.Color::red())
  assert_eq(target.get_pixmap().get_pixel(3, 0), @graphics.Color::green())
  assert_eq(target.get_pixmap().get_pixel(6, 0), @graphics.Color::blue())
  assert_true(layer.get_dirty_region().is_empty())
}

///|
test "Layer visibility and opacity control composition" {
  let hidden_target = @graphics.Canvas::new(1, 1)
  hidden_target.clear(@graphics.Color::white())
  let hidden = @graphics.Layer::new(1, 1).set_visible(false)
  assert_true(!hidden.is_compositable())
  hidden.get_canvas().draw_pixel(0, 0, @graphics.Color::red())
  assert_eq(hidden.composite_dirty_to(hidden_target, 8), 0)
  assert_eq(
    hidden_target.get_pixmap().get_pixel(0, 0),
    @graphics.Color::white(),
  )

  let target = @graphics.Canvas::new(1, 1)
  target.clear(@graphics.Color::white())
  let layer = @graphics.Layer::new(1, 1).set_opacity(0.5)
  assert_true(layer.is_compositable())
  layer.get_canvas().draw_pixel(0, 0, @graphics.Color::blue())
  assert_eq(layer.composite_dirty_to(target, 8), 1)
  assert_eq(
    target.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=127, g=127, b=255, a=255),
  )

  ignore(layer.set_opacity(0.0))
  assert_true(!layer.is_compositable())
}

///|
test "Layer blend mode controls full and dirty composition" {
  let full_target = @graphics.Canvas::new(1, 1)
  full_target.clear(@graphics.Color::blue())
  let full_layer = @graphics.Layer::new(1, 1).set_blend_mode(Screen)
  assert_true(full_layer.get_blend_mode() == Screen)
  full_layer.get_canvas().draw_pixel(0, 0, @graphics.Color::red())
  assert_eq(full_layer.composite_to(full_target), 1)
  assert_eq(
    full_target.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=255, g=0, b=255, a=255),
  )

  let dirty_target = @graphics.Canvas::new(1, 1)
  dirty_target.clear(@graphics.Color::green())
  let dirty_layer = @graphics.Layer::new(1, 1).set_blend_mode(Multiply)
  dirty_layer.get_canvas().draw_pixel(0, 0, @graphics.Color::red())
  assert_eq(dirty_layer.composite_dirty_to(dirty_target, 8), 1)
  assert_eq(dirty_target.get_pixmap().get_pixel(0, 0), @graphics.Color::black())
}

///|
test "Layer compositing keeps transparent-source Porter-Duff modes active" {
  let full_target = @graphics.Canvas::new(2, 1)
  full_target.clear(@graphics.Color::new(r=10, g=20, b=30))
  let full_layer = @graphics.Layer::new(2, 1)
    .set_opacity(0.0)
    .set_blend_mode(Clear)
  assert_true(full_layer.is_compositable())
  assert_eq(full_layer.composite_to(full_target), 1)
  assert_eq(
    full_target.get_pixmap().get_pixel(0, 0),
    @graphics.Color::transparent(),
  )
  assert_eq(
    full_target.get_pixmap().get_pixel(1, 0),
    @graphics.Color::transparent(),
  )

  let dirty_target = @graphics.Canvas::new(2, 1)
  dirty_target.clear(@graphics.Color::new(r=40, g=50, b=60))
  let dirty_layer = @graphics.Layer::new(2, 1)
    .set_opacity(0.0)
    .set_blend_mode(DestinationIn)
  dirty_layer.clear_dirty_region()
  dirty_layer.get_canvas().draw_pixel(1, 0, @graphics.Color::red())
  assert_true(dirty_layer.is_compositable())
  assert_eq(dirty_layer.composite_dirty_to(dirty_target, 8), 1)
  assert_eq(
    dirty_target.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=40, g=50, b=60),
  )
  assert_eq(
    dirty_target.get_pixmap().get_pixel(1, 0),
    @graphics.Color::transparent(),
  )
}

///|
test "Layer transparent-source blend mode marks empty cache dirty" {
  let bounds = @graphics.PixelRect::new(x=0, y=0, width=1, height=1)
  let target = @graphics.Canvas::new(1, 1)
  target.clear(@graphics.Color::new(r=10, g=20, b=30))
  target.clear_dirty_region()

  let layer = @graphics.Layer::new(1, 1).set_opacity(0.0)
  layer.clear_dirty_region()
  assert_true(!layer.has_dirty())

  ignore(layer.set_blend_mode(Clear))
  assert_true(layer.is_compositable())
  assert_true(layer.dirty_bounds() == Some(bounds))

  assert_eq(layer.composite_dirty_to(target, 8), 1)
  assert_eq(target.get_pixmap().get_pixel(0, 0), @graphics.Color::transparent())
  assert_true(layer.get_dirty_region().is_empty())
}

///|
test "Layer transparent-source blend mode deactivation marks empty cache dirty" {
  let bounds = @graphics.PixelRect::new(x=0, y=0, width=1, height=1)
  let layer = @graphics.Layer::new(1, 1).set_opacity(0.0).set_blend_mode(Clear)
  layer.clear_dirty_region()
  assert_true(layer.is_compositable())
  assert_true(!layer.has_dirty())

  ignore(layer.set_blend_mode(SourceOver))
  assert_true(!layer.is_compositable())
  assert_true(layer.dirty_bounds() == Some(bounds))
}

///|
test "Layer filter controls full and dirty composition" {
  let full_target = @graphics.Canvas::new(1, 1)
  let full_layer = @graphics.Layer::new(1, 1).set_filter(
    @graphics.PaintFilter::invert(),
  )
  assert_true(full_layer.get_filter() is Some(_))
  full_layer.get_canvas().draw_pixel(0, 0, @graphics.Color::red())
  assert_eq(full_layer.composite_to(full_target), 1)
  assert_eq(
    full_target.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=0, g=255, b=255),
  )

  let dirty_target = @graphics.Canvas::new(1, 1)
  let dirty_layer = @graphics.Layer::new(1, 1).set_filter(
    @graphics.PaintFilter::invert().then(@graphics.PaintFilter::brightness(0.5)),
  )
  dirty_layer
  .get_canvas()
  .draw_pixel(0, 0, @graphics.Color::new(r=10, g=20, b=30))
  assert_eq(dirty_layer.composite_dirty_to(dirty_target, 8), 1)
  assert_eq(
    dirty_target.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=123, g=118, b=113),
  )

  ignore(dirty_layer.clear_filter())
  assert_true(dirty_layer.get_filter() is None)
}

///|
test "Layer alpha-synthesizing filter composites transparent cache" {
  let filter = make_layer_alpha_synthesizing_filter()
  let target = @graphics.Canvas::new(1, 1)
  target.clear(@graphics.Color::white())
  target.clear_dirty_region()

  let layer = @graphics.Layer::new(1, 1)
  layer.clear_dirty_region()
  ignore(layer.set_filter(filter))
  assert_true(
    layer.dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=1, height=1)),
  )

  let result = layer.composite_dirty_to_result(target, 8)
  assert_eq(result.get_composited_rect_count(), 1)
  assert_true(result.did_composite())
  assert_true(result.did_clear_dirty())
  assert_eq(
    target.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=127, g=127, b=127, a=255),
  )
  assert_true(
    target.get_dirty_region().bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=1, height=1)),
  )
  assert_true(!layer.has_dirty())

  ignore(layer.clear_filter())
  assert_true(
    layer.dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=1, height=1)),
  )
}

///|
test "Layer color-matrix filter reveals transparent RGB cache" {
  let filter = make_layer_red_to_alpha_filter()
  let target = @graphics.Canvas::new(1, 1)
  target.clear(@graphics.Color::white())
  target.clear_dirty_region()

  let layer = @graphics.Layer::new(1, 1)
  layer.get_pixmap().set_pixel(0, 0, @graphics.Color::new(r=128, g=0, b=0, a=0))
  assert_eq(
    layer.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=128, g=0, b=0, a=0),
  )
  layer.clear_dirty_region()
  ignore(layer.set_filter(filter))
  assert_true(
    layer.dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=1, height=1)),
  )

  let result = layer.composite_dirty_to_result(target, 8)
  assert_eq(result.get_composited_rect_count(), 1)
  assert_true(result.did_composite())
  assert_true(result.did_clear_dirty())
  assert_eq(
    target.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=127, g=127, b=127, a=255),
  )
  assert_true(
    target.get_dirty_region().bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=1, height=1)),
  )
  assert_true(!layer.has_dirty())

  ignore(layer.clear_filter())
  assert_true(
    layer.dirty_bounds() ==
    Some(@graphics.PixelRect::new(x=0, y=0, width=1, height=1)),
  )
}

///|
test "Layer shader masks alpha-synthesizing filter for transparent cache" {
  let shader = @graphics.PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=1.0,
    y1=0.0,
    start_color=@graphics.Color::blue(),
    end_color=@graphics.Color::blue(),
  )
  let layer = @graphics.Layer::new(1, 1)
    .set_shader(shader)
    .set_filter(make_layer_alpha_synthesizing_filter())
  layer.clear_dirty_region()
  layer.mark_all_dirty()

  let target = @graphics.Canvas::new(1, 1)
  target.clear(@graphics.Color::white())
  target.clear_dirty_region()

  let result = layer.composite_dirty_to_result(target, 8)
  assert_eq(result.get_composited_rect_count(), 1)
  assert_true(result.did_composite())
  assert_true(result.did_clear_dirty())
  assert_eq(target.get_pixmap().get_pixel(0, 0), @graphics.Color::white())
  assert_true(target.get_dirty_region().bounds() == None)
}

///|
test "Layer shader controls full and dirty composition" {
  let gradient = @graphics.PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=2.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
  )
  let full_target = @graphics.Canvas::new(2, 1)
  let full_layer = @graphics.Layer::new(2, 1).set_shader(gradient)
  assert_true(full_layer.get_shader() is Some(_))
  full_layer.get_canvas().draw_pixel(0, 0, @graphics.Color::white())
  full_layer.get_canvas().draw_pixel(1, 0, @graphics.Color::white())
  assert_eq(full_layer.composite_to(full_target), 1)
  assert_eq(
    full_target.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=191, g=0, b=64),
  )
  assert_eq(
    full_target.get_pixmap().get_pixel(1, 0),
    @graphics.Color::new(r=64, g=0, b=191),
  )

  let red_shader = @graphics.PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=1.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::red(),
  )
  let dirty_target = @graphics.Canvas::new(1, 1)
  dirty_target.clear(@graphics.Color::white())
  let dirty_layer = @graphics.Layer::new(1, 1).set_shader(red_shader)
  dirty_layer
  .get_canvas()
  .draw_pixel(0, 0, @graphics.Color::new(r=0, g=0, b=255, a=128))
  assert_eq(dirty_layer.composite_dirty_to(dirty_target, 8), 1)
  assert_eq(
    dirty_target.get_pixmap().get_pixel(0, 0),
    @graphics.Color::new(r=255, g=127, b=127, a=255),
  )

  ignore(dirty_layer.clear_shader())
  assert_true(dirty_layer.get_shader() is None)
}

///|
test "Layer shader keeps transparent cache clean and invisible" {
  let shader = @graphics.PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=1.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::red(),
  )
  let layer = @graphics.Layer::new(1, 1).set_shader(shader)
  assert_true(!layer.has_dirty())

  let target = @graphics.Canvas::new(1, 1)
  target.clear(@graphics.Color::white())
  target.clear_dirty_region()
  assert_eq(layer.composite_dirty_to(target, 8), 0)
  assert_eq(target.get_pixmap().get_pixel(0, 0), @graphics.Color::white())
  assert_true(target.get_dirty_region().is_empty())
  assert_true(!layer.has_dirty())

  layer.mark_all_dirty()
  assert_eq(layer.composite_dirty_to(target, 8), 1)
  assert_eq(target.get_pixmap().get_pixel(0, 0), @graphics.Color::white())
  assert_true(target.get_dirty_region().is_empty())
  assert_true(!layer.has_dirty())

  assert_eq(layer.composite_to(target), 1)
  assert_eq(target.get_pixmap().get_pixel(0, 0), @graphics.Color::white())
  assert_true(target.get_dirty_region().is_empty())
  assert_true(!layer.has_dirty())
}

///|
test "Layer shader samples positioned cache pixels in layer coordinates" {
  let gradient = @graphics.PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=2.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
  )
  let full_target = @graphics.Canvas::new(4, 1)
  let full_layer = @graphics.Layer::new(2, 1)
    .set_position(2, 0)
    .set_shader(gradient)
  full_layer.get_canvas().draw_pixel(0, 0, @graphics.Color::white())
  full_layer.get_canvas().draw_pixel(1, 0, @graphics.Color::white())
  assert_eq(full_layer.composite_to(full_target), 1)
  assert_eq(
    full_target.get_pixmap().get_pixel(2, 0),
    @graphics.Color::new(r=191, g=0, b=64),
  )
  assert_eq(
    full_target.get_pixmap().get_pixel(3, 0),
    @graphics.Color::new(r=64, g=0, b=191),
  )

  let dirty_target = @graphics.Canvas::new(4, 1)
  dirty_target.clear(@graphics.Color::white())
  dirty_target.clear_dirty_region()
  let dirty_layer = @graphics.Layer::new(2, 1)
    .set_position(2, 0)
    .set_shader(gradient)
  dirty_layer.get_canvas().draw_pixel(0, 0, @graphics.Color::white())
  dirty_layer.get_canvas().draw_pixel(1, 0, @graphics.Color::white())
  assert_eq(dirty_layer.composite_dirty_to(dirty_target, 8), 1)
  assert_eq(
    dirty_target.get_pixmap().get_pixel(2, 0),
    @graphics.Color::new(r=191, g=0, b=64),
  )
  assert_eq(
    dirty_target.get_pixmap().get_pixel(3, 0),
    @graphics.Color::new(r=64, g=0, b=191),
  )
  assert_true(
    dirty_target.get_dirty_region().bounds() ==
    Some(@graphics.PixelRect::new(x=2, y=0, width=2, height=1)),
  )
  assert_true(dirty_layer.get_dirty_region().is_empty())
}

///|
test "Layer shader filter composition samples positioned pixels before filtering" {
  let gradient = @graphics.PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=2.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
  )
  let full_target = @graphics.Canvas::new(4, 1)
  let full_layer = @graphics.Layer::new(2, 1)
    .set_position(2, 0)
    .set_shader(gradient)
    .set_filter(@graphics.PaintFilter::invert())
  full_layer.get_canvas().draw_pixel(0, 0, @graphics.Color::white())
  full_layer.get_canvas().draw_pixel(1, 0, @graphics.Color::white())

  assert_eq(full_layer.composite_to(full_target), 1)
  assert_eq(
    full_target.get_pixmap().get_pixel(2, 0),
    @graphics.Color::new(r=64, g=255, b=191),
  )
  assert_eq(
    full_target.get_pixmap().get_pixel(3, 0),
    @graphics.Color::new(r=191, g=255, b=64),
  )

  let dirty_target = @graphics.Canvas::new(4, 1)
  dirty_target.clear(@graphics.Color::white())
  dirty_target.clear_dirty_region()
  let dirty_layer = @graphics.Layer::new(2, 1)
    .set_position(2, 0)
    .set_shader(gradient)
    .set_filter(@graphics.PaintFilter::invert())
  dirty_layer.get_canvas().draw_pixel(0, 0, @graphics.Color::white())
  dirty_layer.get_canvas().draw_pixel(1, 0, @graphics.Color::white())
  dirty_layer.clear_dirty_region()
  dirty_layer.mark_dirty_rect(
    @graphics.PixelRect::new(x=1, y=0, width=1, height=1),
  )

  assert_eq(dirty_layer.composite_dirty_to(dirty_target, 8), 1)
  assert_eq(dirty_target.get_pixmap().get_pixel(2, 0), @graphics.Color::white())
  assert_eq(
    dirty_target.get_pixmap().get_pixel(3, 0),
    @graphics.Color::new(r=191, g=255, b=64),
  )
  assert_true(
    dirty_target.get_dirty_region().bounds() ==
    Some(@graphics.PixelRect::new(x=3, y=0, width=1, height=1)),
  )
  assert_true(dirty_layer.get_dirty_region().is_empty())
}

///|
test "Layer destination blend ignores sampled shader filter source" {
  let gradient = @graphics.PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=2.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
  )
  let full_left = @graphics.Color::new(r=20, g=40, b=60)
  let full_right = @graphics.Color::new(r=200, g=150, b=100)
  let full_target = @graphics.Canvas::new(2, 1)
  full_target.get_pixmap().set_pixel(0, 0, full_left)
  full_target.get_pixmap().set_pixel(1, 0, full_right)
  full_target.clear_dirty_region()
  let full_layer = @graphics.Layer::new(2, 1)
    .set_shader(gradient)
    .set_filter(@graphics.PaintFilter::invert())
    .set_opacity(0.5)
    .set_blend_mode(Destination)
  full_layer.get_canvas().draw_pixel(0, 0, @graphics.Color::white())
  full_layer.get_canvas().draw_pixel(1, 0, @graphics.Color::white())

  assert_eq(full_layer.composite_to(full_target), 1)
  assert_eq(full_target.get_pixmap().get_pixel(0, 0), full_left)
  assert_eq(full_target.get_pixmap().get_pixel(1, 0), full_right)
  assert_true(full_target.get_dirty_region().is_empty())

  let dirty_left = @graphics.Color::new(r=10, g=30, b=50)
  let dirty_right = @graphics.Color::new(r=90, g=110, b=130)
  let dirty_target = @graphics.Canvas::new(2, 1)
  dirty_target.get_pixmap().set_pixel(0, 0, dirty_left)
  dirty_target.get_pixmap().set_pixel(1, 0, dirty_right)
  dirty_target.clear_dirty_region()
  let dirty_layer = @graphics.Layer::new(2, 1)
    .set_shader(gradient)
    .set_filter(@graphics.PaintFilter::invert())
    .set_opacity(0.5)
    .set_blend_mode(Destination)
  dirty_layer.get_canvas().draw_pixel(0, 0, @graphics.Color::white())
  dirty_layer.get_canvas().draw_pixel(1, 0, @graphics.Color::white())
  dirty_layer.clear_dirty_region()
  dirty_layer.mark_dirty_rect(
    @graphics.PixelRect::new(x=1, y=0, width=1, height=1),
  )

  let result = dirty_layer.composite_dirty_to_result(dirty_target, 8)
  assert_eq(result.get_composited_rect_count(), 1)
  assert_true(result.did_composite())
  assert_true(result.did_clear_dirty())
  assert_eq(dirty_target.get_pixmap().get_pixel(0, 0), dirty_left)
  assert_eq(dirty_target.get_pixmap().get_pixel(1, 0), dirty_right)
  assert_true(dirty_target.get_dirty_region().is_empty())
  assert_true(dirty_layer.get_dirty_region().is_empty())
}

///|
test "Layer positioned shader samples partial dirty rect in layer coordinates" {
  let gradient = @graphics.PaintShader::linear_gradient(
    x0=0.0,
    y0=0.0,
    x1=2.0,
    y1=0.0,
    start_color=@graphics.Color::red(),
    end_color=@graphics.Color::blue(),
  )
  let target = @graphics.Canvas::new(4, 1)
  target.clear(@graphics.Color::white())
  target.clear_dirty_region()
  let layer = @graphics.Layer::new(2, 1).set_position(2, 0).set_shader(gradient)
  layer.get_canvas().draw_pixel(0, 0, @graphics.Color::white())
  layer.get_canvas().draw_pixel(1, 0, @graphics.Color::white())
  layer.clear_dirty_region()
  layer.mark_dirty_rect(@graphics.PixelRect::new(x=1, y=0, width=1, height=1))

  assert_eq(layer.composite_dirty_to(target, 8), 1)
  assert_eq(target.get_pixmap().get_pixel(2, 0), @graphics.Color::white())
  assert_eq(
    target.get_pixmap().get_pixel(3, 0),
    @graphics.Color::new(r=64, g=0, b=191),
  )
  assert_true(
    target.get_dirty_region().bounds() ==
    Some(@graphics.PixelRect::new(x=3, y=0, width=1, height=1)),
  )
  assert_true(layer.get_dirty_region().is_empty())
}

///|
test "Layer::composite_to draws full cache" {
  let target = @graphics.Canvas::new(3, 1)
  let layer = @graphics.Layer::new(2, 1).set_position(1, 0)
  layer.get_canvas().draw_pixel(0, 0, @graphics.Color::red())
  layer.get_canvas().draw_pixel(1, 0, @graphics.Color::blue())
  assert_eq(layer.composite_to(target), 1)
  assert_eq(target.get_pixmap().get_pixel(1, 0), @graphics.Color::red())
  assert_eq(target.get_pixmap().get_pixel(2, 0), @graphics.Color::blue())
}

///|
fn make_layer_alpha_synthesizing_filter() -> @graphics.PaintFilter {
  @graphics.PaintFilter::color_matrix([
    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
    0.0, 0.0, 0.0, 128.0,
  ])
}

///|
fn make_layer_red_to_alpha_filter() -> @graphics.PaintFilter {
  @graphics.PaintFilter::color_matrix([
    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0,
    0.0, 0.0, 0.0, 0.0,
  ])
}
