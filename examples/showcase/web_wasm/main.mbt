///|
fn showcase_initial_section_code() -> Int = "showcase" "initial_section"

///|
fn main {
  let route_source = @host.HostRouteSource::new()
  let route_host = @showcase_app.ShowcaseRouteHost::new(
    route_source~,
    dispatch_command=dispatch_showcase_route_command,
  )
  let model = match showcase_initial_section_code() {
    1 =>
      @showcase_app.ShowcaseModel::new()
      .with_host_summary(@web.web_capability_summary())
      .update(@showcase_app.ShowcaseMsg::SelectSection("advanced-rendering"))
    _ =>
      @showcase_app.ShowcaseModel::new().with_host_summary(
        @web.web_capability_summary(),
      )
  }
  let runtime = @runtime.new_program_with_dimensions(
    program=model.program_with_route_host(route_host),
    width=960.0,
    height=560.0,
  )
  @web.run_app_with_options(
    "MoUI Showcase Wasm Host",
    runtime,
    options=@web.WebAppOptions::new(route_source=Some(route_source)),
  )
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
pub fn web_dispatch_route(source_code : Int, text_id : Int) -> Unit {
  @web.web_dispatch_route(source_code, text_id)
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
