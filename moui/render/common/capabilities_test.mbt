///|
fn capability_test_provider(
  id : String,
  backend : @render.RendererBackendKind,
  status : @render.RendererFeatureStatus,
) -> @render.RendererProvider {
  let capabilities = @common.renderer_provider_capabilities(
    provider_id=id,
    backend~,
    capability_for=feature => (status, "\{id} declares \{feature.label()}"),
  )
  @render.RendererProvider::new(
    id~,
    descriptor=@render.RendererDescriptor::new(
      backend~,
      family=Skia,
      presentation=CpuPixelFrame,
      supported_targets=[Native],
      capabilities~,
      description="capability test provider",
    ),
    capabilities=() => capabilities,
    bind=_surface => Rejected("test only"),
  )
}

///|
test "renderer capability report aggregates registered provider ids" {
  let raster = capability_test_provider(
    "skia-raster",
    SkiaRasterNative,
    Supported,
  )
  let canvas = capability_test_provider("canvas2d", Canvas2DWasm, Partial)
  let report = @common.renderer_feature_capability_report([raster, canvas])
  inspect(report.length(), content="17")
  guard @common.renderer_feature_capability([raster, canvas], Gradient)
    is Some(gradient) else {
    fail("expected gradient capability")
  }
  assert_true(gradient.status_for_provider("skia-raster") == Supported)
  assert_true(gradient.status_for_provider("canvas2d") == Partial)
  inspect(
    gradient.note_for_provider("canvas2d"),
    content="canvas2d declares gradient",
  )
  assert_true(gradient.providers.length() == 2)
  assert_true(
    @common.renderer_feature_follow_ups([raster, canvas]).length() ==
    @common.renderer_features().length(),
  )
}

///|
test "renderer capability report ignores an entry with the wrong provider id" {
  let provider = capability_test_provider(
    "registered-id",
    SkiaRasterNative,
    Supported,
  )
  let invalid = @render.RendererProvider::{
    ..provider,
    capabilities: () => {
      [
        @render.RendererBackendFeatureCapability::new(
          provider_id="other-id",
          feature=Rect,
          backend=SkiaRasterNative,
          status=Supported,
        ),
      ]
    },
  }
  guard @common.renderer_feature_capability([invalid], Rect) is Some(rect) else {
    fail("expected rect capability")
  }
  inspect(rect.providers.length(), content="0")
}
