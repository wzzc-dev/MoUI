///|
fn app_builder_test_runtime() -> AppRuntime {
  let root : @core.View[Unit] = @views.text("builder test")
  AppRuntime::new_view(root~, size=@core.Size::new(width=320.0, height=240.0))
}

///|
fn app_builder_test_provider(id : String) -> @render.RendererProvider {
  @render.RendererProvider::new(
    id~,
    descriptor=@render.RendererDescriptor::new(
      backend=@render.RendererBackendKind::SkiaRasterNative,
      family=@render.RendererFamily::Skia,
      presentation=@render.RendererPresentationModel::CpuPixelFrame,
      supported_targets=[@render.RendererTarget::Native],
      capabilities=[],
      description="app builder test provider",
    ),
    capabilities=() => [],
    bind=_surface => @render.RendererBindResult::Rejected("not bound"),
  )
}

///|
test "AppBuilder passes ordered providers and window requests to backend" {
  let launched = Ref(false)
  let title = Ref("")
  let provider_ids : Array[String] = []
  let requests = @backend_host.WindowRequests::new(pending_count=() => 1)
  let pending_requests = Ref(0)
  let entry = PlatformEntry::new(id="test", launch=request => {
    launched.val = true
    title.val = request.title()
    for provider in request.renderer_providers() {
      provider_ids.push(provider.id())
    }
    pending_requests.val = request.window_requests().pending_count()
  })
  run_app("Builder Test", app_builder_test_runtime())
  .render(app_builder_test_provider("first"))
  .render_all([
    app_builder_test_provider("second"),
    app_builder_test_provider("third"),
  ])
  .window_requests(requests)
  .backend(entry)
  .run()
  assert_true(launched.val)
  inspect(title.val, content="Builder Test")
  inspect(provider_ids.length(), content="3")
  inspect(provider_ids[0], content="first")
  inspect(provider_ids[1], content="second")
  inspect(provider_ids[2], content="third")
  inspect(pending_requests.val, content="1")
}
