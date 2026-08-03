///|
fn app_builder_test_runtime() -> AppRuntime {
  let root : @core.View[Unit] = @views.text("builder test")
  AppRuntime::new_view(root~, size=@core.Size::new(width=320.0, height=240.0))
}

///|
fn app_builder_test_factory(id : String) -> @render.RendererBindingFactory {
  @render.RendererBindingFactory::new(id~, bind=_kit => abort("not bound"))
}

///|
test "AppBuilder passes ordered factories and window requests to backend" {
  let launched = Ref(false)
  let title = Ref("")
  let factory_ids : Array[String] = []
  let queue = @backend_host.HostWindowRequestQueue::new()
  queue.close_window(@backend_host.HostWindowId::new(42))
  let pending_requests = Ref(0)
  let entry = PlatformEntry::new(id="test", launch=request => {
    launched.val = true
    title.val = request.title()
    for factory in request.renderer_factories() {
      factory_ids.push(factory.id())
    }
    pending_requests.val = request.window_requests().pending_count()
  })
  run_app("Builder Test", app_builder_test_runtime())
  .render(app_builder_test_factory("first"))
  .render_all([
    app_builder_test_factory("second"),
    app_builder_test_factory("third"),
  ])
  .window_requests(queue)
  .backend(entry)
  .run()
  assert_true(launched.val)
  inspect(title.val, content="Builder Test")
  inspect(factory_ids.length(), content="3")
  inspect(factory_ids[0], content="first")
  inspect(factory_ids[1], content="second")
  inspect(factory_ids[2], content="third")
  inspect(pending_requests.val, content="1")
}
