///|
test "skia renderer backend info reflects native availability" {
  let info = backend_info()
  assert_true(info.backend == @render.RendererBackendKind::SkiaRasterNative)
  assert_true(info.owns_surface)
  assert_true(info.description.contains("SurfaceTargetDescriptor"))
  assert_true(info.description.contains("finalization preflight"))
  assert_true(info.description.contains("Metal GPU opt-in preflight"))
  assert_true(info.description.contains("window-present=pending"))
  assert_true(info.description.contains("text fallback/shaping descriptor"))
  assert_true(info.description.contains("text maturity audit"))
  assert_false(info.description.contains("text maturity audit partial"))
  assert_true(
    info.description.contains("mixed-run fallback ready") ||
    info.description.contains("mixed-run fallback pending"),
  )
  assert_true(
    info.description.contains("Unicode 17 grapheme boundary contract ready") ||
    info.description.contains("Unicode 17 grapheme boundary contract pending"),
  )
  assert_true(
    info.description.contains("bidi and paragraph line breaking ready"),
  )
  assert_true(
    info.description.contains("color emoji confirmed") ||
    info.description.contains("color emoji pending"),
  )
  assert_true(info.description.contains("flush-and-submit finalization"))
  if skia_available() {
    assert_true(info.status == @render.RendererCapabilityStatus::Supported)
    assert_true(info.can_render)
  } else {
    assert_true(info.status == @render.RendererCapabilityStatus::Unavailable)
    assert_false(info.can_render)
  }
}

///|
test "skia gpu metal preflight reports explicit opt-in route" {
  let summary = skia_gpu_metal_preflight_summary()
  assert_true(summary.contains("Metal GPU opt-in preflight"))
  assert_true(summary.contains("target-plan-ready"))
  assert_true(summary.contains("explicit-offscreen-surface-api-"))
  assert_true(summary.contains("window-present=pending"))
}

///|
test "skia surface routes keep raster default and gate metal gpu explicitly" {
  assert_false(SkiaSurfaceRoute::RasterSurfaceRoute.is_gpu())
  assert_true(SkiaSurfaceRoute::MetalGpuSurfaceRoute.is_gpu())
  assert_true(SkiaSurfaceRoute::RasterSurfaceRoute.label() == "raster")
  assert_true(SkiaSurfaceRoute::MetalGpuSurfaceRoute.label() == "metal-gpu")

  let target = SkiaPresentTarget::new(description="test", present=_frame => true)
  let metrics = @core.SurfaceMetrics::from_logical(
    size=@core.Size::new(width=16.0, height=16.0),
  )
  if !skia_available() {
    try
      create_with_present_target_and_route(
        metrics,
        target,
        surface_route=SkiaSurfaceRoute::MetalGpuSurfaceRoute,
      )
    catch {
      err =>
        match err {
          SkiaRendererError::SkiaUnavailable => ()
          _ => fail("expected unavailable Skia before GPU route creation")
        }
    } noraise {
      _ => fail("expected unavailable Skia before GPU route creation")
    }
  } else {
    let descriptor = @moui_skia.GpuContextDescriptor::metal(
      b"moui-render-skia-metal-gpu",
    )
    let status = @skia_native.Surface::gpu_context_support_status(descriptor)
    if status.is_available() {
      let renderer = create_with_present_target_and_route(
        metrics,
        target,
        surface_route=SkiaSurfaceRoute::MetalGpuSurfaceRoute,
      ) catch {
        err => fail("expected GPU renderer route, got \{err.message()}")
      }
      assert_true(renderer.surface_route().is_gpu())
      assert_true(renderer.surface_is_gpu())
      assert_true(
        renderer
        .surface_diagnostic_summary()
        .contains("surface_route=metal-gpu"),
      )
      assert_true(
        renderer.surface_diagnostic_summary().contains("surface_gpu=true"),
      )
    } else {
      try
        create_with_present_target_and_route(
          metrics,
          target,
          surface_route=SkiaSurfaceRoute::MetalGpuSurfaceRoute,
        )
      catch {
        err =>
          match err {
            SkiaRendererError::GpuContextUnavailable(_) => ()
            _ => fail("expected explicit GPU context unavailable error")
          }
      } noraise {
        _ => fail("expected explicit GPU context unavailable error")
      }
    }
  }
}

///|
test "skia renderer descriptor is a skia cpu pixel backend" {
  let descriptor = renderer_descriptor()
  assert_true(
    descriptor.backend == @render.RendererBackendKind::SkiaRasterNative,
  )
  assert_true(descriptor.family == @render.RendererFamily::Skia)
  assert_true(
    descriptor.presentation == @render.RendererPresentationModel::CpuPixelFrame,
  )
  inspect(descriptor.capabilities.length(), content="17")
}

///|
test "skia renderer fails explicitly when real skia is unavailable" {
  if !skia_available() {
    let target = SkiaPresentTarget::new(description="test", present=_frame => {
      true
    })
    try
      create_with_present_target(
        @core.SurfaceMetrics::from_logical(
          size=@core.Size::new(width=16.0, height=16.0),
        ),
        target,
      )
    catch {
      err =>
        match err {
          SkiaRendererError::SkiaUnavailable => ()
          _ => fail("expected explicit unavailable error")
        }
    } noraise {
      _ => fail("expected explicit unavailable error")
    }
    try
      create_with_present_target(
        @core.SurfaceMetrics::from_logical(
          size=@core.Size::new(width=16.0, height=16.0),
        ),
        target,
        font_resolution=SkiaFontResolution::EmptyTypeface,
      )
    catch {
      err =>
        match err {
          SkiaRendererError::SkiaUnavailable => ()
          _ => fail("expected explicit unavailable error")
        }
    } noraise {
      _ => fail("expected explicit unavailable error")
    }
  }
}

///|
test "skia text system is directly available for diagnostic conformance" {
  let system = skia_text_system()
  assert_true(system.id() == "skia-raster-text-system")
  let text = "abc אבג 👩‍💻"
  let input = @core.TextLayoutInput::new(
    text~,
    font=@core.FontSpec::new(size=18.0, weight=500),
  )
  let layout = system.measure_text(input)
  inspect(
    layout.caret_positions.length(),
    content="\{text.to_array().length() + 1}",
  )
  assert_true(layout.size.width > 0.0)
  assert_true(layout.baseline > 0.0)
  assert_true(skia_test_carets_are_monotonic(layout.caret_positions))
  let clamped = system.measure_text(
    @core.TextLayoutInput::new(text~, font=input.font, max_width=32.0),
  )
  inspect(
    clamped.caret_positions.length(),
    content="\{text.to_array().length() + 1}",
  )
  assert_true(clamped.size.width <= 32.0)
  for caret in clamped.caret_positions {
    assert_true(caret <= 32.0)
  }
  let paragraph_text = "alpha beta gamma delta"
  let paragraph = system.layout_paragraph(
    @core.TextLayoutInput::new(
      text=paragraph_text,
      font=input.font,
      max_width=72.0,
    ),
  )
  assert_true(paragraph.metadata.paragraph_layout_available)
  assert_true(paragraph.metadata.line_metrics_available)
  assert_true(paragraph.metadata.selection_rects_available)
  assert_true(paragraph.metadata.hit_test_available)
  if @skia_native.skia_paragraph_available() {
    assert_true(paragraph.metadata.native_paragraph_ready)
  } else {
    assert_false(paragraph.metadata.native_paragraph_ready)
  }
  assert_true(paragraph.line_count() >= 2)
  inspect(
    paragraph.caret_rects.length(),
    content="\{paragraph_text.to_array().length() + 1}",
  )
  assert_true(
    paragraph
    .selection_rects(
      @core.TextRange::new(start=0, end=paragraph_text.to_array().length()),
    )
    .length() >=
    2,
  )
}

///|
/// The editor's shared soft-wrap layer consumes line `text_range` as Char
/// offsets (moui/core contract). SkParagraph reports line metrics in UTF-16
/// code units, so mixed CJK + Latin text is the regression fixture: if the
/// conversion regressed to raw byte/unit indices, line coverage gaps appear
/// only once the text contains multi-byte characters.
test "skia paragraph line metrics are character offsets for CJK mixed text" {
  if !@skia_native.skia_paragraph_available() {
    return
  }
  let system = skia_text_system()
  let text =
    "MoUI 是一个多平台 MoonBit GUI 框架，用于构建声明式 UI 应用，共享平台无关的应用逻辑。"
  let chars = text.to_array()
  let paragraph = system.layout_paragraph(
    @core.TextLayoutInput::new(
      text~,
      font=@core.FontSpec::new(size=18.0, weight=500),
      max_width=240.0,
    ),
  )
  assert_true(paragraph.metadata.native_paragraph_ready)
  let lines = paragraph.lines
  assert_true(lines.length() >= 2)
  assert_true(lines[0].text_range.start == 0)
  assert_true(lines[lines.length() - 1].text_range.end == chars.length())
  for index, line in lines {
    assert_true(line.text_range.end > line.text_range.start)
    if index + 1 < lines.length() {
      assert_true(lines[index + 1].text_range.start == line.text_range.end)
    }
  }
}

///|
test "skia selection geometry diagnostic covers line ranges hit testing and bidi observation" {
  let text = "ABC \u{05D0}\u{05D1}\u{05D2} 123 alpha beta gamma"
  guard skia_text_selection_geometry_diagnostic(
      text,
      font=@core.FontSpec::new(size=18.0, weight=500),
      max_width=96.0,
    )
    is Some(diagnostic) else {
    fail("expected Skia selection geometry diagnostic")
  }
  assert_true(diagnostic.selection_rect_count() >= 2)
  assert_true(diagnostic.selected_line_count() >= 2)
  assert_true(diagnostic.line_count() >= 2)
  inspect(diagnostic.hit_test_line_index(), content="1")
  assert_true(diagnostic.hit_test_inside())
  assert_true(
    diagnostic.hit_test_offset() >= diagnostic.selection_range().start,
  )
  if skia_available() {
    assert_true(diagnostic.visual_order_differs())
    assert_true(diagnostic.visual_segment_count() >= 3)
    assert_true(diagnostic.bidi_visual_order_observed())
  }
}

///|
test "skia empty typeface text system remains opt-in and fallback-safe" {
  let system = skia_text_system(resolution=SkiaFontResolution::EmptyTypeface)
  if skia_available() {
    assert_true(system.id() == "skia-raster-empty-typeface-text-system")
  } else {
    assert_true(system.id() == @core.TextSystem::fallback().id())
  }
}

///|
test "skia pixel frame carries presenter payload" {
  let captured : Ref[SkiaPixelFrame?] = Ref(None)
  let target = SkiaPresentTarget::new(description="test", present=next => {
    captured.val = Some(next)
    true
  })
  guard skia_available() else {
    assert_true(captured.val is None)
    return ()
  }
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=1.0, height=1.0),
      scale_factor=2.0,
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  renderer.render([@core.DrawCommand::Clear(@core.Color::white())]) catch {
    err => fail("expected Skia renderer render: \{err.message()}")
  }
  guard captured.val is Some(frame) else {
    fail("expected presenter callback to receive pixel frame")
  }
  inspect(frame.width(), content="2")
  inspect(frame.height(), content="2")
  inspect(frame.scale_factor(), content="2")
  inspect(frame.row_bytes(), content="8")
  inspect(frame.pixels().length(), content="16")
}

///|
test "skia renderer descriptor exposes observation-gated backend capabilities" {
  let descriptor = skia_raster_native_descriptor()
  let image = find_skia_descriptor_capability(
    descriptor,
    @render.RendererFeature::Image,
  )
  let gradient = find_skia_descriptor_capability(
    descriptor,
    @render.RendererFeature::Gradient,
  )
  let path = find_skia_descriptor_capability(
    descriptor,
    @render.RendererFeature::PathVector,
  )
  let layer = find_skia_descriptor_capability(
    descriptor,
    @render.RendererFeature::LayerCompositing,
  )
  let blend = find_skia_descriptor_capability(
    descriptor,
    @render.RendererFeature::BlendMode,
  )
  let filter = find_skia_descriptor_capability(
    descriptor,
    @render.RendererFeature::FilterEffect,
  )
  let transform = find_skia_descriptor_capability(
    descriptor,
    @render.RendererFeature::Transform,
  )
  let shader = find_skia_descriptor_capability(
    descriptor,
    @render.RendererFeature::ShaderEffect,
  )
  match (image, gradient, path, layer, blend, filter, transform, shader) {
    (
      Some(image),
      Some(gradient),
      Some(path),
      Some(layer),
      Some(blend),
      Some(filter),
      Some(transform),
      Some(shader),
    ) => {
      assert_true(
        image.backend == @render.RendererBackendKind::SkiaRasterNative,
      )
      assert_true(
        gradient.backend == @render.RendererBackendKind::SkiaRasterNative,
      )
      assert_true(path.backend == @render.RendererBackendKind::SkiaRasterNative)
      assert_true(
        layer.backend == @render.RendererBackendKind::SkiaRasterNative,
      )
      assert_true(
        blend.backend == @render.RendererBackendKind::SkiaRasterNative,
      )
      assert_true(
        filter.backend == @render.RendererBackendKind::SkiaRasterNative,
      )
      assert_true(
        transform.backend == @render.RendererBackendKind::SkiaRasterNative,
      )
      assert_true(
        shader.backend == @render.RendererBackendKind::SkiaRasterNative,
      )
      assert_true(image.status == @render.RendererFeatureStatus::Supported)
      assert_true(gradient.status == @render.RendererFeatureStatus::Supported)
      assert_true(path.status == @render.RendererFeatureStatus::Supported)
      assert_true(layer.status == @render.RendererFeatureStatus::Supported)
      assert_true(blend.status == @render.RendererFeatureStatus::Supported)
      assert_true(filter.status == @render.RendererFeatureStatus::Supported)
      assert_true(transform.status == @render.RendererFeatureStatus::Supported)
      assert_true(shader.status == @render.RendererFeatureStatus::Supported)
      assert_true(image.note.contains("data URI"))
      assert_true(image.note.contains("JPEG/BMP"))
      assert_true(image.note.contains("local PNG/JPEG/BMP"))
      assert_true(image.note.contains("failed-image placeholders"))
      assert_true(gradient.note.contains("fills and strokes"))
      assert_true(gradient.note.contains("radial"))
      assert_true(path.note.contains("quadratic and cubic"))
      assert_true(layer.note.contains("nested layer/filter"))
      assert_true(blend.note.contains("overlay"))
      assert_true(filter.note.contains("color matrix"))
      assert_true(transform.note.contains("scaled-and-clipped"))
      assert_true(transform.note.contains("filter-scoped"))
      assert_true(shader.note.contains("solid"))
      assert_true(shader.note.contains("linear-gradient-debug"))
      assert_true(shader.note.contains("vignette"))
    }
    _ =>
      fail(
        "expected Skia image, gradient, path, layer, blend, filter, transform, and shader capability records",
      )
  }
}

///|
test "skia filter bindings stay fallback-safe" {
  let matrix : Array[Float] = [
    1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0,
    0.0, 0.0, 0.0, 1.0, 0.0,
  ]
  if skia_available() {
    // ColorFilter/ImageFilter/MaskFilter bindings may be unavailable even
    // when Skia is linked, because the release binary's header structure
    // may not include SkColorFilter.h at compile time. Accept either
    // Some (headers found at compile time) or None (feature not compiled).
    let _ = @skia_native.ColorFilter::matrix(matrix)
    let _ = @skia_native.ImageFilter::blur(2.0, 2.0)
    let _ = @skia_native.MaskFilter::blur(2.0)
  } else {
    assert_true(@skia_native.ColorFilter::matrix(matrix) is None)
    assert_true(@skia_native.ImageFilter::blur(2.0, 2.0) is None)
    assert_true(@skia_native.MaskFilter::blur(2.0) is None)
  }
}

///|
fn find_skia_descriptor_capability(
  descriptor : @render.RendererDescriptor,
  feature : @render.RendererFeature,
) -> @render.RendererBackendFeatureCapability? {
  for capability in descriptor.capabilities {
    if capability.feature == feature {
      return Some(capability)
    }
  }
  None
}

///|
fn skia_test_carets_are_monotonic(carets : Array[Double]) -> Bool {
  if carets.length() <= 1 {
    return true
  }
  for index in 1..<carets.length() {
    if carets[index] < carets[index - 1] {
      return false
    }
  }
  true
}
