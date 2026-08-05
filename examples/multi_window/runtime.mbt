///|
pub fn runtime_and_host() -> (
  @runtime.AppRuntime,
  @runtime.WindowSceneResolver,
  @backend_common.WindowRequestQueue,
) {
  let queue = @backend_common.WindowRequestQueue::new()
  let windows = window_actions(queue)
  let resolver = @runtime.WindowSceneResolver::new(resolve=request => {
    match
      @multi_window_app.scene_from_window(
        @multi_window_app.WindowScene::new(
          scene_id=request.scene.scene_id,
          payload=request.scene.payload,
        ),
      ) {
      Some(scene) =>
        @runtime.WindowSceneResolution::SceneResolved(
          @runtime.WindowSceneInstance::new(
            request~,
            runtime=runtime_for(scene, windows, request.metrics.logical_size),
          ),
        )
      None =>
        @runtime.WindowSceneResolution::SceneRejected("unknown sample scene")
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
  queue : @backend_common.WindowRequestQueue,
) -> @multi_window_app.WindowActions {
  let host = @backend_common.WindowActions::new(queue~)
  @multi_window_app.WindowActions::new(
    dispatch=request => {
      match request {
        @multi_window_app.WindowRequest::Open(open) =>
          host.open(
            title=open.title,
            scene=@host.WindowScene::new(
              scene_id=open.scene.scene_id,
              payload=open.scene.payload,
            ),
            metrics=@core.SurfaceMetrics::from_logical(
              size=@geometry.Size::new(width=open.width, height=open.height),
            ),
          )
        @multi_window_app.WindowRequest::Focus(id) =>
          host.focus(@host.WindowId::new(id.value))
        @multi_window_app.WindowRequest::Close(id) =>
          host.close(@host.WindowId::new(id.value))
      }
    },
    subscribe=dispatch => {
      queue.subscribe_completed(completion => {
        match completion.result {
          @host.WindowRequestResult::WindowOpened(id) =>
            dispatch(
              @multi_window_app.WindowEvent::Opened(
                @multi_window_app.WindowId::new(id.value),
              ),
            )
          @host.WindowRequestResult::WindowUpdated(id) =>
            dispatch(
              @multi_window_app.WindowEvent::Updated(
                @multi_window_app.WindowId::new(id.value),
              ),
            )
          @host.WindowRequestResult::WindowRejected(message) =>
            dispatch(@multi_window_app.WindowEvent::Rejected(message))
        }
      })
    },
  )
}
