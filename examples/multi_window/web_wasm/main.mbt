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
        @runtime.HostWindowSceneResolution::SceneRejected(
          "unknown sample scene",
        )
    }
  })
  @moui.run_app(
    "MoUI Multi-Window",
    runtime_for(
      @multi_window_app.Scene::Main,
      windows,
      @geometry.Size::new(width=640.0, height=420.0),
    ),
  )
  .render_all(@webgpu_adapter.from_env())
  .backend(@web.entry(options=@web.WebAppOptions::new(scene_resolver=resolver)))
  .window_requests(queue)
  .run()
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

///|
pub fn web_dispatch_event(
  kind : Int,
  raw_id : Int,
  arg0 : Int,
  arg1 : Int,
  argd : Double,
  text_id : Int,
) -> Unit {
  @web.web_dispatch_event(kind, raw_id, arg0, arg1, argd, text_id)
}

///|
pub fn web_dispatch_pointer_input(
  raw_id : Int,
  kind : Int,
  x_px : Double,
  y_px : Double,
  delta_x_px : Double,
  delta_y_px : Double,
  button : Int,
  modifiers : Int,
) -> Int {
  @web.web_dispatch_pointer_input(
    raw_id, kind, x_px, y_px, delta_x_px, delta_y_px, button, modifiers,
  )
}

///|
pub fn web_dispatch_route(source_code : Int, text_id : Int) -> Unit {
  @web.web_dispatch_route(source_code, text_id)
}

///|
pub fn web_dispatch_semantics_action(
  raw_id : Int,
  node_id_text_id : Int,
  generation_text_id : Int,
  action_code : Int,
  value_id : Int,
  direction_code : Int,
) -> Unit {
  @web.web_dispatch_semantics_action(
    raw_id, node_id_text_id, generation_text_id, action_code, value_id, direction_code,
  )
}

///|
pub fn web_complete_async_clipboard_read(
  id : Int,
  ok : Bool,
  text_id : Int,
) -> Unit {
  @web.web_complete_async_clipboard_read(id, ok, text_id)
}

///|
pub fn web_complete_async_file_dialog(
  id : Int,
  ok : Bool,
  text_id : Int,
) -> Unit {
  @web.web_complete_async_file_dialog(id, ok, text_id)
}
