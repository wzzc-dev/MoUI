///|
pub fn start_counter_web(
  context : @winit_web.WinitWebBootContext,
) -> @winit_web.WinitWebApp {
  let app_state = @counter_app.CounterApp::new()
  let runtime = app_state.runtime(
    width=@winit_web.width(context),
    height=@winit_web.height(context),
  )
  let app = @winit_web.new_app(
    runtime~,
    renderer=@winit_web.renderer(context),
  )
  @winit_web.attach_dom_events(app, context)
  @winit_web.start(app)
  app
}

///|
pub fn start_todo_web(
  context : @winit_web.WinitWebBootContext,
) -> @winit_web.WinitWebApp {
  let app_state = @todo_app.TodoApp::new()
  app_state.add("Try MoUI")
  let runtime = app_state.runtime(
    width=@winit_web.width(context),
    height=@winit_web.height(context),
  )
  let app = @winit_web.new_app(
    runtime~,
    renderer=@winit_web.renderer(context),
  )
  @winit_web.attach_dom_events(app, context)
  @winit_web.start(app)
  app
}

///|
extern "js" fn has_boot_context() -> Bool =
  #|() => globalThis.__mouiBootContext !== undefined

///|
extern "js" fn boot_context() -> @winit_web.WinitWebBootContext =
  #|() => globalThis.__mouiBootContext

///|
fn main {
  if has_boot_context() && !has_started() {
    mark_started()
    if web_app_name() == "todo" {
      ignore(start_todo_web(boot_context()))
    } else {
      ignore(start_counter_web(boot_context()))
    }
  }
}

///|
extern "js" fn has_started() -> Bool =
  #|() => globalThis.__mouiStarted === true

///|
extern "js" fn mark_started() -> Unit =
  #|() => {
  #|  globalThis.__mouiStarted = true;
  #|}

///|
extern "js" fn web_app_name() -> String =
  #|() => new URLSearchParams(globalThis.location?.search ?? "").get("app") ?? "counter"
