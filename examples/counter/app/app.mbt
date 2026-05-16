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
pub fn CounterApp::root(self : CounterApp) -> @core.ViewSpec {
  let theme = @core.Theme::light()
  @views.surface(
    @views.column(
      [
        @views.text("MoUI Counter")
        .font(theme.typography.title)
        .foreground(theme.palette.foreground),
        @views.text("Count: \{self.count.get()}")
        .font(theme.typography.body)
        .foreground(theme.palette.muted),
        @views.button(
          "Increment",
          on_click=() => self.increment(),
          style=@core.ButtonStyle::filled(theme~),
        ),
      ],
      spacing=theme.spacing_scale.md,
    ),
    style=@core.SurfaceStyle::default(theme~),
  )
}

///|
pub fn CounterApp::runtime(
  self : CounterApp,
  width? : Double = 800.0,
  height? : Double = 600.0,
) -> @core.AppRuntime {
  @core.AppRuntime::new_component(
    root=@core.Component::new(_ctx => self.root()),
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
