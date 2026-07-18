///|
fn main {
  @web.run_app(
    "MoUI Design Systems",
    @runtime.new_program_with_dimensions(
      program=@design_systems_app.program(),
      width=960.0,
      height=680.0,
    ),
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
pub fn web_dispatch_pointer_input(raw_id : Int, kind : Int, x_px : Double, y_px : Double, delta_x_px : Double, delta_y_px : Double, button : Int, buttons : Int, pointer_id : Int, pointer_kind : Int, modifiers : Int) -> Int {
  @web.web_dispatch_pointer_input(raw_id, kind, x_px, y_px, delta_x_px, delta_y_px, button, buttons, pointer_id, pointer_kind, modifiers)
}

///|
pub fn web_dispatch_route(source_code : Int, text_id : Int) -> Unit {
  @web.web_dispatch_route(source_code, text_id)
}

///|
pub fn web_dispatch_semantics_action(
  raw_id : Int,
  element_id : Int,
  action_code : Int,
  value_id : Int,
) -> Unit {
  @web.web_dispatch_semantics_action(raw_id, element_id, action_code, value_id)
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
