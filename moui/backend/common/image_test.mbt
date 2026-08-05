///|
test "host window renderer forwards lifecycle closures" {
  let resized = Ref(@core.Size::new(width=0.0, height=0.0))
  let rendered = Ref(0)
  let disposed = Ref(0)
  let presenter = Ref(3)
  let callback_sets = Ref(0)
  let callback_revisions : Array[Int] = []
  let completion_sources : Array[String] = []
  let image_records = [
    @render.ImageResourceRecord::ready("loaded.png", width=32, height=18),
    @render.ImageResourceRecord::failed(
      "missing.png",
      diagnostic="decode failed",
    ),
  ]
  let renderer = @render.WindowRenderer::new(
    resize=metrics => resized.val = metrics.logical_size,
    render=commands => rendered.val = commands.length(),
    text_system=() => @core.TextSystem::fallback(),
    present_count=() => presenter.val,
    dispose=() => disposed.val = disposed.val + 1,
    image=@render.HostRendererImageCapability::new(
      image_resources=() => image_records,
      image_resource_snapshot=Some(() => {
        @render.ImageResourceSnapshot::new(revision=7, records=image_records)
      }),
      apply_image_resource_load_completion=Some(completion => {
        completion_sources.push(completion.source)
        @render.ImageResourceSnapshot::new(revision=11, records=[
          @render.ImageResourceRecord::ready(
            completion.source,
            width=completion.width,
            height=completion.height,
          ),
        ])
      }),
      set_image_resource_change_callback=callback => {
        callback_sets.val = callback_sets.val + 1
        match callback {
          Some(notify) =>
            notify(@render.ImageResourceSnapshot::new(revision=9, records=[]))
          None => ()
        }
      },
    ),
  )
  renderer.resize(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=96.0, height=48.0),
      scale_factor=2.0,
    ),
  )
  renderer.render([@core.DrawCommand::Clear(@core.Color::white())])
  inspect(resized.val.width, content="96")
  inspect(resized.val.height, content="48")
  inspect(rendered.val, content="1")
  inspect(renderer.text_system().id(), content="core-fallback-text-system")
  let resources = renderer.image_resources()
  inspect(resources.length(), content="2")
  assert_true(resources[0].status == @render.ImageResourceStatus::ImageReady)
  inspect(resources[0].width, content="32")
  assert_true(resources[1].status == @render.ImageResourceStatus::ImageFailed)
  assert_true(resources[1].diagnostic.contains("decode"))
  let image_snapshot = renderer.image_resource_snapshot()
  inspect(image_snapshot.revision, content="7")
  inspect(image_snapshot.records.length(), content="2")
  let completed = renderer.apply_image_resource_load_completion(
    @render.ImageResourceLoadCompletion::ready("async.png", width=44, height=22),
  )
  inspect(completed.revision, content="11")
  inspect(completion_sources.length(), content="1")
  inspect(completion_sources[0], content="async.png")
  assert_true(completed.records[0].source == "async.png")
  inspect(completed.records[0].width, content="44")
  renderer.set_image_resource_change_callback(
    Some(snapshot => callback_revisions.push(snapshot.revision)),
  )
  inspect(callback_sets.val, content="1")
  assert_true(callback_revisions == [9])
  renderer.set_image_resource_change_callback(None)
  inspect(callback_sets.val, content="2")
  inspect(renderer.present_count(), content="3")
  renderer.dispose()
  inspect(disposed.val, content="1")
}

///|
test "host window renderer image resource diagnostics default empty" {
  let renderer = @render.WindowRenderer::new(resize=_ => (), render=_ => (), text_system=() => {
    @core.TextSystem::fallback()
  })
  inspect(renderer.image_resources().length(), content="0")
  let image_snapshot = renderer.image_resource_snapshot()
  inspect(image_snapshot.revision, content="0")
  inspect(image_snapshot.records.length(), content="0")
  let completion_snapshot = renderer.apply_image_resource_load_completion(
    @render.ImageResourceLoadCompletion::failed(
      "missing.png",
      diagnostic="decode failed",
    ),
  )
  inspect(completion_snapshot.revision, content="0")
  inspect(completion_snapshot.records.length(), content="0")
  renderer.set_image_resource_change_callback(Some(_snapshot => ()))
  renderer.set_image_resource_change_callback(None)
}
