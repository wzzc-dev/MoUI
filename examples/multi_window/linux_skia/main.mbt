///|
fn main {
  let queue = @host.HostWindowRequestQueue::new()
  let windows = @host.HostWindowActions::new(queue~)
  let resolver = @host.HostWindowSceneResolver::new(resolve=request => {
    match @multi_window_app.scene_from_host(request.scene) {
      Some(scene) =>
        @host.HostWindowSceneResolution::SceneResolved(
          @host.HostWindowSceneInstance::new(
            request~,
            runtime=runtime_for(scene, windows, request.metrics.logical_size),
          ),
        )
      None => @host.HostWindowSceneResolution::SceneRejected("unknown sample scene")
    }
  })
  @linux_skia_backend.run_app_with_options(
    "MoUI Multi-Window",
    runtime_for(
      @multi_window_app.Scene::Main,
      windows,
      @geometry.Size::new(width=640.0, height=420.0),
    ),
    options=@linux_skia_backend.LinuxSkiaAppOptions::new(scene_resolver=resolver),
    window_requests=queue,
  )
}

///|
fn runtime_for(
  scene : @multi_window_app.Scene,
  windows : @host.HostWindowActions,
  size : @core.Size,
) -> @runtime.AppRuntime {
  @runtime.new_program_with_dimensions(
    program=@multi_window_app.program(scene, windows),
    width=size.width,
    height=size.height,
  )
}
