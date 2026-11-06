///|
using @views {button, card, center, column, row, text}

///|
pub struct Model {
  count : Int32
}

///|
pub(all) enum Msg {
  Increment
  Decrement
  Reset
}

///|
pub fn Model::new() -> Model {
  { count: 0, }
}

///|
pub fn update(model : Model, msg : Msg) -> Model {
  match msg {
    Increment => { count: model.count + 1, }
    Decrement => { count: model.count - 1, }
    Reset => { count: 0, }
  }
}

///|
pub fn view(model : Model) -> @moui.View[Msg] {
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
pub fn program() -> @moui.Program[Model, Msg] {
  @moui.Program::simple(init=Model::new(), update~, view~)
}

///|
/// Dev-loop entrypoint with state-preserving restarts: the model serializes
/// to JSON, and a `moui dev` restart restores the last count when the
/// composition root supplies a state transport.
pub fn program_with_dev_state() -> @moui.Program[Model, Msg] {
  program().with_state_persistence(
    save=model => Json::number(model.count.to_double()).stringify(),
    load=payload => {
      let parsed = @json.parse(payload) catch { _ => return None }
      match parsed {
        Json::Number(count, repr=_) => Some({ count: count.to_int(), })
        _ => None
      }
    },
  )
}
