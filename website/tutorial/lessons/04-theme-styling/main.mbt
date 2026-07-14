///|
pub struct Model {
  dark : Bool
}

///|
fn view(model : Model) -> @moui.View[Unit] {
  let theme = if model.dark {
    @views.dark_theme()
  } else {
    @views.light_theme()
  }
  @views.container(
    @views.text("Theme-aware surface", theme~),
    theme~,
    padding=16.0,
  )
}

///|
pub fn program() -> @moui.Program[Model, Unit] {
  @moui.Program::simple(init={ dark: false }, update=(model, _) => model, view~)
}
