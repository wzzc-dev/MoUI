///|
fn main {
  let queue = @host.HostWindowRequestQueue::new()
  let windows = @host.HostWindowActions::new(queue~)
  let resolver = @runtime.HostWindowSceneResolver::new(resolve=request => {
    match @multi_window_app.scene_from_host(request.scene) {
      Some(scene) =>
        @runtime.HostWindowSceneResolution::SceneResolved(
          @runtime.HostWindowSceneInstance::new(
            request~,
            runtime=runtime_for(scene, windows, request.metrics.logical_size),
          ),
        )
      None =>
        @runtime.HostWindowSceneResolution::SceneRejected("unknown sample scene")
    }
  })
  @windows_skia_backend.run_app_with_options(
    "MoUI Multi-Window",
    runtime_for(
      @multi_window_app.Scene::Main,
      windows,
      @geometry.Size::new(width=640.0, height=420.0),
    ),
    options=@windows_skia_backend.WindowsSkiaAppOptions::new(
      scene_resolver=resolver,
    ),
    window_requests=queue,
  )
}

///|
fn runtime_for(
  scene : @multi_window_app.Scene,
  windows : @host.HostWindowActions,
  size : @geometry.Size,
) -> @runtime.AppRuntime {
  @runtime.new_program_with_dimensions(
    program=@multi_window_app.program(scene, windows),
    width=size.width,
    height=size.height,
  )
}
