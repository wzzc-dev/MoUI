///|
pub struct Model {
  title : String
}

///|
fn view(model : Model) -> @moui.View[Unit] {
  @views.column([@views.text(model.title), @views.text("A first MoUI program")])
}

///|
pub fn program() -> @moui.Program[Model, Unit] {
  @moui.Program::simple(
    init={ title: "Hello, MoUI!" },
    update=(model, _message) => model,
    view~,
  )
}
