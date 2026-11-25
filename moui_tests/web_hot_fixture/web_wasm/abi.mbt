///|
// Moon only exports functions defined by the executable package. Keep this
// mechanical ABI shim free of platform or application logic.
pub fn web_dispatch_event(
  kind : Int32,
  raw_id : Int32,
  arg0 : Int32,
  arg1 : Int32,
  argd : Double,
  text_id : Int32,
) -> Unit {
  @web.web_dispatch_event(kind, raw_id, arg0, arg1, argd, text_id)
}

///|
pub fn web_dispatch_pointer_input(
  raw_id : Int32,
  kind : Int32,
  x_px : Double,
  y_px : Double,
  delta_x_px : Double,
  delta_y_px : Double,
  button : Int32,
  modifiers : Int32,
  pointer_id : Int32,
  pressure : Double,
) -> Int32 {
  @web.web_dispatch_pointer_input(
    raw_id, kind, x_px, y_px, delta_x_px, delta_y_px, button, modifiers, pointer_id,
    pressure,
  )
}

///|
pub fn web_dispatch_route(source_code : Int32, text_id : Int32) -> Unit {
  @web.web_dispatch_route(source_code, text_id)
}

///|
pub fn web_dispatch_semantics_action(
  raw_id : Int32,
  node_id_text_id : Int32,
  generation_text_id : Int32,
  action_code : Int32,
  value_id : Int32,
  direction_code : Int32,
) -> Unit {
  @web.web_dispatch_semantics_action(
    raw_id, node_id_text_id, generation_text_id, action_code, value_id, direction_code,
  )
}

///|
pub fn web_complete_async_clipboard_read(
  request_id : Int32,
  ok : Bool,
  text_id : Int32,
) -> Unit {
  @web.web_complete_async_clipboard_read(request_id, ok, text_id)
}

///|
pub fn web_complete_async_file_dialog(
  request_id : Int32,
  ok : Bool,
  text_id : Int32,
) -> Unit {
  @web.web_complete_async_file_dialog(request_id, ok, text_id)
}
