///|
fn main {
  let app = @markdown_app.MarkdownEditorApp::new()
  let runtime = app.runtime_with_services(
    @web.web_app_services(),
    width=980.0,
    height=640.0,
  )
  @web.run_app("MoUI Markdown Editor", runtime)
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

///|
pub fn web_complete_async_file_open_text(
  id : Int,
  ok : Bool,
  path_id : Int,
  text_id : Int,
) -> Unit {
  @web.web_complete_async_file_open_text(id, ok, path_id, text_id)
}

///|
pub fn web_complete_async_text_file_write(
  id : Int,
  ok : Bool,
  text_id : Int,
) -> Unit {
  @web.web_complete_async_text_file_write(id, ok, text_id)
}
