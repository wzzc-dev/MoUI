///|
// A minimal counter program demonstrating the agent-controllable runtime.
// An agent reads committed semantics and performs typed semantic actions that
// emit the same messages consumed by TEA update.

using @views {column, text, button}

///|
using @moui {type Program}

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
    button("Increment", on_click=Increment).semantic_id(
      @moui.SemanticId::parse("counter.increment").unwrap(),
    ),
    button("Decrement", on_click=Decrement).semantic_id(
      @moui.SemanticId::parse("counter.decrement").unwrap(),
    ),
    button("Reset", on_click=Reset).semantic_id(
      @moui.SemanticId::parse("counter.reset").unwrap(),
    ),
  ])
}

///|
pub fn program() -> Program[Model, Msg] {
  Program::simple(init=Model::new(), update~, view~)
}
