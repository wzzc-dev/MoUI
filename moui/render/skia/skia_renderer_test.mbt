///|
test "skia renderer backend info reflects native availability" {
  let info = backend_info()
  assert_true(info.backend == @render.RendererBackendKind::SkiaRasterNative)
  assert_true(info.owns_surface)
  if skia_available() {
    assert_true(info.status == @render.RendererCapabilityStatus::Ready)
    assert_true(info.can_render)
  } else {
    assert_true(info.status == @render.RendererCapabilityStatus::Unavailable)
    assert_false(info.can_render)
  }
}

///|
test "skia renderer spec is a skia cpu pixel backend" {
  let spec = renderer_spec()
  assert_true(spec.backend == @render.RendererBackendKind::SkiaRasterNative)
  assert_true(spec.family == @render.RendererFamily::Skia)
  assert_true(
    spec.presentation == @render.RendererPresentationModel::CpuPixelFrame,
  )
  inspect(spec.capabilities.length(), content="17")
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
test "skia renderer spec exposes fallback-gated backend capabilities" {
  let spec = skia_raster_native_spec()
  let image = find_skia_spec_capability(spec, @render.RendererFeature::Image)
  let filter = find_skia_spec_capability(
    spec,
    @render.RendererFeature::FilterEffect,
  )
  match (image, filter) {
    (Some(image), Some(filter)) => {
      assert_true(
        image.backend == @render.RendererBackendKind::SkiaRasterNative,
      )
      assert_true(
        filter.backend == @render.RendererBackendKind::SkiaRasterNative,
      )
      assert_true(image.status == @render.RendererFeatureStatus::Unavailable)
      assert_true(filter.status == @render.RendererFeatureStatus::Unavailable)
      assert_true(image.note.contains("decode"))
      assert_true(filter.note.contains("color-filter"))
    }
    _ => fail("expected Skia image and filter capability records")
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
fn find_skia_spec_capability(
  spec : @render.RendererSpec,
  feature : @render.RendererFeature,
) -> @render.RendererBackendFeatureCapability? {
  for capability in spec.capabilities {
    if capability.feature == feature {
      return Some(capability)
    }
  }
  None
}
