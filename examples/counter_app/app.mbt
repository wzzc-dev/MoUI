///|
pub struct CounterApp {
  mut count : Int
}

///|
pub fn CounterApp::new() -> CounterApp {
  { count: 0 }
}

///|
pub fn CounterApp::increment(self : CounterApp) -> Unit {
  self.count = self.count + 1
}

///|
pub fn CounterApp::root(self : CounterApp) -> @core.ViewNode {
  @views.column(
    [
      @views.label("MoUI Counter"),
      @views.label("Count: \{self.count}"),
      @views.button_on_click("Increment", () => self.increment()),
    ],
    spacing=12.0,
  )
}

///|
pub fn CounterApp::runtime(
  self : CounterApp,
  width? : Double = 800.0,
  height? : Double = 600.0,
) -> @backend.AppRuntime {
  @backend.AppRuntime::new(
    root=self.root(),
    size=@core.Size::new(width~, height~),
  )
}

///|
pub fn CounterApp::sync_runtime(
  self : CounterApp,
  runtime : @backend.AppRuntime,
) -> Unit {
  if runtime.needs_rebuild() {
    runtime.set_root(self.root())
  }
}
