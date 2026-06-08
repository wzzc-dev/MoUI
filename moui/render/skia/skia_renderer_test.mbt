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
  assert_true(info.description.contains("text maturity audit partial"))
  assert_true(info.description.contains("mixed-run fallback ready"))
  assert_true(
    info.description.contains("Unicode 17 grapheme boundary contract ready"),
  )
  assert_true(info.description.contains("bidi, paragraph line breaking"))
  assert_true(info.description.contains("flush-and-submit finalization"))
  if skia_available() {
    assert_true(info.status == @render.RendererCapabilityStatus::Ready)
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
  let metrics = @render.RendererSurfaceMetrics::from_logical(
    size=@core.Size::new(width=16.0, height=16.0),
  )
  let gpu_result = try? create_with_present_target_and_route(
    metrics,
    target,
    surface_route=SkiaSurfaceRoute::MetalGpuSurfaceRoute,
  )
  if !skia_available() {
    match gpu_result {
      Err(SkiaRendererError::SkiaUnavailable) => ()
      _ => fail("expected unavailable Skia before GPU route creation")
    }
  } else {
    let descriptor = @moui_skia.GpuContextDescriptor::metal(
      b"moui-render-skia-metal-gpu",
    )
    let status = @skia_native.Surface::gpu_context_support_status(descriptor)
    if status.is_available() {
      match gpu_result {
        Ok(renderer) => {
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
        }
        Err(err) => fail("expected GPU renderer route, got \{err.message()}")
      }
    } else {
      match gpu_result {
        Err(SkiaRendererError::GpuContextUnavailable(_)) => ()
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
    let result = try? create_with_present_target(
      @render.RendererSurfaceMetrics::from_logical(
        size=@core.Size::new(width=16.0, height=16.0),
      ),
      target,
    )
    match result {
      Err(SkiaRendererError::SkiaUnavailable) => ()
      _ => fail("expected explicit unavailable error")
    }
    let empty_font_result = try? create_with_present_target(
      @render.RendererSurfaceMetrics::from_logical(
        size=@core.Size::new(width=16.0, height=16.0),
      ),
      target,
      font_resolution=SkiaFontResolution::EmptyTypeface,
    )
    match empty_font_result {
      Err(SkiaRendererError::SkiaUnavailable) => ()
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
test "skia selection geometry proof covers line ranges hit testing and bidi evidence" {
  let text = "ABC \u{05D0}\u{05D1}\u{05D2} 123 alpha beta gamma"
  guard skia_text_selection_geometry_proof(
      text,
      font=@core.FontSpec::new(size=18.0, weight=500),
      max_width=96.0,
    )
    is Some(proof) else {
    fail("expected Skia selection geometry proof")
  }
  assert_true(proof.selection_rect_count >= 2)
  assert_true(proof.selected_line_count >= 2)
  assert_true(proof.line_count >= 2)
  inspect(proof.hit_test_line_index, content="1")
  assert_true(proof.hit_test_inside)
  assert_true(proof.hit_test_offset >= proof.selection_range.start)
  if skia_available() {
    assert_true(proof.visual_order_differs)
    assert_true(proof.visual_segment_count >= 3)
    assert_true(proof.bidi_visual_order_evidence)
  }
}

///|
test "skia emoji font fallback proof records glyph metadata without readiness promotion" {
  match skia_emoji_font_fallback_proof() {
    Some(proof) => {
      inspect(proof.font_family, content="emoji")
      inspect(proof.font_source, content="skia-system-fontmgr")
      inspect(proof.fallback_language_tags.length(), content="2")
      inspect(proof.fallback_language_tags[0], content="und-Zsye")
      inspect(proof.fallback_language_tags[1], content="en")
      inspect(proof.fallback_script_tag, content="und-Zsye")
      inspect(proof.fallback_language_tag_count, content="2")
      inspect(proof.fallback_request_language_count, content="2")
      assert_true(proof.text_system_id == "skia-raster-text-system")
      assert_true(proof.emoji_hint)
      assert_true(proof.emoji_fallback_attempted)
      assert_true(proof.fallback_request_ready)
      assert_true(proof.missing_glyph_recovery_ready)
      assert_false(proof.deterministic_color_emoji_ready)
      inspect(proof.glyph_format, content="rgba")
      assert_true(proof.glyph_key.contains("skia-system-fontmgr"))
      assert_true(proof.glyph_key.contains("skia-raster-text-system"))
      assert_true(proof.glyph_key.contains("script=und-Zsye"))
      assert_true(proof.glyph_key.contains("langs=2"))
      assert_true(proof.glyph_key.contains("emoji-u+"))
      assert_true(proof.glyph_key.contains("rgba"))
      assert_true(proof.glyph_count >= 1)
      assert_true(proof.cluster_count == 1)
      assert_true(proof.glyph_width > 0)
      assert_true(proof.glyph_height > 0)
      assert_true(proof.resolved_missing_glyph_count >= 0)
      assert_true(proof.fallback_character == 0x1F469)
    }
    None => assert_true(!skia_available())
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
  let frame = SkiaPixelFrame::{
    width: 1,
    height: 1,
    row_bytes: 4,
    scale_factor: 2.0,
    pixels: b"\x00\x00\x00\xff",
  }
  let presented = Ref(false)
  let target = SkiaPresentTarget::new(description="test", present=next => {
    presented.val = next == frame
    true
  })
  assert_true((target.present)(frame))
  assert_true(presented.val)
}

///|
test "skia renderer descriptor exposes evidence-gated backend capabilities" {
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
      assert_true(image.status == @render.RendererFeatureStatus::Ready)
      assert_true(gradient.status == @render.RendererFeatureStatus::Ready)
      assert_true(path.status == @render.RendererFeatureStatus::Ready)
      assert_true(layer.status == @render.RendererFeatureStatus::Ready)
      assert_true(blend.status == @render.RendererFeatureStatus::Ready)
      assert_true(filter.status == @render.RendererFeatureStatus::Ready)
      assert_true(transform.status == @render.RendererFeatureStatus::Ready)
      assert_true(shader.status == @render.RendererFeatureStatus::Ready)
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
    0.0, 0.0, 1.0, 0.0,
  ]
  if skia_available() {
    assert_true(@skia_native.ColorFilter::matrix(matrix) is Some(_))
    assert_true(@skia_native.ImageFilter::blur(2.0, 2.0) is Some(_))
    assert_true(@skia_native.MaskFilter::blur(2.0) is Some(_))
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
