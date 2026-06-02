///|
test "skia renderer backend info reflects native availability" {
  let info = backend_info()
  assert_true(info.backend == @render.RendererBackendKind::SkiaRasterNative)
  assert_true(info.owns_surface)
  assert_true(info.description.contains("SurfaceTargetDescriptor"))
  assert_true(info.description.contains("finalization preflight"))
  assert_true(info.description.contains("text fallback/shaping descriptor"))
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
      assert_true(image.note.contains("local PNG"))
      assert_true(image.note.contains("failed-image placeholders"))
      assert_true(gradient.note.contains("fills and strokes"))
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
