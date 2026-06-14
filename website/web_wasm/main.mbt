///|
fn main {
  @web.run_app(
    "MoUI Website",
    @runtime.new_program_with_dimensions(
      program=@website_app.program_with_services(@web.web_app_services()),
      width=1180.0,
      height=760.0,
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
