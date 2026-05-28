///|
using @views {button, column, padding_edges, row, spacer, surface, text}

///|
pub struct CounterApp {
  count : @core.State[Int]
}

///|
priv enum CounterMsg {
  Decrement
  Increment
  Reset
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
pub fn CounterApp::decrement(self : CounterApp) -> Unit {
  self.count.update(value => value - 1)
}

///|
pub fn CounterApp::reset(self : CounterApp) -> Unit {
  self.count.set(0)
}

///|
fn CounterApp::update(self : CounterApp, message : CounterMsg) -> Unit {
  match message {
    Increment => self.increment()
    Decrement => self.decrement()
    Reset => self.reset()
  }
}

///|
fn CounterApp::root(
  self : CounterApp,
  ctx : @core.BuildContext,
) -> @core.View[CounterMsg] {
  let theme = @views.light_theme()
  let count = ctx.watch(self.count)
  let content = column(
    [
      text("MoUI Counter", width=320.0, height=42.0)
      .font(theme.typography.title)
      .foreground(theme.palette.foreground),
      text("Count: \{count}", width=320.0, height=64.0)
      .font(@core.FontSpec::new(size=34.0, weight=700))
      .foreground(theme.palette.primary),
      row(
        [
          button(
            "-",
            on_click=Decrement,
            variant=@views.ButtonVariant::Outline,
            theme~,
            width=72.0,
          ),
          button(
            "Reset",
            on_click=Reset,
            variant=@views.ButtonVariant::Tonal,
            theme~,
            width=108.0,
          ),
          button(
            "+",
            on_click=Increment,
            variant=@views.ButtonVariant::Primary,
            theme~,
            width=72.0,
          ),
        ],
        spacing=theme.spacing_scale.sm,
        align=@views.CrossAlign::Center,
      ),
    ],
    spacing=theme.spacing_scale.md,
    align=@views.CrossAlign::Center,
  )
  surface(
    padding_edges(content, top=32.0, right=32.0, bottom=32.0, left=32.0),
    width=420.0,
    height=260.0,
    variant=@views.SurfaceVariant::Raised,
    theme~,
  )
  |> center_in_window(ctx.viewport_size(), theme)
}

///|
fn center_in_window(
  child : @core.View[CounterMsg],
  viewport : @core.Size,
  theme : @core.Theme,
) -> @core.View[CounterMsg] {
  let horizontal = (viewport.width - 420.0) / 2.0
  let vertical = (viewport.height - 260.0) / 2.0
  surface(
    column(
      [
        spacer(min_length=max_double(0.0, vertical), weight=0.0),
        row(
          [spacer(min_length=max_double(0.0, horizontal), weight=0.0), child],
          spacing=0.0,
          align=@views.CrossAlign::Start,
        ),
      ],
      spacing=0.0,
      align=@views.CrossAlign::Start,
    ),
    width=viewport.width,
    height=viewport.height,
    variant=@views.SurfaceVariant::Base,
    theme~,
    background=@core.Color::rgba(r=0.96, g=0.97, b=0.98),
    padding=0.0,
  )
}

///|
fn max_double(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
pub fn CounterApp::runtime(
  self : CounterApp,
  width? : Double = 520.0,
  height? : Double = 360.0,
) -> @core.AppRuntime {
  @core.AppRuntime::new_component_view(
    root=ctx => self.root(ctx),
    size=@core.Size::new(width~, height~),
    on_message=Some(message => self.update(message)),
  )
}
