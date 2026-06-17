///|
// A minimal counter program demonstrating the agent-controllable runtime.
// An agent reads its semantics tree, observes events, and fires command
// intents that flow through update() — exactly like a user clicking.

using @views {column, text, button}
using @moui { type Program}
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
pub fn view(model : Model) -> @moui.View[Msg] {
  column([
    text("Agent Counter"),
    text("Count: \{model.count}"),
    button("Increment", on_click=Increment),
    button("Decrement", on_click=Decrement),
    button("Reset", on_click=Reset),
  ])
}

///|
pub fn program() -> Program[Model, Msg] {
  Program::simple(init=Model::new(), update~, view~)
}
