///|
fn main {
  let route_source = @host.HostRouteSource::new()
  let runtime_ref : Ref[@runtime.AppRuntime?] = Ref(None)
  let route_host = @website_app.WebsiteRouteHost::new(
    route_source~,
    push_route=route => @web.web_history_push_route(route),
    scroll_to_key=(key, alignment) => {
      match runtime_ref.val {
        Some(runtime) => ignore(runtime.scroll_to_key(key, alignment~))
        None => ()
      }
    },
    apply_locale=locale => {
      match runtime_ref.val {
        Some(runtime) =>
          runtime.set_environment(runtime.environment().with_locale(locale))
        None => ()
      }
    },
    update_metadata=(title, description, canonical, locale, direction) => {
      @web.web_update_document_metadata(
        @web.WebDocumentMetadata::new(
          title~,
          description~,
          canonical~,
          locale~,
          direction~,
        ),
      )
    },
  )
  let runtime = @runtime.new_program_with_dimensions(
    program=@website_app.program_with_services(
      @web.web_app_services(),
      route_host=Some(route_host),
    ),
    width=1180.0,
    height=760.0,
  )
  runtime_ref.val = Some(runtime)
  @web.run_app_with_options(
    "MoUI - MoonBit GUI Framework",
    runtime,
    options=@web.WebAppOptions::new(route_source=Some(route_source)),
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

///|
pub fn web_complete_async_text_file_read(
  id : Int,
  ok : Bool,
  text_id : Int,
) -> Unit {
  @web.web_complete_async_text_file_read(id, ok, text_id)
}
