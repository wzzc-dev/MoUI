///|
fn provider_test_descriptor() -> @render.RendererDescriptor {
  @render.RendererDescriptor::new(
    backend=SkiaRasterNative,
    family=Skia,
    presentation=CpuPixelFrame,
    supported_targets=[Native],
    capabilities=[],
    description="provider test",
  )
}

///|
fn provider_test_session(
  native_surface? : @render.NativeSurface? = None,
  dispose? : () -> Unit = () => (),
) -> @render.RendererSession {
  @render.RendererSession::new(
    resize=_metrics => (),
    render_frame=_frame => @render.RenderFrameResult::new(presented=true),
    text_system=() => @core.TextSystem::fallback(),
    native_surface~,
    dispose~,
  )
}

///|
fn provider_test_surface(
  native_surface? : @render.NativeSurface? = None,
) -> @render.HostSurface {
  @render.HostSurface::new(
    surface_id="test-surface",
    metrics=@core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=100.0, height=50.0),
      scale_factor=2.0,
    ),
    cpu_present=Some(
      @render.PresentTarget::new(description="test", present=_frame => true),
    ),
    native_surface~,
  )
}

///|
fn provider_test_provider(
  id : String,
  accepts : Bool,
  bind_count : Ref[Int],
  allocation_count : Ref[Int],
) -> @render.RendererProvider {
  @render.RendererProvider::new(
    id~,
    descriptor=provider_test_descriptor(),
    capabilities=() => [],
    bind=surface => {
      bind_count.val = bind_count.val + 1
      if !accepts {
        return Rejected("rejected by test")
      }
      if surface.cpu_present() is None {
        return Rejected("missing CPU presenter")
      }
      allocation_count.val = allocation_count.val + 1
      Bound(provider_test_session())
    },
  )
}

///|
test "resolve_renderer stops after the first bound provider" {
  let first_bind_count = Ref(0)
  let second_bind_count = Ref(0)
  let first_allocations = Ref(0)
  let second_allocations = Ref(0)
  let session = @render_common.resolve_renderer(
    [
      provider_test_provider("first", true, first_bind_count, first_allocations),
      provider_test_provider(
        "second", true, second_bind_count, second_allocations,
      ),
    ],
    provider_test_surface(),
  )
  assert_true(session is Some(_))
  inspect(first_bind_count.val, content="1")
  inspect(first_allocations.val, content="1")
  inspect(second_bind_count.val, content="0")
  inspect(second_allocations.val, content="0")
}

///|
test "resolve_renderer advances after side-effect-free rejection" {
  let first_bind_count = Ref(0)
  let second_bind_count = Ref(0)
  let first_allocations = Ref(0)
  let second_allocations = Ref(0)
  let session = @render_common.resolve_renderer(
    [
      provider_test_provider(
        "first", false, first_bind_count, first_allocations,
      ),
      provider_test_provider(
        "second", true, second_bind_count, second_allocations,
      ),
    ],
    provider_test_surface(),
  )
  assert_true(session is Some(_))
  inspect(first_bind_count.val, content="1")
  inspect(first_allocations.val, content="0")
  inspect(second_bind_count.val, content="1")
  inspect(second_allocations.val, content="1")
}

///|
test "native surface rejects zero handles" {
  assert_true(@render.NativeSurface::new(surface_handle=0UL) is None)
  assert_true(
    @render.NativeSurface::new(surface_handle=1UL, display_handle=Some(0UL))
    is None,
  )
}

///|
test "renderer session disposes renderer and native surface exactly once" {
  let renderer_disposals = Ref(0)
  let surface_disposals = Ref(0)
  guard @render.NativeSurface::new(surface_handle=7UL, dispose=() => {
      surface_disposals.val = surface_disposals.val + 1
    })
    is Some(native_surface) else {
    fail("expected valid native surface")
  }
  let session = provider_test_session(native_surface=Some(native_surface), dispose=() => {
    renderer_disposals.val = renderer_disposals.val + 1
  })
  session.dispose()
  session.dispose()
  inspect(renderer_disposals.val, content="1")
  inspect(surface_disposals.val, content="1")
  guard session.recover("after dispose") is RecoveryFailed(message) else {
    fail("expected disposed recovery failure")
  }
  inspect(message, content="renderer session is disposed")
}
