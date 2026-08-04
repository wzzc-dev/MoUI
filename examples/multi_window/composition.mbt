///|
pub fn runtime_and_host() -> (
  @runtime.AppRuntime,
  @runtime.HostWindowSceneResolver,
  @host.HostWindowRequestQueue,
) {
  let queue = @host.HostWindowRequestQueue::new()
  let windows = window_actions(queue)
  let resolver = @runtime.HostWindowSceneResolver::new(resolve=request => {
    match
      @multi_window_app.scene_from_window(
        @multi_window_app.WindowScene::new(
          scene_id=request.scene.scene_id,
          payload=request.scene.payload,
        ),
      ) {
      Some(scene) =>
        @runtime.HostWindowSceneResolution::SceneResolved(
          @runtime.HostWindowSceneInstance::new(
            request~,
            runtime=runtime_for(scene, windows, request.metrics.logical_size),
          ),
        )
      None =>
        @runtime.HostWindowSceneResolution::SceneRejected(
          "unknown sample scene",
        )
    }
  })
  (
    runtime_for(
      @multi_window_app.Scene::Main,
      windows,
      @geometry.Size::new(width=640.0, height=420.0),
    ),
    resolver,
    queue,
  )
}

///|
fn runtime_for(
  scene : @multi_window_app.Scene,
  windows : @multi_window_app.WindowActions,
  size : @geometry.Size,
) -> @runtime.AppRuntime {
  @runtime.new_program_with_dimensions(
    program=@multi_window_app.program(scene, windows),
    width=size.width,
    height=size.height,
  )
}

///|
fn window_actions(
  queue : @host.HostWindowRequestQueue,
) -> @multi_window_app.WindowActions {
  let host = @host.HostWindowActions::new(queue~)
  @multi_window_app.WindowActions::new(
    dispatch=request => {
      match request {
        @multi_window_app.WindowRequest::Open(open) =>
          host.open(
            title=open.title,
            scene=@host.HostWindowScene::new(
              scene_id=open.scene.scene_id,
              payload=open.scene.payload,
            ),
            metrics=@host.HostSurfaceMetrics::from_logical(
              size=@geometry.Size::new(width=open.width, height=open.height),
            ),
          )
        @multi_window_app.WindowRequest::Focus(id) =>
          host.focus(@host.HostWindowId::new(id.value))
        @multi_window_app.WindowRequest::Close(id) =>
          host.close(@host.HostWindowId::new(id.value))
      }
    },
    subscribe=dispatch => {
      queue.subscribe_completed(completion => {
        match completion.result {
          @host.HostWindowRequestResult::WindowOpened(id) =>
            dispatch(
              @multi_window_app.WindowEvent::Opened(
                @multi_window_app.WindowId::new(id.value),
              ),
            )
          @host.HostWindowRequestResult::WindowUpdated(id) =>
            dispatch(
              @multi_window_app.WindowEvent::Updated(
                @multi_window_app.WindowId::new(id.value),
              ),
            )
          @host.HostWindowRequestResult::WindowRejected(message) =>
            dispatch(@multi_window_app.WindowEvent::Rejected(message))
        }
      })
    },
  )
}
