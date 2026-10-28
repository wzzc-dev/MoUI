///|
fn metal_test_metrics() -> @core.SurfaceMetrics {
  @core.SurfaceMetrics::new(
    logical_size=@core.Size::new(width=640.0, height=480.0),
    physical_size=@core.Size::new(width=640.0, height=480.0),
    scale_factor=1.0,
  )
}

///|
fn metal_test_surface(metrics~ : @core.SurfaceMetrics) -> @render.HostSurface {
  @render.HostSurface::new(metrics~)
}

///|
test "metal provider identity is the no-Skia no-wgpu host GPU route" {
  let provider = metal(text_engine=native_noop_text_engine())
  assert_eq(provider.id(), "metal-direct")
  let descriptor = provider.descriptor()
  assert_eq(descriptor.backend, @render.NativeDirectGpu)
  assert_eq(descriptor.family, @render.DirectGpu)
  assert_eq(descriptor.presentation, @render.HostGpuSurface)
  assert_eq(descriptor.supported_targets, [@render.Native])
  assert_eq(descriptor.backend.label(), "native-direct-gpu")
  assert_eq(descriptor.backend.short_label(), "direct-gpu")
  assert_eq(descriptor.family.label(), "direct-gpu")
  let description = descriptor.description
  guard description.contains("No Skia") && description.contains("no wgpu") else {
    fail("descriptor must name the boundary it exists to prove: \{description}")
  }
}

///|
test "metal capability notes cannot be more optimistic than their status" {
  let caps = metal_feature_capabilities()
  let offenders : Array[String] = []
  assert_eq(caps.length(), 17)
  for cap in caps {
    assert_eq(cap.provider_id, "metal-direct")
    assert_eq(cap.backend, @render.NativeDirectGpu)
    let says_absent = cap.note.contains("not implemented")
    if cap.status == @render.Gap {
      if !says_absent {
        fail("a Gap row must say the feature is absent: \{cap.note}")
      }
    } else {
      if says_absent {
        fail("a feature that draws cannot keep the Gap note: \{cap.note}")
      }
      // A length check cannot tell an explanation from a description, and two
      // rows were passing on 700-odd characters of pure description while
      // naming nothing that is missing. The convention is explicit now: a
      // Partial note carries a `Remaining:` sentence, so this can ask for it.
      if cap.status == Partial {
        if !cap.note.contains("Remaining:") {
          offenders.push(cap.feature.label())
        }
        if cap.note.length() < 60 {
          fail(
            "a Partial row must explain the half that is missing: \{cap.note}",
          )
        }
      }
    }
  }
  // Report every offender, not the first: one failure per run would make fixing
  // the list take one run per row.
  assert_eq(
    offenders.join(", "),
    "",
    msg="rows reported Partial without naming their missing half",
  )
}

///|
test "metal rejects a surface with no host GPU layer" {
  let provider = metal(text_engine=native_noop_text_engine())
  match
    provider.bind_surface(metal_test_surface(metrics=metal_test_metrics())) {
    Rejected(message) =>
      if !message.contains("native surface") {
        fail("unexpected rejection reason: \{message}")
      }
    Bound(_) => fail("metal must not bind a surface without a host layer")
  }
}

///|
test "metal rejects degenerate surface metrics before touching the device" {
  let provider = metal(text_engine=native_noop_text_engine())
  let surface = metal_test_surface(
    metrics=@core.SurfaceMetrics::new(
      logical_size=@core.Size::new(width=0.0, height=0.0),
      physical_size=@core.Size::new(width=0.0, height=0.0),
      scale_factor=1.0,
    ),
  )
  match provider.bind_surface(surface) {
    Rejected(message) =>
      if message.length() == 0 {
        fail("rejection must carry the metrics reason")
      }
    Bound(_) => fail("metal must not bind a zero-pixel surface")
  }
}

///|
test "frame accounting reports a failed present without a device" {
  let renderer = MetalRenderer::new(
    metrics=metal_test_metrics(),
    context=0UL,
    layer=0UL,
    cache=@native_text.NativeTextCache::new(),
    image_source=@render.HostImageSource::unavailable(),
  )
  let frame = @core.DrawFrame::new(
    commands=[],
    damage=@core.DamageRegion::empty(),
    clear_color=@core.Color::white(),
  )
  let result = renderer.render_frame(frame)
  assert_eq(result.presented, false)
  assert_eq(renderer.present_count(), 0)
  assert_eq(renderer.present_count(), 0)
  renderer.dispose()
  assert_eq(renderer.render_frame(frame).presented, false)
  assert_eq(renderer.present_count(), 0)
}

///|
/// A provider whose measure layout carries a real caret table. `metal_test_text_engine`'s
/// fixture carries none, and `NativeTextLayout::is_valid_for_measure`
/// (`moui/render/native_text/layout_validation.mbt:18`) rejects a table shorter
/// than one caret per cluster — the shared model then measures the widget with
/// core's ~0.55em estimate while the painter still uses the provider's placements.
/// That divergence is exactly what the wiring probe below is for, so the fixture
/// here supplies numbers no estimate produces: 31.5 wide with a caret at 12.25.
fn metal_wired_text_engine() -> NativeTextEngine {
  let layout = @native_text.NativeTextLayout::new(
    size=@core.Size::new(width=31.5, height=8.0),
    baseline=8.0,
    caret_positions=[0.0, 12.25, 31.5],
    glyphs=[
      @native_text.NativeGlyphPlacement::new(
        key=@native_text.native_platform_glyph_key(
          cache_key="metal-wired-glyph",
          payload=Bytes::make(0, 0),
        ),
        x=0.0,
      ),
    ],
  )
  native_platform_text_engine(
    @native_text.NativePlatformTextProvider::new(
      id="metal-wired-text",
      measure=_input => Some(layout),
      layout_run=(_run, _scale_factor) => Some(layout),
      raster_glyph=(_cache_key, _payload) => Some(metal_test_glyph_raster()),
    ),
  )
}

///|
/// The wiring claim behind every text widget on this route. `to_renderer_session`
/// hands the runtime a system built from the same cache the painter rasterizes
/// from; a route that installed `@core.TextSystem::fallback()` there would still
/// draw glyphs — measured by one engine and placed by another — and every pixel
/// test in this package would stay green, so what is asserted is the metric the
/// widgets receive.
test "metal session gives the runtime the injected engine's text system" {
  let renderer = MetalRenderer::new(
    metrics=metal_test_metrics(),
    context=0UL,
    layer=0UL,
    cache=@native_text.NativeTextCache::new_with_engine(
      metal_wired_text_engine(),
    ),
    image_source=@render.HostImageSource::unavailable(),
  )
  let system = renderer.to_renderer_session().text_system()
  assert_eq(system.id(), "metal-wired-text")
  let layout = system.measure_text(
    @core.TextLayoutInput::new(text="ab", font=@core.FontSpec::new(size=16.0)),
  )
  assert_eq(layout.size.width, 31.5)
  assert_eq(layout.size.height, 8.0)
  assert_eq(layout.baseline, 8.0)
  assert_eq(layout.caret_positions.length(), 3)
  assert_eq(layout.caret_positions[1], 12.25)
  assert_eq(layout.caret_positions[2], 31.5)
  renderer.dispose()
}

///|
test "metal session refuses recovery and never claims a present without a device" {
  let renderer = MetalRenderer::new(
    metrics=metal_test_metrics(),
    context=0UL,
    layer=0UL,
    cache=@native_text.NativeTextCache::new(),
    image_source=@render.HostImageSource::unavailable(),
  )
  let session = renderer.to_renderer_session()
  session.resize(metal_test_metrics())
  assert_eq(session.present_count(), 0)
  match session.recover("test context loss") {
    @render.RecoveryFailed(reason) =>
      if !reason.contains("L4") {
        fail("recovery must name the stage that owns it: \{reason}")
      }
    @render.RecoverySucceeded =>
      fail("metal must not claim a recovery path it does not have")
    @render.FallbackToCpu =>
      fail("metal has no CPU fallback to hand the frame to")
  }
  renderer.dispose()
}
