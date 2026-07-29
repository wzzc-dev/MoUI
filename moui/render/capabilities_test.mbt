///|
fn capability_test_provider(
  id : String,
  backend : RendererBackendKind,
  status : RendererFeatureStatus,
) -> RendererProvider {
  let capabilities = renderer_provider_capabilities(provider_id=id, backend~, capability_for=feature => {
    (status, "\{id} declares \{feature.label()}")
  })
  {
    id,
    descriptor: RendererDescriptor::new(
      backend~,
      family=RendererFamily::Skia,
      presentation=RendererPresentationModel::CpuPixelFrame,
      supported_targets=[RendererTarget::Native],
      capabilities~,
      description="capability test provider",
    ),
    capabilities: () => capabilities,
    negotiate: _surface => {
      SurfaceNegotiationResult::SurfaceRejected("test only")
    },
    create: (_metrics, _surface) => RendererInstance::{
      render_frame: _frame => RenderFrameResult::new(presented=false),
      recover: _reason => RecoveryResult::RecoverySucceeded,
      dispose: () => (),
    },
  }
}

///|
test "renderer capability report aggregates registered provider ids" {
  let raster = capability_test_provider(
    "skia-raster",
    RendererBackendKind::SkiaRasterNative,
    RendererFeatureStatus::Supported,
  )
  let canvas = capability_test_provider(
    "canvas2d",
    RendererBackendKind::Canvas2DWasm,
    RendererFeatureStatus::Partial,
  )
  let report = renderer_feature_capability_report([raster, canvas])
  inspect(report.length(), content="17")
  guard renderer_feature_capability([raster, canvas], RendererFeature::Gradient)
    is Some(gradient) else {
    fail("expected gradient capability")
  }
  assert_true(
    gradient.status_for_provider("skia-raster") ==
    RendererFeatureStatus::Supported,
  )
  assert_true(
    gradient.status_for_provider("canvas2d") == RendererFeatureStatus::Partial,
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
    RendererBackendKind::SkiaRasterNative,
    RendererFeatureStatus::Supported,
  )
  let invalid = RendererProvider::{
    ..provider,
    capabilities: () => {
      [
        RendererBackendFeatureCapability::new(
          provider_id="other-id",
          feature=RendererFeature::Rect,
          backend=RendererBackendKind::SkiaRasterNative,
          status=RendererFeatureStatus::Supported,
        ),
      ]
    },
  }
  guard renderer_feature_capability([invalid], RendererFeature::Rect)
    is Some(rect) else {
    fail("expected rect capability")
  }
  inspect(rect.providers.length(), content="0")
}
