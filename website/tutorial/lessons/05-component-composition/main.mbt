///|
pub struct Model {
  name : String
}

///|
fn user_card(model : Model) -> @moui.View[Unit] {
  @views.container(
    @views.column([@views.text(model.name), @views.text("Reusable component")]),
    padding=12.0,
  )
}

///|
fn view(model : Model) -> @moui.View[Unit] {
  @views.column(
    [user_card(model), user_card({ name: "Another card" })],
    spacing=8.0,
  )
}

///|
pub fn program() -> @moui.Program[Model, Unit] {
  @moui.Program::simple(
    init={ name: "Component card" },
    update=(model, _) => model,
    view~,
  )
}
