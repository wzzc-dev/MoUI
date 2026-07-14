///|
pub struct Model {
  ready : Bool
}

///|
fn view(model : Model) -> @moui.View[Unit] {
  @views.column([
    @views.text(
      if model.ready {
        "Ready to publish"
      } else {
        "Inspect the diagnostics"
      },
    ),
    @views.text("Run the same source in Playground before publishing."),
  ])
}

///|
pub fn program() -> @moui.Program[Model, Unit] {
  @moui.Program::simple(init={ ready: true }, update=(model, _) => model, view~)
}
