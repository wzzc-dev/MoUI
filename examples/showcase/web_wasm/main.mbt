///|
fn main {
  let app = @showcase_app.ShowcaseApp::new()
  let runtime = app.runtime()
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
