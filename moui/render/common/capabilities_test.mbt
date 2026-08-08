///|
fn capability_test_provider(
  id : String,
  backend : @render.RendererBackendKind,
  status : @render.RendererFeatureStatus,
) -> @render.RendererProvider {
  let capabilities = renderer_provider_capabilities(provider_id=id, backend~, capability_for=feature => {
    (status, "\{id} declares \{feature.label()}")
  })
  @render.RendererProvider::new(
    id~,
    descriptor=@render.RendererDescriptor::new(
      backend~,
      family=@render.RendererFamily::Skia,
      presentation=@render.RendererPresentationModel::CpuPixelFrame,
      supported_targets=[@render.RendererTarget::Native],
      capabilities~,
      description="capability test provider",
    ),
    capabilities=() => capabilities,
    bind=_surface => @render.RendererBindResult::Rejected("test only"),
  )
}

///|
test "renderer capability report aggregates registered provider ids" {
  let raster = capability_test_provider(
    "skia-raster",
    @render.RendererBackendKind::SkiaRasterNative,
    @render.RendererFeatureStatus::Supported,
  )
  let canvas = capability_test_provider(
    "canvas2d",
    @render.RendererBackendKind::Canvas2DWasm,
    @render.RendererFeatureStatus::Partial,
  )
  let report = renderer_feature_capability_report([raster, canvas])
  inspect(report.length(), content="17")
  guard renderer_feature_capability(
      [raster, canvas],
      @render.RendererFeature::Gradient,
    )
    is Some(gradient) else {
    fail("expected gradient capability")
  }
  assert_true(
    gradient.status_for_provider("skia-raster") ==
    @render.RendererFeatureStatus::Supported,
  )
  assert_true(
    gradient.status_for_provider("canvas2d") ==
    @render.RendererFeatureStatus::Partial,
  )
  inspect(
    gradient.note_for_provider("canvas2d"),
    content="canvas2d declares gradient",
  )
  assert_true(gradient.providers.length() == 2)
  assert_true(
    renderer_feature_follow_ups([raster, canvas]).length() ==
    renderer_features().length(),
  )
}

///|
test "renderer capability report ignores an entry with the wrong provider id" {
  let provider = capability_test_provider(
    "registered-id",
    @render.RendererBackendKind::SkiaRasterNative,
    @render.RendererFeatureStatus::Supported,
  )
  let invalid = @render.RendererProvider::{
    ..provider,
    capabilities: () => {
      [
        @render.RendererBackendFeatureCapability::new(
          provider_id="other-id",
          feature=@render.RendererFeature::Rect,
          backend=@render.RendererBackendKind::SkiaRasterNative,
          status=@render.RendererFeatureStatus::Supported,
        ),
      ]
    },
  }
  guard renderer_feature_capability([invalid], @render.RendererFeature::Rect)
    is Some(rect) else {
    fail("expected rect capability")
  }
  inspect(rect.providers.length(), content="0")
}
