///|
fn contract_descriptor() -> @render.RendererDescriptor {
  @render.RendererDescriptor::new(
    backend=@render.RendererBackendKind::SkiaRasterNative,
    family=@render.RendererFamily::Skia,
    presentation=@render.RendererPresentationModel::CpuPixelFrame,
    supported_targets=[@render.RendererTarget::Native],
    capabilities=[],
    description="renderer contract test",
  )
}

///|
fn contract_surface(
  native_surface? : @render.NativeSurface? = None,
) -> @render.HostSurface {
  @render.HostSurface::new(
    surface_id="contract-surface",
    metrics=@core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=120.0, height=80.0),
      scale_factor=2.0,
    ),
    cpu_present=Some(
      @render.PresentTarget::new(description="contract CPU presenter", present=_ => {
        true
      }),
    ),
    native_surface~,
  )
}

///|
fn contract_session(
  present_count? : () -> Int = () => 0,
  recover? : (String) -> @render.RecoveryResult = _ => {
    @render.RecoveryResult::RecoverySucceeded
  },
  drain? : () -> Array[@render.RendererEvent] = () => [],
  image_records? : () -> Array[@render.ImageResourceRecord] = () => [],
  apply_image_load_completion? : (@render.ImageResourceLoadCompletion) -> Bool = _ => {
    false
  },
  image_source? : @render.HostImageSource = @render.HostImageSource::unavailable(),
  image_decoder? : @render.RendererImageDecoder? = None,
  native_surface? : @render.NativeSurface? = None,
  dispose? : () -> Unit = () => (),
) -> @render.RendererSession {
  @render.RendererSession::new(
    resize=_ => (),
    render_frame=_ => @render.RenderFrameResult::new(presented=true),
    drain_events=Some(drain),
    text_system=() => @core.TextSystem::fallback(),
    present_count~,
    recover~,
    image_records~,
    apply_image_load_completion~,
    image_source~,
    image_decoder~,
    native_surface~,
    dispose~,
  )
}

///|
test "renderer providers bind in order and rejection allocates no session" {
  let calls : Array[String] = []
  let allocations = Ref(0)
  let rejecting = @render.RendererProvider::new(
    id="rejecting",
    descriptor=contract_descriptor(),
    capabilities=() => [],
    bind=_surface => {
      calls.push("rejecting")
      @render.RendererBindResult::Rejected("policy mismatch")
    },
  )
  let accepting = @render.RendererProvider::new(
    id="accepting",
    descriptor=contract_descriptor(),
    capabilities=() => [],
    bind=_surface => {
      calls.push("accepting")
      allocations.val = allocations.val + 1
      @render.RendererBindResult::Bound(contract_session())
    },
  )
  let skipped = @render.RendererProvider::new(
    id="skipped",
    descriptor=contract_descriptor(),
    capabilities=() => [],
    bind=_surface => {
      calls.push("skipped")
      @render.RendererBindResult::Bound(contract_session())
    },
  )
  assert_true(
    @render_common.resolve_renderer(
      [rejecting, accepting, skipped],
      contract_surface(),
    )
    is Some(_),
  )
  assert_eq(calls, ["rejecting", "accepting"])
  inspect(allocations.val, content="1")
}

///|
test "one provider creates independent renderer sessions per window" {
  let next_id = Ref(0)
  let first_disposals = Ref(0)
  let second_disposals = Ref(0)
  let provider = @render.RendererProvider::new(
    id="independent",
    descriptor=contract_descriptor(),
    capabilities=() => [],
    bind=_surface => {
      next_id.val = next_id.val + 1
      let id = next_id.val
      @render.RendererBindResult::Bound(
        contract_session(present_count=() => id, dispose=() => {
          if id == 1 {
            first_disposals.val = first_disposals.val + 1
          } else {
            second_disposals.val = second_disposals.val + 1
          }
        }),
      )
    },
  )
  let first = @render_common.resolve_renderer([provider], contract_surface())
  let second = @render_common.resolve_renderer([provider], contract_surface())
  guard (first, second) is (Some(first), Some(second)) else {
    fail("expected two renderer sessions")
  }
  inspect(first.present_count(), content="1")
  inspect(second.present_count(), content="2")
  first.dispose()
  first.dispose()
  inspect(first_disposals.val, content="1")
  inspect(second_disposals.val, content="0")
  inspect(second.present_count(), content="2")
}

///|
test "renderer session owns recovery image completion and present completion" {
  let recovered : Array[String] = []
  let applied : Array[String] = []
  let events : Ref[Array[@render.RendererEvent]] = Ref([
    @render.RendererEvent::PresentCompleted(
      @render.RenderPresentCompletion::new(
        token=@render.FrameToken::new(surface_generation=2, sequence=3),
        submitted_at_ms=1.0,
        completed_at_ms=2.0,
        presented_at_ms=2.0,
        status=@render.RenderPresentStatus::Presented,
        gpu_context_generation=1,
      ),
    ),
  ])
  let session = contract_session(
    recover=reason => {
      recovered.push(reason)
      @render.RecoveryResult::RecoverySucceeded
    },
    drain=() => {
      let drained = events.val
      events.val = []
      drained
    },
    image_records=() => [@render.ImageResourceRecord::loading("image.png")],
    apply_image_load_completion=completion => {
      applied.push(completion.source)
      true
    },
    image_source=@render.HostImageSource::new(read=_ => Some(b"image")),
    image_decoder=Some(
      @render.RendererImageDecoder::new(decode=(source, _bytes) => {
        @render.ImageResourceLoadCompletion::ready(source, width=8, height=4)
      }),
    ),
  )
  assert_true(
    session.recover("device lost") is @render.RecoveryResult::RecoverySucceeded,
  )
  assert_eq(recovered, ["device lost"])
  inspect(session.image_diagnostics().records().length(), content="1")
  let drained = session.drain_events()
  inspect(drained.length(), content="2")
  let present_completions : Array[@render.RenderPresentCompletion] = []
  let mut image_request : @render.RendererImageLoadRequest? = None
  for event in drained {
    match event {
      @render.RendererEvent::PresentCompleted(completion) =>
        present_completions.push(completion)
      @render.RendererEvent::ImageLoadRequested(request) =>
        image_request = Some(request)
    }
  }
  assert_true(
    @render.render_present_completions_have_presented(present_completions),
  )
  guard image_request is Some(request) else { fail("expected image request") }
  let completion = request.load()
  assert_true(
    session.apply_image_load_completion(completion)
    is @render.RendererImageCompletionResult::Applied(true),
  )
  assert_true(
    session.apply_image_load_completion(completion)
    is @render.RendererImageCompletionResult::Stale,
  )
  assert_eq(applied, ["image.png"])
  session.dispose()
  assert_true(
    session.apply_image_load_completion(completion)
    is @render.RendererImageCompletionResult::Disposed,
  )
}

///|
test "opaque native surface validates handles and disposes exactly once" {
  assert_true(@render.NativeSurface::new(surface_handle=0UL) is None)
  assert_true(
    @render.NativeSurface::new(surface_handle=7UL, display_handle=Some(0UL))
    is None,
  )
  let surface_disposals = Ref(0)
  guard @render.NativeSurface::new(
      surface_handle=7UL,
      display_handle=Some(11UL),
      dispose=() => surface_disposals.val = surface_disposals.val + 1,
    )
    is Some(native_surface) else {
    fail("expected validated native surface")
  }
  inspect(native_surface.surface_handle(), content="7")
  assert_true(native_surface.display_handle() == Some(11UL))
  let renderer_disposals = Ref(0)
  let session = contract_session(native_surface=Some(native_surface), dispose=() => {
    renderer_disposals.val = renderer_disposals.val + 1
  })
  session.dispose()
  session.dispose()
  inspect(renderer_disposals.val, content="1")
  inspect(surface_disposals.val, content="1")
}

///|
test "renderer-owned native policy can reject an otherwise opaque surface" {
  let allocations = Ref(0)
  let requires_display = @render.RendererProvider::new(
    id="requires-display",
    descriptor=contract_descriptor(),
    capabilities=() => [],
    bind=surface => {
      match surface.native_surface() {
        Some(native) if native.display_handle() is Some(_) => {
          allocations.val = allocations.val + 1
          @render.RendererBindResult::Bound(contract_session())
        }
        _ => @render.RendererBindResult::Rejected("display handle required")
      }
    },
  )
  guard @render.NativeSurface::new(surface_handle=9UL) is Some(native_surface) else {
    fail("expected surface-only capability")
  }
  assert_true(
    @render_common.resolve_renderer(
      [requires_display],
      contract_surface(native_surface=Some(native_surface)),
    )
    is None,
  )
  inspect(allocations.val, content="0")
}
