///|
fn image_task_test_session(applied : Ref[Int]) -> @render.RendererSession {
  @render.RendererSession::new(
    resize=_ => (),
    render_frame=_ => @render.RenderFrameResult::new(presented=true),
    text_system=() => @core.TextSystem::fallback(),
    image_records=() => [@render.ImageResourceRecord::loading("asset.png")],
    apply_image_load_completion=completion => {
      applied.val = applied.val + 1
      completion.status
      is @render.ImageResourceLoadCompletionStatus::ImageLoadReady
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
      @render.RendererEvent::ImageLoadRequested(request) => return request
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
  let tasks = WindowImageTasks::new(
    starter=WindowImageTaskStarter::new(start=(_request, complete) => {
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
