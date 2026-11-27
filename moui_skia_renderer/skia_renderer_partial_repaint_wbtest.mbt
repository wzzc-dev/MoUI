///|
/// Multi-frame pixel-comparison coverage for the default partial-repaint
/// paths. The reference renderer always keeps the historical `FullSurfaceOnly`
/// contract, so equality proves the damage-limited path preserved every pixel
/// outside the dirty region across frames.
fn skia_test_partial_reference(
  metrics : @core.SurfaceMetrics,
) -> SkiaRasterRenderer raise SkiaRendererError {
  create_with_present_target(
    metrics,
    SkiaPresentTarget::new(description="full-reference", present=_ => true),
  )
}

///|
fn skia_test_partial_candidate(
  metrics : @core.SurfaceMetrics,
) -> SkiaRasterRenderer raise SkiaRendererError {
  create_with_present_target(
    metrics,
    SkiaPresentTarget::new(description="subrect-candidate", present=_ => true),
    surface_damage=@render.SubRect,
  )
}

///|
fn skia_test_partial_render_pair(
  reference : SkiaRasterRenderer,
  candidate : SkiaRasterRenderer,
  commands : Array[@core.DrawCommand],
  candidate_damage : @core.DamageRegion,
  clear_color~ : @core.Color = @core.Color::white(),
) -> @render.RenderFrameResult {
  ignore(
    reference.render_frame(
      @core.DrawFrame::new(
        commands~,
        damage=@core.DamageRegion::full("reference frame"),
        clear_color~,
      ),
    ),
  )
  candidate.render_frame(
    @core.DrawFrame::new(commands~, damage=candidate_damage, clear_color~),
  )
}

///|
fn skia_test_partial_frames_equal(
  reference : SkiaRasterRenderer,
  candidate : SkiaRasterRenderer,
) -> Bool {
  match (reference.last_frame(), candidate.last_frame()) {
    (Some(reference_frame), Some(candidate_frame)) =>
      skia_test_pixel_frames_equal(reference_frame, candidate_frame)
    _ => false
  }
}

///|
fn skia_test_pixel_frame_matches_render_frame(
  expected : SkiaPixelFrame,
  actual : @render.PixelFrame,
) -> Bool {
  if expected.width() != actual.width() ||
    expected.height() != actual.height() ||
    expected.row_bytes() != actual.row_bytes() ||
    expected.scale_factor() != actual.scale_factor() ||
    expected.pixels().length() != actual.pixels().length() {
    return false
  }
  for index in 0..<expected.pixels().length() {
    if expected.pixels()[index] != actual.pixels()[index] {
      return false
    }
  }
  true
}

///|
fn skia_test_partial_has_diagnostic(
  result : @render.RenderFrameResult,
  code : String,
) -> Bool {
  for diagnostic in result.diagnostics {
    if diagnostic.code == code {
      return true
    }
  }
  false
}

///|
test "skia subrect moving layer matches full-frame reference" {
  guard skia_available() else { return }
  let metrics = @core.SurfaceMetrics::from_logical(
    size=@core.Size::new(width=16.0, height=16.0),
  )
  let reference = skia_test_partial_reference(metrics) catch {
    err => fail("expected reference creation: \{err.message()}")
  }
  let candidate = skia_test_partial_candidate(metrics) catch {
    err => fail("expected candidate creation: \{err.message()}")
  }
  let red = @core.Color::rgba(r=1.0, g=0.0, b=0.0, a=1.0)
  let blue = @core.Color::rgba(r=0.0, g=0.0, b=1.0, a=1.0)
  let old_rect = @core.Rect::new(x=2.0, y=2.0, width=4.0, height=4.0)
  let new_rect = @core.Rect::new(x=9.0, y=9.0, width=4.0, height=4.0)
  let first_commands : Array[@core.DrawCommand] = [FillRect(old_rect, red)]
  ignore(
    skia_test_partial_render_pair(
      reference,
      candidate,
      first_commands,
      @core.DamageRegion::full("initial frame"),
    ),
  )
  let move_commands : Array[@core.DrawCommand] = [FillRect(new_rect, blue)]
  let moved = skia_test_partial_render_pair(
    reference,
    candidate,
    move_commands,
    Rects([old_rect, new_rect]),
  )
  assert_true(moved.presented)
  assert_true(skia_test_partial_frames_equal(reference, candidate))
  guard candidate.last_damage_report() is Some(report) else {
    fail("expected a damage report")
  }
  inspect(report.requested().kind(), content="rects")
  inspect(report.effective().kind(), content="rects")
  inspect(report.target().label(), content="retained-raster-surface")
  assert_true(report.presented())
  assert_true(report.fallback_reason() is None)
  assert_true(report.draw_us() >= 0.0)
  assert_true(report.copy_us() >= 0.0)
  assert_true(report.present_us() >= 0.0)
  guard candidate.last_frame() is Some(frame) else {
    fail("expected candidate frame")
  }
  assert_true(
    skia_test_region_has_matching_pixel(frame, old_rect, (r, g, b, a) => {
      r > 240 && g > 240 && b > 240 && a > 0
    }),
  )
  assert_true(
    skia_test_region_has_matching_pixel(frame, new_rect, (r, g, b, a) => {
      r < 40 && g < 40 && b > 200 && a > 0
    }),
  )
}

///|
test "skia subrect transparent background and deletion match full reference" {
  guard skia_available() else { return }
  let metrics = @core.SurfaceMetrics::from_logical(
    size=@core.Size::new(width=16.0, height=16.0),
  )
  let reference = skia_test_partial_reference(metrics) catch {
    err => fail("expected reference creation: \{err.message()}")
  }
  let candidate = skia_test_partial_candidate(metrics) catch {
    err => fail("expected candidate creation: \{err.message()}")
  }
  let transparent = @core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0)
  let red = @core.Color::rgba(r=1.0, g=0.0, b=0.0, a=1.0)
  let green = @core.Color::rgba(r=0.0, g=1.0, b=0.0, a=1.0)
  let deleted = @core.Rect::new(x=2.0, y=2.0, width=5.0, height=5.0)
  let retained = @core.Rect::new(x=11.0, y=11.0, width=4.0, height=4.0)
  let first_commands : Array[@core.DrawCommand] = [
    FillRect(deleted, red),
    FillRect(retained, green),
  ]
  ignore(
    skia_test_partial_render_pair(
      reference,
      candidate,
      first_commands,
      @core.DamageRegion::full("initial frame"),
      clear_color=transparent,
    ),
  )
  // The deleted item disappears; the retained item stays in the full command
  // stream but lies outside the damage rect, so only surface retention can
  // reproduce it.
  let delete_commands : Array[@core.DrawCommand] = [FillRect(retained, green)]
  let deleted_frame = skia_test_partial_render_pair(
    reference,
    candidate,
    delete_commands,
    Rects([deleted]),
    clear_color=transparent,
  )
  assert_true(deleted_frame.presented)
  assert_true(skia_test_partial_frames_equal(reference, candidate))
  guard candidate.last_frame() is Some(frame) else {
    fail("expected candidate frame")
  }
  assert_true(
    skia_test_region_has_matching_pixel(frame, deleted, (_r, _g, _b, a) => {
      a == 0
    }),
  )
  assert_true(
    skia_test_region_has_matching_pixel(frame, retained, (r, g, b, a) => {
      r < 40 && g > 200 && b < 40 && a > 0
    }),
  )
}

///|
test "skia subrect hidpi move matches full-frame reference" {
  guard skia_available() else { return }
  let metrics = @core.SurfaceMetrics::from_logical(
    size=@core.Size::new(width=32.0, height=16.0),
    scale_factor=2.0,
  )
  let reference = skia_test_partial_reference(metrics) catch {
    err => fail("expected reference creation: \{err.message()}")
  }
  let candidate = skia_test_partial_candidate(metrics) catch {
    err => fail("expected candidate creation: \{err.message()}")
  }
  let red = @core.Color::rgba(r=1.0, g=0.0, b=0.0, a=1.0)
  let blue = @core.Color::rgba(r=0.0, g=0.0, b=1.0, a=1.0)
  let old_rect = @core.Rect::new(x=2.0, y=2.0, width=4.0, height=4.0)
  let new_rect = @core.Rect::new(x=20.0, y=2.0, width=4.0, height=4.0)
  ignore(
    skia_test_partial_render_pair(
      reference,
      candidate,
      [FillRect(old_rect, red)],
      @core.DamageRegion::full("initial hidpi frame"),
    ),
  )
  let moved = skia_test_partial_render_pair(
    reference,
    candidate,
    [FillRect(new_rect, blue)],
    Rects([old_rect, new_rect]),
  )
  assert_true(moved.presented)
  assert_true(skia_test_partial_frames_equal(reference, candidate))
  guard candidate.last_damage_report() is Some(report) else {
    fail("expected a damage report")
  }
  inspect(report.effective().kind(), content="rects")
  inspect(report.effective().rect_count(), content="1")
}

///|
test "skia subrect scope commands record a full-damage fallback" {
  guard skia_available() else { return }
  let metrics = @core.SurfaceMetrics::from_logical(
    size=@core.Size::new(width=16.0, height=16.0),
  )
  let reference = skia_test_partial_reference(metrics) catch {
    err => fail("expected reference creation: \{err.message()}")
  }
  let candidate = skia_test_partial_candidate(metrics) catch {
    err => fail("expected candidate creation: \{err.message()}")
  }
  let left = @core.Rect::new(x=2.0, y=2.0, width=6.0, height=6.0)
  ignore(
    skia_test_partial_render_pair(
      reference,
      candidate,
      [FillRect(left, @core.Color::black())],
      @core.DamageRegion::full("initial frame"),
    ),
  )
  let scoped : Array[@core.DrawCommand] = [
    PushOpacity(1.0),
    FillRect(left, @core.Color::white()),
    PopOpacity,
  ]
  let result = skia_test_partial_render_pair(
    reference,
    candidate,
    scoped,
    Rects([left]),
  )
  assert_true(result.presented)
  assert_true(skia_test_partial_frames_equal(reference, candidate))
  guard candidate.last_damage_report() is Some(report) else {
    fail("expected a damage report")
  }
  inspect(report.requested().kind(), content="rects")
  inspect(report.effective().kind(), content="full")
  guard report.fallback_reason() is Some(reason) else {
    fail("expected a damage fallback reason")
  }
  assert_true(reason.contains("scope"))
  assert_true(
    skia_test_partial_has_diagnostic(result, "renderer.damage_fallback"),
  )
}

///|
test "skia subrect resize forces full reinitialization" {
  guard skia_available() else { return }
  let initial_metrics = @core.SurfaceMetrics::from_logical(
    size=@core.Size::new(width=16.0, height=16.0),
  )
  let resized_metrics = @core.SurfaceMetrics::from_logical(
    size=@core.Size::new(width=24.0, height=16.0),
  )
  let reference = skia_test_partial_reference(resized_metrics) catch {
    err => fail("expected reference creation: \{err.message()}")
  }
  let candidate = skia_test_partial_candidate(initial_metrics) catch {
    err => fail("expected candidate creation: \{err.message()}")
  }
  let red = @core.Color::rgba(r=1.0, g=0.0, b=0.0, a=1.0)
  let blue = @core.Color::rgba(r=0.0, g=0.0, b=1.0, a=1.0)
  let left = @core.Rect::new(x=2.0, y=2.0, width=4.0, height=4.0)
  ignore(
    skia_test_partial_render_pair(
      reference,
      candidate,
      [FillRect(left, red)],
      @core.DamageRegion::full("initial frame"),
    ),
  )
  candidate.resize(resized_metrics) catch {
    err => fail("expected candidate resize: \{err.message()}")
  }
  let right = @core.Rect::new(x=18.0, y=2.0, width=4.0, height=4.0)
  let recovered = skia_test_partial_render_pair(
    reference,
    candidate,
    [FillRect(right, blue)],
    Rects([right]),
  )
  assert_true(recovered.presented)
  assert_true(skia_test_partial_frames_equal(reference, candidate))
  guard candidate.last_damage_report() is Some(report) else {
    fail("expected a damage report")
  }
  inspect(report.requested().kind(), content="rects")
  inspect(report.effective().kind(), content="full")
  guard report.fallback_reason() is Some(reason) else {
    fail("expected a resize fallback reason")
  }
  assert_true(reason.contains("not initialized"))
}

///|
test "skia subrect incomplete frame forces full reinitialization" {
  guard skia_available() else { return }
  let metrics = @core.SurfaceMetrics::from_logical(
    size=@core.Size::new(width=16.0, height=16.0),
  )
  let reference = skia_test_partial_reference(metrics) catch {
    err => fail("expected reference creation: \{err.message()}")
  }
  let candidate = skia_test_partial_candidate(metrics) catch {
    err => fail("expected candidate creation: \{err.message()}")
  }
  let left = @core.Rect::new(x=2.0, y=2.0, width=4.0, height=4.0)
  ignore(
    skia_test_partial_render_pair(
      reference,
      candidate,
      [FillRect(left, @core.Color::black())],
      @core.DamageRegion::full("initial frame"),
    ),
  )
  let broken = @core.RetainedLayerSpec::new(
    key="partial-repaint-broken",
    frame=@core.Rect::new(x=2.0, y=2.0, width=4.0, height=4.0),
    content_revision=1,
  )
  let broken_commands : Array[@core.DrawCommand] = [BeginRetainedLayer(broken)]
  ignore(
    skia_test_partial_render_pair(
      reference,
      candidate,
      broken_commands,
      Rects([left]),
    ),
  )
  guard candidate.last_damage_report() is Some(broken_report) else {
    fail("expected a damage report for the incomplete frame")
  }
  assert_false(broken_report.presented())
  let right = @core.Rect::new(x=10.0, y=10.0, width=4.0, height=4.0)
  let recovered = skia_test_partial_render_pair(
    reference,
    candidate,
    [FillRect(right, @core.Color::rgba(r=0.0, g=0.0, b=1.0, a=1.0))],
    Rects([right]),
  )
  assert_true(recovered.presented)
  assert_true(skia_test_partial_frames_equal(reference, candidate))
  guard candidate.last_damage_report() is Some(report) else {
    fail("expected a recovery damage report")
  }
  inspect(report.effective().kind(), content="full")
  guard report.fallback_reason() is Some(reason) else {
    fail("expected a recovery fallback reason")
  }
  assert_true(reason.contains("not initialized"))
}

///|
test "default raster provider negotiates subrect and preserves pixels" {
  guard skia_available() else { return }
  let metrics = @core.SurfaceMetrics::from_logical(
    size=@core.Size::new(width=16.0, height=16.0),
  )
  let captured : Array[@render.PixelFrame] = []
  let surface = @render.HostSurface::new(
    surface_id="partial-raster-provider",
    metrics~,
    cpu_present=Some(
      @render.PresentTarget::new(description="partial-raster-provider", present=frame => {
        captured.push(frame)
        true
      }),
    ),
  )
  let provider = raster()
  let session = match provider.bind_surface(surface) {
    @render.Bound(session) => session
    @render.Rejected(message) =>
      fail("expected the raster provider to bind: \{message}")
  }
  guard session.surface_damage_capability() is @render.SubRect else {
    fail("default raster provider must negotiate SubRect")
  }
  let red = @core.Color::rgba(r=1.0, g=0.0, b=0.0, a=1.0)
  let blue = @core.Color::rgba(r=0.0, g=0.0, b=1.0, a=1.0)
  let old_rect = @core.Rect::new(x=2.0, y=2.0, width=4.0, height=4.0)
  let new_rect = @core.Rect::new(x=9.0, y=9.0, width=4.0, height=4.0)
  let first = session.render_frame(
    @render.RenderFrameSubmission::new(
      token=@render.FrameToken::new(surface_generation=0, sequence=0),
      frame=@core.DrawFrame::new(
        commands=[FillRect(old_rect, red)],
        damage=@core.DamageRegion::full("provider initial frame"),
      ),
    ),
  )
  assert_true(first.presented)
  let second = session.render_frame(
    @render.RenderFrameSubmission::new(
      token=@render.FrameToken::new(surface_generation=0, sequence=1),
      frame=@core.DrawFrame::new(
        commands=[FillRect(new_rect, blue)],
        damage=Rects([old_rect, new_rect]),
      ),
    ),
  )
  assert_true(second.presented)
  inspect(captured.length(), content="2")
  let reference = skia_test_partial_reference(metrics) catch {
    err => fail("expected reference creation: \{err.message()}")
  }
  ignore(
    reference.render_frame(
      @core.DrawFrame::new(
        commands=[FillRect(old_rect, red)],
        damage=@core.DamageRegion::full("reference initial frame"),
      ),
    ),
  )
  ignore(
    reference.render_frame(
      @core.DrawFrame::new(
        commands=[FillRect(new_rect, blue)],
        damage=@core.DamageRegion::full("reference move frame"),
      ),
    ),
  )
  guard reference.last_frame() is Some(reference_frame) else {
    fail("expected a reference frame")
  }
  assert_true(
    skia_test_pixel_frame_matches_render_frame(reference_frame, captured[1]),
  )
  session.dispose()
}

///|
test "gpu damage capability is only advertised where backing exists" {
  assert_true(
    skia_gpu_surface_damage_capability(MetalGpuSurfaceRoute) is @render.SubRect,
  )
  assert_true(
    skia_gpu_surface_damage_capability(VulkanGpuSurfaceRoute)
    is @render.FullSurfaceOnly,
  )
  assert_true(
    skia_gpu_surface_damage_capability(Direct3DGpuSurfaceRoute)
    is @render.FullSurfaceOnly,
  )
  assert_true(
    skia_gpu_surface_damage_capability(EglGpuSurfaceRoute)
    is @render.FullSurfaceOnly,
  )
}

///|
test "skia partial repaint report separates backing from drawable" {
  guard skia_available() else { return }
  let metrics = @core.SurfaceMetrics::from_logical(
    size=@core.Size::new(width=8.0, height=8.0),
  )
  let raster_renderer = skia_test_partial_candidate(metrics) catch {
    err => fail("expected raster candidate creation: \{err.message()}")
  }
  let raster_report = raster_renderer.partial_repaint_report()
  assert_true(raster_report.surface_damage() is @render.SubRect)
  assert_true(raster_report.drawable_retained())
  assert_false(raster_report.persistent_backing())
  assert_true(raster_report.partial_redraw())
  assert_false(raster_report.partial_present())
}

///|
fn skia_test_gpu_frame_capture(
  surface : @skia_native.Surface,
) -> SkiaPixelFrame? {
  match surface.read_pixels() {
    Some(pixmap) =>
      Some({
        width: pixmap.width(),
        height: pixmap.height(),
        row_bytes: pixmap.row_bytes(),
        scale_factor: 1.0,
        pixels: pixmap.pixels,
      })
    None => None
  }
}

///|
fn skia_test_gpu_partial_renderer(
  label : String,
  surface_damage : @render.SurfaceDamageCapability,
  captured : Array[SkiaPixelFrame],
) -> SkiaRasterRenderer raise SkiaRendererError {
  let target = SkiaPresentTarget::new(description=label, present=_ => true)
  let gpu_target = HostGpuPresentTarget::new(
    description=label,
    create_window_surface=(context, metrics) => {
      skia_test_gpu_surface_for_size(
        context,
        @moui_skia.ISize::new(
          metrics.physical_size.width.to_int(),
          metrics.physical_size.height.to_int(),
        ),
      )
    },
    present_gpu=(context, surface) => {
      match skia_test_gpu_frame_capture(surface) {
        Some(frame) => captured.push(frame)
        None => ()
      }
      HostGpuPresentOutcome::new(
        succeeded=true,
        next_surface=skia_test_gpu_surface(context),
      )
    },
  )
  create_with_present_target_and_route(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=8.0, height=8.0),
    ),
    target,
    surface_route=MetalGpuSurfaceRoute,
    gpu_target=Some(gpu_target),
    surface_damage~,
  )
}

///|
test "Metal persistent backing partial update matches full reference" {
  guard skia_available() else { return }
  guard @skia_native.Surface::metal_gpu_context_runtime_available() else {
    return ()
  }
  let reference_frames : Array[SkiaPixelFrame] = []
  let candidate_frames : Array[SkiaPixelFrame] = []
  let reference = skia_test_gpu_partial_renderer(
    "gpu-full-reference",
    @render.FullSurfaceOnly,
    reference_frames,
  ) catch {
    _ => return ()
  }
  let candidate = skia_test_gpu_partial_renderer(
    "gpu-subrect-candidate",
    @render.SubRect,
    candidate_frames,
  ) catch {
    _ => return ()
  }
  let red = @core.Color::rgba(r=1.0, g=0.0, b=0.0, a=1.0)
  let blue = @core.Color::rgba(r=0.0, g=0.0, b=1.0, a=1.0)
  let old_rect = @core.Rect::new(x=0.0, y=0.0, width=3.0, height=8.0)
  let new_rect = @core.Rect::new(x=3.0, y=0.0, width=5.0, height=8.0)
  let first_commands : Array[@core.DrawCommand] = [FillRect(old_rect, red)]
  let first = candidate.render_frame(
    @core.DrawFrame::new(
      commands=first_commands,
      damage=@core.DamageRegion::full("gpu initial frame"),
      clear_color=@core.Color::white(),
    ),
  )
  assert_true(first.presented)
  ignore(
    reference.render_frame(
      @core.DrawFrame::new(
        commands=first_commands,
        damage=@core.DamageRegion::full("gpu reference initial frame"),
        clear_color=@core.Color::white(),
      ),
    ),
  )
  let move_commands : Array[@core.DrawCommand] = [FillRect(new_rect, blue)]
  let second = candidate.render_frame(
    @core.DrawFrame::new(
      commands=move_commands,
      damage=Rects([old_rect, new_rect]),
      clear_color=@core.Color::white(),
    ),
  )
  assert_true(second.presented)
  ignore(
    reference.render_frame(
      @core.DrawFrame::new(
        commands=move_commands,
        damage=@core.DamageRegion::full("gpu reference move frame"),
        clear_color=@core.Color::white(),
      ),
    ),
  )
  guard candidate.last_damage_report() is Some(report) else {
    fail("expected a damage report")
  }
  inspect(report.requested().kind(), content="rects")
  inspect(report.effective().kind(), content="rects")
  inspect(report.target().label(), content="gpu-persistent-backing")
  assert_true(report.presented())
  assert_true(report.fallback_reason() is None)
  let capability = candidate.partial_repaint_report()
  assert_true(capability.surface_damage() is @render.SubRect)
  assert_false(capability.drawable_retained())
  assert_true(capability.persistent_backing())
  assert_true(capability.partial_redraw())
  assert_false(capability.partial_present())
  // Backing pixels are updated only inside the damage union, while the
  // drawable receives the complete backing. GPU readback may be unavailable on
  // a stub build; the report checks above still prove the path was selected.
  if reference_frames.length() == 2 && candidate_frames.length() == 2 {
    assert_true(
      skia_test_pixel_frames_equal(reference_frames[1], candidate_frames[1]),
    )
  }
  candidate.dispose()
  reference.dispose()
}

///|
test "Metal backing resize forces full initialization" {
  guard skia_available() else { return }
  guard @skia_native.Surface::metal_gpu_context_runtime_available() else {
    return ()
  }
  let captured : Array[SkiaPixelFrame] = []
  let renderer = skia_test_gpu_partial_renderer(
    "gpu-subrect-resize",
    @render.SubRect,
    captured,
  ) catch {
    _ => return ()
  }
  let first = renderer.render_frame(
    @core.DrawFrame::new(
      commands=[
        FillRect(
          @core.Rect::new(x=0.0, y=0.0, width=8.0, height=8.0),
          @core.Color::black(),
        ),
      ],
      damage=@core.DamageRegion::full("gpu resize baseline"),
      clear_color=@core.Color::white(),
    ),
  )
  assert_true(first.presented)
  renderer.resize(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=10.0, height=10.0),
    ),
  ) catch {
    _ => return ()
  }
  let resized = renderer.render_frame(
    @core.DrawFrame::new(
      commands=[
        FillRect(
          @core.Rect::new(x=4.0, y=4.0, width=4.0, height=4.0),
          @core.Color::white(),
        ),
      ],
      damage=Rects([@core.Rect::new(x=4.0, y=4.0, width=4.0, height=4.0)]),
      clear_color=@core.Color::white(),
    ),
  )
  assert_true(resized.presented)
  guard renderer.last_damage_report() is Some(report) else {
    fail("expected a resize damage report")
  }
  inspect(report.effective().kind(), content="full")
  guard report.fallback_reason() is Some(reason) else {
    fail("expected a backing reinitialization reason")
  }
  assert_true(reason.contains("backing"))
  renderer.dispose()
}
