///|
// Moon only exports functions defined by the executable package. Keep this
// mechanical ABI shim free of platform or application logic.
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
  request_id : Int,
  ok : Bool,
  text_id : Int,
) -> Unit {
  @web.web_complete_async_clipboard_read(request_id, ok, text_id)
}

///|
pub fn web_complete_async_file_dialog(
  request_id : Int,
  ok : Bool,
  text_id : Int,
) -> Unit {
  @web.web_complete_async_file_dialog(request_id, ok, text_id)
}
