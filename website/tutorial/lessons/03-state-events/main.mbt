///|
pub enum Msg {
  Increment
}

///|
pub struct Model {
  count : Int
}

///|
fn view(model : Model) -> @moui.View[Msg] {
  @views.column([
    @views.text("Count: \{model.count}"),
    @views.button("Increment", on_click=Increment),
  ])
}

///|
fn update(model : Model, message : Msg) -> Model {
  match message {
    Increment => { count: model.count + 1 }
  }
}

///|
pub fn program() -> @moui.Program[Model, Msg] {
  @moui.Program::simple(init={ count: 0 }, update~, view~)
}
