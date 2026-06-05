///|
fn showcase_initial_section_code() -> Int = "showcase" "initial_section"

///|
fn main {
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
  let runtime = model.runtime()
  @web.run_app("MoUI Showcase Wasm Host", runtime)
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
