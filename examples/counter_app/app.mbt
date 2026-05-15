///|
pub struct CounterApp {
  count : @core.State[Int]
}

///|
pub fn CounterApp::new() -> CounterApp {
  { count: @core.State::new(0) }
}

///|
pub fn CounterApp::increment(self : CounterApp) -> Unit {
  self.count.update(value => value + 1)
}

///|
pub fn CounterApp::root(self : CounterApp) -> @core.ViewNode {
  @views.column(
    [
      @views.label("MoUI Counter"),
      @views.label("Count: \{self.count.get()}"),
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
) -> @core.AppRuntime {
  @core.AppRuntime::new_dynamic(
    root=() => self.root(),
    size=@core.Size::new(width~, height~),
  )
}

///|
pub fn CounterApp::sync_runtime(
  self : CounterApp,
  runtime : @core.AppRuntime,
) -> Unit {
  ignore(self)
  ignore(runtime)
}
