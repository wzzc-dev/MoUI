///|
pub fn start_counter_web(context : @web.WebBootContext) -> @web.WebApp {
  let app_state = @counter_app.CounterApp::new()
  let runtime = app_state.runtime(
    width=context.width(),
    height=context.height(),
  )
  let app = @web.WebApp::new(runtime~, renderer=context.renderer(), rebuild=runtime => {
    app_state.sync_runtime(runtime)
  })
  app.attach_dom_events(context)
  app.start()
  app
}

///|
pub fn start_todo_web(context : @web.WebBootContext) -> @web.WebApp {
  let app_state = @todo_app.TodoApp::new()
  app_state.add("Try MoUI")
  let runtime = app_state.runtime(
    width=context.width(),
    height=context.height(),
  )
  let app = @web.WebApp::new(runtime~, renderer=context.renderer(), rebuild=runtime => {
    ignore(runtime)
  })
  app.attach_dom_events(context)
  app.start()
  app
}

///|
extern "js" fn has_boot_context() -> Bool =
  #|() => globalThis.__mouiBootContext !== undefined

///|
extern "js" fn boot_context() -> @web.WebBootContext =
  #|() => globalThis.__mouiBootContext

///|
fn main {
  if has_boot_context() && !has_started() {
    mark_started()
    ignore(start_counter_web(boot_context()))
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
