///|
fn binding_test_provider(id : String, accepts : Bool) -> RendererProvider {
  {
    id,
    descriptor: RendererDescriptor::new(
      backend=RendererBackendKind::SkiaRasterNative,
      family=RendererFamily::Skia,
      presentation=RendererPresentationModel::CpuPixelFrame,
      supported_targets=[RendererTarget::Native],
      capabilities=[],
      description="binding test provider",
    ),
    capabilities: () => [],
    negotiate: surface => {
      if accepts {
        match surface {
          SurfaceDescriptor::CpuRaster(width, height, scale_factor) =>
            SurfaceNegotiationResult::SurfaceAccepted(
              BoundSurface::new(
                kind=RendererPresentationModel::CpuPixelFrame,
                route=SkiaSurfaceRoute::RasterSurfaceRoute,
                metrics=RendererSurfaceMetrics::from_logical(
                  size=@core.Size::new(width~, height~),
                  scale_factor~,
                ),
              ),
            )
          SurfaceDescriptor::GpuSurface(_, _, _, _) =>
            SurfaceNegotiationResult::SurfaceRejected("unexpected surface")
        }
      } else {
        SurfaceNegotiationResult::SurfaceRejected("rejected by test")
      }
    },
    create: (_metrics, _surface) => RendererInstance::{
      render_frame: _frame => RenderFrameResult::new(presented=false),
      recover: _reason => RecoveryResult::RecoverySucceeded,
      dispose: () => (),
    },
  }
}

///|
fn binding_test_host_renderer() -> HostWindowRenderer {
  HostWindowRenderer::new(resize=_metrics => (), render=_commands => (), text_system=() => {
    @core.TextSystem::fallback()
  })
}

///|
test "RendererProviderBinding selects by registration negotiation" {
  let rejected = RendererProviderBinding::new(
    provider=binding_test_provider("first", false),
    create_host_renderer=(_metrics, _surface) => binding_test_host_renderer(),
  )
  let accepted = RendererProviderBinding::new(
    provider=binding_test_provider("second", true),
    create_host_renderer=(_metrics, _surface) => binding_test_host_renderer(),
  )
  guard select_renderer_provider_binding(
      [rejected, accepted],
      SurfaceDescriptor::cpu_raster(width=100.0, height=50.0, scale_factor=2.0),
    )
    is Some((binding, bound)) else {
    fail("expected an accepted binding")
  }
  inspect(binding.provider().id, content="second")
  assert_true(bound.metrics().physical_size.width == 200.0)
}

///|
test "RendererProviderBinding projects providers for diagnostics" {
  let provider = binding_test_provider("diagnostic-provider", true)
  let binding = RendererProviderBinding::new(provider~, create_host_renderer=(
    _metrics,
    _surface,
  ) => binding_test_host_renderer())
  let providers = renderer_provider_binding_providers([binding])
  inspect(providers[0].id, content="diagnostic-provider")
}
