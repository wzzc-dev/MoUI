///|
fn main {
  @web_backend.run_app(
    "Component Gallery",
    @runtime.new_program_with_dimensions(
      program=@component_gallery_app.program(
        active_platform=@component_gallery_app.PlatformId::Web,
      ),
      width=1040.0,
      height=720.0,
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
  @web_backend.web_dispatch_event(kind, raw_id, arg0, arg1, argd, text_id)
}

///|
pub fn web_dispatch_route(source_code : Int, text_id : Int) -> Unit {
  @web_backend.web_dispatch_route(source_code, text_id)
}

///|
pub fn web_complete_async_clipboard_read(
  id : Int,
  ok : Bool,
  text_id : Int,
) -> Unit {
  @web_backend.web_complete_async_clipboard_read(id, ok, text_id)
}

///|
pub fn web_complete_async_file_dialog(
  id : Int,
  ok : Bool,
  text_id : Int,
) -> Unit {
  @web_backend.web_complete_async_file_dialog(id, ok, text_id)
}
