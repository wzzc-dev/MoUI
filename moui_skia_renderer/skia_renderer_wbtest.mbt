///|
test "skia transform maps MoUI affine fields to Skia matrix members" {
  let transform = @core.Transform2D::{
    a: 2.0,
    b: 3.0,
    c: 5.0,
    d: 7.0,
    tx: 11.0,
    ty: 13.0,
  }
  let matrix = skia_matrix(transform)
  assert_true(
    matrix.values() == [2.0, 5.0, 11.0, 3.0, 7.0, 13.0, 0.0, 0.0, 1.0],
  )
  assert_true(
    matrix.map_point(@moui_skia.Point::new(17.0, 19.0)) ==
    @moui_skia.Point::new(140.0, 197.0),
  )
}

///|
test "skia raster surface preflight consumes moui_skia resource descriptors" {
  let preflight = raster_surface_preflight(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=12.0, height=8.0),
      scale_factor=2.0,
    ),
  )
  inspect(preflight.physical_width, content="24")
  inspect(preflight.physical_height, content="16")
  assert_true(preflight.target_ready)
  assert_true(preflight.frame_ready)
  assert_true(preflight.finalization_ready)
  assert_true(preflight.submission_ready)
  inspect(preflight.resource_count, content="2")
  inspect(preflight.cacheable_resource_count, content="1")
  inspect(preflight.uncacheable_resource_count, content="1")
  inspect(preflight.gpu_backed_resource_count, content="0")
  inspect(preflight.surface_resource_count, content="2")
  assert_true(preflight.byte_size > 0L)
}

///|
test "skia raster surface preflight clamps empty physical targets" {
  let preflight = raster_surface_preflight(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=0.0, height=8.0),
      scale_factor=2.0,
    ),
  )
  inspect(preflight.physical_width, content="1")
  inspect(preflight.physical_height, content="16")
  assert_true(preflight.target_ready)
  assert_true(preflight.frame_ready)
  assert_true(preflight.finalization_ready)
  inspect(preflight.resource_count, content="2")
}

///|
test "skia brush shader maps radial gradients when native Skia is linked" {
  let radial = @core.Brush::radial_gradient(
    center=@core.Point::new(x=12.0, y=10.0),
    radius=8.0,
    center_color=@core.Color::blue(),
    edge_color=@core.Color::gray(),
  )
  assert_true(
    skia_brush_shader(@core.Brush::solid(@core.Color::blue())) is None,
  )
  if skia_available() {
    assert_true(skia_brush_shader(radial) is Some(_))
  } else {
    assert_true(skia_brush_shader(radial) is None)
  }
}
