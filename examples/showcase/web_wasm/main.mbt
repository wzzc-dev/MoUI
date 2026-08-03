///|
fn showcase_initial_section_code() -> Int = "showcase" "initial_section"

///|
fn main {
  let route_source = @runtime.HostRouteSource::new()
  let route_host = @showcase_app.ShowcaseRouteHost::new(
    route_source~,
    dispatch_command=dispatch_showcase_route_command,
  )
  let renderer_providers = @render.renderer_provider_binding_providers(
    @webgpu_adapter.provider_bindings(canvas_id="moonbit-window-web-showcase"),
  )
  let model = match showcase_initial_section_code() {
    1 =>
      @showcase_app.ShowcaseModel::new()
      .with_host_summary(@web.web_capability_summary())
      .with_renderer_providers(renderer_providers)
      .update(
        @showcase_app.ShowcaseMsg::Navigate("diagnostics/advanced-rendering"),
      )
    _ =>
      @showcase_app.ShowcaseModel::new()
      .with_host_summary(@web.web_capability_summary())
      .with_renderer_providers(renderer_providers)
  }
  let runtime = @runtime.new_program_with_dimensions(
    program=model.program_with_route_host(route_host),
    width=1100.0,
    height=680.0,
  )
  @moui.run_app("MoUI Showcase Wasm Host", runtime)
  .render_all(@webgpu_adapter.from_env())
  .backend(
    @web.entry(options=@web.WebAppOptions::new(route_source=Some(route_source))),
  )
  .run()
}

///|
fn dispatch_showcase_route_command(
  command : @showcase_app.ShowcaseRouteHistoryCommand,
) -> Unit {
  match command {
    @showcase_app.ShowcaseRouteHistoryCommand::PushRoute(route) =>
      @web.web_history_push_route(route)
    @showcase_app.ShowcaseRouteHistoryCommand::ReplaceRoute(route) =>
      @web.web_history_replace_route(route)
    @showcase_app.ShowcaseRouteHistoryCommand::BackRoute =>
      @web.web_history_back()
    @showcase_app.ShowcaseRouteHistoryCommand::ForwardRoute =>
      @web.web_history_forward()
  }
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
