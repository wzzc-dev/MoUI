///|
using @views {button, card, center, column, row, text}

///|
pub struct Model {
  count : Int
}

///|
pub(all) enum Msg {
  Increment
  Decrement
  Reset
}

///|
pub fn Model::new() -> Model {
  { count: 0 }
}

///|
pub fn update(model : Model, msg : Msg) -> Model {
  match msg {
    Increment => { count: model.count + 1 }
    Decrement => { count: model.count - 1 }
    Reset => { count: 0 }
  }
}

///|
pub fn view(model : Model) -> @core.View[Msg] {
  center(
    card(
      column([
        text("MoUI Counter").title(),
        text("Count: \{model.count}").title(),
        row([
          button("-", on_click=Decrement),
          button("Reset", on_click=Reset),
          button("+", on_click=Increment),
        ]),
      ]),
    ),
  )
}

///|
pub fn runtime(
  width? : Double = 520.0,
  height? : Double = 360.0,
) -> @runtime.AppRuntime {
  @runtime.AppRuntime::new_program(
    program=@core.Program::simple(init=Model::new(), update~, view~),
    size=@core.Size::new(width~, height~),
  )
}
