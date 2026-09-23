///|
fn image_task_test_session(applied : Ref[Int]) -> @render.RendererSession {
  @render.RendererSession::new(
    resize=_ => (),
    render_frame=_ => @render.RenderFrameResult::new(presented=true),
    text_system=() => @core.TextSystem::fallback(),
    image_records=() => [@render.ImageResourceRecord::loading("asset.png")],
    apply_image_load_completion=completion => {
      applied.val = applied.val + 1
      completion.status is ImageLoadReady
    },
    image_source=@render.HostImageSource::new(read=_ => Some(b"image")),
    image_decoder=Some(
      @render.RendererImageDecoder::new(decode=(source, _bytes) => {
        @render.ImageResourceLoadCompletion::ready(source, width=1, height=1)
      }),
    ),
  )
}

///|
fn next_image_request(
  renderer : @render.RendererSession,
  sequence : Int,
) -> @render.RendererImageLoadRequest {
  ignore(
    renderer.render_frame(
      @render.RenderFrameSubmission::new(
        token=@render.FrameToken::new(surface_generation=1, sequence~),
        frame=@core.DrawFrame::new(
          commands=[],
          damage=@core.DamageRegion::full("image task test"),
        ),
      ),
    ),
  )
  for event in renderer.drain_events() {
    match event {
      ImageLoadRequested(request) => return request
      _ => ()
    }
  }
  abort("expected renderer image request")
}

///|
test "window image tasks de-duplicate, apply once, and ignore late completion" {
  let applied = Ref(0)
  let redraws = Ref(0)
  let cancellations = Ref(0)
  let completion_slot : Ref[((@render.RendererImageLoadCompletion) -> Unit)?] = Ref(
    None,
  )
  let renderer = image_task_test_session(applied)
  let tasks = @image.WindowImageTasks::new(
    starter=@image.WindowImageTaskStarter::new(start=(_request, complete) => {
      completion_slot.val = Some(complete)
      Some(() => cancellations.val = cancellations.val + 1)
    }),
    request_redraw=() => redraws.val = redraws.val + 1,
  )
  let request = next_image_request(renderer, 1)
  assert_true(tasks.schedule(renderer, request))
  assert_false(tasks.schedule(renderer, request))
  inspect(tasks.pending_count(), content="1")
  inspect(tasks.take_scheduled_count(), content="1")
  inspect(tasks.take_scheduled_count(), content="0")
  guard completion_slot.val is Some(complete) else {
    fail("expected deferred image completion")
  }
  let completion = request.load()
  complete(completion)
  complete(completion)
  inspect(applied.val, content="1")
  inspect(redraws.val, content="1")
  inspect(tasks.pending_count(), content="0")
  inspect(cancellations.val, content="0")

  let cancelled_request = next_image_request(renderer, 2)
  assert_true(tasks.schedule(renderer, cancelled_request))
  guard completion_slot.val is Some(late_complete) else {
    fail("expected cancellable image completion")
  }
  inspect(tasks.cancel(), content="1")
  inspect(cancellations.val, content="1")
  late_complete(cancelled_request.load())
  inspect(applied.val, content="1")
  inspect(redraws.val, content="1")
  tasks.dispose()
  tasks.dispose()
  assert_false(tasks.schedule(renderer, cancelled_request))
}

///|
fn deferred_image_starter_session(
  source : String,
  applied : Ref[Int],
  bytes_len : Ref[Int],
) -> @render.RendererSession {
  @render.RendererSession::new(
    resize=_ => (),
    render_frame=_ => @render.RenderFrameResult::new(presented=true),
    text_system=() => @core.TextSystem::fallback(),
    image_records=() => [@render.ImageResourceRecord::loading(source)],
    apply_image_load_completion=completion => {
      applied.val = applied.val + 1
      completion.status is ImageLoadReady
    },
    image_source=@render.HostImageSource::new(read=_ => Some(b"local")),
    image_decoder=Some(
      @render.RendererImageDecoder::new(decode=(source, bytes) => {
        bytes_len.val = match bytes {
          Some(data) => data.length()
          None => -1
        }
        @render.ImageResourceLoadCompletion::ready(source, width=2, height=1)
      }),
    ),
  )
}

///|
test "deferred image starter fetches remote sources through the worker" {
  let applied = Ref(0)
  let redraws = Ref(0)
  let fetch_calls = Ref(0)
  let spawns = Ref(0)
  let posts = Ref(0)
  let bytes_len = Ref(0)
  let renderer = deferred_image_starter_session(
    "https://example.com/mark.svg", applied, bytes_len,
  )
  let tasks = @image.WindowImageTasks::new(
    starter=@image.WindowImageTaskStarter::deferred(
      fetch=_source => {
        fetch_calls.val = fetch_calls.val + 1
        Some(b"remote-bytes")
      },
      spawn=task => {
        spawns.val = spawns.val + 1
        task()
        None
      },
      post=task => {
        posts.val = posts.val + 1
        task()
      },
    ),
    request_redraw=() => redraws.val = redraws.val + 1,
  )
  let request = next_image_request(renderer, 1)
  assert_true(tasks.schedule(renderer, request))
  // The worker fetched, then marshalled the completion back exactly once.
  inspect(fetch_calls.val, content="1")
  inspect(spawns.val, content="1")
  inspect(posts.val, content="1")
  // The decoder observed the fetched payload, not a second read of the source.
  inspect(bytes_len.val, content="12")
  inspect(applied.val, content="1")
  inspect(redraws.val, content="1")
  inspect(tasks.pending_count(), content="0")
}

///|
test "deferred image starter completes local sources without a worker" {
  let applied = Ref(0)
  let redraws = Ref(0)
  let spawns = Ref(0)
  let posts = Ref(0)
  let fetches = Ref(0)
  let bytes_len = Ref(0)
  let renderer = deferred_image_starter_session(
    "/tmp/notes/local.png", applied, bytes_len,
  )
  let tasks = @image.WindowImageTasks::new(
    starter=@image.WindowImageTaskStarter::deferred(
      fetch=_source => {
        fetches.val = fetches.val + 1
        None
      },
      spawn=_task => {
        spawns.val = spawns.val + 1
        None
      },
      post=_task => posts.val = posts.val + 1,
    ),
    request_redraw=() => redraws.val = redraws.val + 1,
  )
  let request = next_image_request(renderer, 1)
  assert_true(tasks.schedule(renderer, request))
  // A local source never leaves the UI thread.
  inspect(fetches.val, content="0")
  inspect(spawns.val, content="0")
  inspect(posts.val, content="0")
  // `local` came from the host image source through the synchronous path.
  inspect(bytes_len.val, content="5")
  inspect(applied.val, content="1")
  inspect(redraws.val, content="1")
}
