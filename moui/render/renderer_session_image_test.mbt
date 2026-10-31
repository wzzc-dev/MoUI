///|
/// Black-box coverage for the renderer image-request hot path: the
/// pending map dedup, the optional records-generation gate, and the
/// completion lifecycle wiring pattern production renderers use.

///|
fn image_test_decoder() -> @render.RendererImageDecoder {
  @render.RendererImageDecoder::new(decode=(source, _bytes) => {
    @render.ImageResourceLoadCompletion::ready(source, width=1, height=1)
  })
}

///|
fn image_request_sources(
  events : Array[@render.RendererEvent],
) -> Array[String] {
  let sources : Array[String] = []
  for event in events {
    match event {
      @render.ImageLoadRequested(request) => sources.push(request.source())
      @render.PresentCompleted(_) => ()
    }
  }
  sources
}

///|
fn image_test_session(
  records~ : () -> Array[@render.ImageResourceRecord],
  generation~ : (() -> Int64)?,
  apply~ : (@render.ImageResourceLoadCompletion) -> Bool,
) -> @render.RendererSession {
  @render.RendererSession::new(
    resize=_ => (),
    render_frame=_ => @render.RenderFrameResult::new(presented=true),
    text_system=() => @core.TextSystem::fallback(),
    image_records=records,
    image_records_generation=generation,
    apply_image_load_completion=apply,
    image_decoder=Some(image_test_decoder()),
  )
}

///|
test "image requests are issued once per loading source" {
  let records : Array[@render.ImageResourceRecord] = [
    @render.ImageResourceRecord::loading("a.png"),
    @render.ImageResourceRecord::ready("b.png", width=1, height=1),
    @render.ImageResourceRecord::loading("c.png"),
  ]
  let session = image_test_session(
    records=() => records.copy(),
    generation=None,
    apply=_ => true,
  )
  let first = session.drain_events()
  assert_eq(image_request_sources(first), ["a.png", "c.png"])
  assert_eq(session.image_diagnostics().pending_request_count(), 2)
  // Every later frame re-offers the same records; the pending index
  // keeps already-requested sources from being requested twice.
  let _ = session.drain_events()
  let _ = session.drain_events()
  assert_eq(image_request_sources(session.drain_events()), [])
  assert_eq(session.image_diagnostics().pending_request_count(), 2)
}

///|
test "an unchanged generation skips the records pull entirely" {
  let records_pulls = Ref(0)
  let generation = Ref(0L)
  let session = image_test_session(
    records=() => {
      records_pulls.val = records_pulls.val + 1
      [@render.ImageResourceRecord::loading("g.png")]
    },
    generation=Some(() => generation.val),
    apply=_ => true,
  )
  let first = session.drain_events()
  assert_eq(image_request_sources(first), ["g.png"])
  assert_eq(records_pulls.val, 1)
  // The provider is not consulted again while the generation stands
  // still — zero re-scans across any number of frames.
  let _ = session.drain_events()
  let _ = session.drain_events()
  assert_eq(records_pulls.val, 1)
  // Advancing the generation without a record change costs exactly one
  // pull and produces no duplicate request for the pending source.
  generation.val = generation.val + 1L
  assert_eq(image_request_sources(session.drain_events()), [])
  assert_eq(records_pulls.val, 2)
  let _ = session.drain_events()
  assert_eq(records_pulls.val, 2)
}

///|
test "a newly loading record is requested on the next scan" {
  let records_pulls = Ref(0)
  let generation = Ref(0L)
  let records : Array[@render.ImageResourceRecord] = [
    @render.ImageResourceRecord::loading("old.png"),
  ]
  let session = image_test_session(
    records=() => {
      records_pulls.val = records_pulls.val + 1
      records.copy()
    },
    generation=Some(() => generation.val),
    apply=_ => true,
  )
  let first = session.drain_events()
  assert_eq(image_request_sources(first), ["old.png"])
  assert_eq(records_pulls.val, 1)
  // The provider changes and its generation advances with it: exactly
  // one rescan, surfacing only the new request.
  records.push(@render.ImageResourceRecord::loading("new.png"))
  generation.val = generation.val + 1L
  let second = session.drain_events()
  assert_eq(image_request_sources(second), ["new.png"])
  assert_eq(records_pulls.val, 2)
  let _ = session.drain_events()
  assert_eq(records_pulls.val, 2)
}

///|
test "lifecycle generation wiring rescans exactly when records change" {
  let lifecycle = @render_common.ImageResourceLifecycle::new()
  let records_pulls = Ref(0)
  let session = image_test_session(
    records=() => {
      records_pulls.val = records_pulls.val + 1
      lifecycle.snapshot()
    },
    generation=Some(() => lifecycle.generation()),
    apply=completion => lifecycle.apply_load_completion(completion),
  )
  ignore(lifecycle.mark_loading("g.png"))
  let first = session.drain_events()
  assert_eq(image_request_sources(first), ["g.png"])
  assert_eq(records_pulls.val, 1)
  let _ = session.drain_events()
  assert_eq(records_pulls.val, 1)
  // Apply the completion through the session contract: the record
  // leaves ImageLoading, the lifecycle generation advances, and the
  // next scan pulls exactly once without re-requesting the source.
  guard first[0] is @render.ImageLoadRequested(request) else {
    abort("expected an image load request")
  }
  let completion = @render.RendererImageLoadCompletion::new(
    token=request.token(),
    result=@render.ImageResourceLoadCompletion::ready(
      request.source(),
      width=2,
      height=3,
    ),
  )
  guard session.apply_image_load_completion(completion) is Applied(_) else {
    abort("completion must apply to the pending token")
  }
  guard lifecycle.lookup("g.png") is Some(record) else {
    abort("completed record must be tracked")
  }
  assert_true(record.status is ImageReady)
  let after = session.drain_events()
  assert_eq(records_pulls.val, 2)
  assert_eq(image_request_sources(after), [])
  let _ = session.drain_events()
  assert_eq(records_pulls.val, 2)
  // A stale token (already taken) applies nothing and must not force a
  // rescan of unchanged records.
  guard session.apply_image_load_completion(completion) is Stale else {
    abort("replaying the taken token must be stale")
  }
  let _ = session.drain_events()
  assert_eq(records_pulls.val, 2)
}
