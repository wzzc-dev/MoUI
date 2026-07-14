///|
pub struct Model {
  items : Array[String]
}

///|
fn view(model : Model) -> @moui.View[Unit] {
  @views.row(model.items.map(item => @views.text(item)), spacing=12.0)
}

///|
pub fn program() -> @moui.Program[Model, Unit] {
  @moui.Program::simple(
    init={ items: ["Sidebar", "Content", "Inspector"] },
    update=(model, _message) => model,
    view~,
  )
}
