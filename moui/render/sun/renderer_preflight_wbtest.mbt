///|
test "sun cpu raster preflight records canvas frame and resource telemetry" {
  let preflight = sun_cpu_raster_preflight(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=12.0, height=8.0),
      scale_factor=2.0,
    ),
  )
  inspect(preflight.physical_width, content="24")
  inspect(preflight.physical_height, content="16")
  inspect(preflight.row_bytes, content="96")
  inspect(preflight.byte_size, content="1536")
  assert_true(preflight.canvas_ready)
  assert_true(preflight.frame_ready)
  assert_true(preflight.resource_cache_ready)
  inspect(preflight.font_face_capacity, content="64")
  inspect(preflight.text_mask_capacity, content="256")
  inspect(preflight.glyph_mask_capacity, content="256")
  inspect(preflight.atlas_capacity, content="1048576")
  inspect(preflight.image_capacity, content="128")
  assert_true(
    preflight.summary().contains("Sun CPU raster surface preflight ready"),
  )
  assert_true(preflight.summary().contains("resource cache preflight ready"))
}

///|
test "sun surface diagnostic reports cached layer admission telemetry" {
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=8.0, height=8.0),
    ),
    SunPresentTarget::new(description="diagnostic", present=_ => true),
  )
  for revision in 1..<=3 {
    let spec = @core.CachedLayerSpec::new(
      key="surface-diagnostic-layer",
      frame=@core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      content_revision=revision,
    )
    ignore(
      renderer.render_frame(
        @core.DrawFrame::new(
          commands=[
            @core.DrawCommand::Clear(@core.Color::white()),
            @core.DrawCommand::BeginCachedLayer(spec),
            @core.DrawCommand::FillRect(
              @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
              @core.Color::blue(),
            ),
            @core.DrawCommand::EndCachedLayer(spec.key),
          ],
          damage=@core.DamageRegion::full("sun surface diagnostic cache"),
        ),
      ),
    )
  }
  let summary = renderer.surface_diagnostic_summary()
  assert_true(summary.contains("cached_layer_updates=2"))
  assert_true(summary.contains("cached_layer_evicts=0"))
  assert_true(summary.contains("cached_layer_admissions=1"))
  assert_true(summary.contains("cached_layer_churn_without_hit=1"))
}
