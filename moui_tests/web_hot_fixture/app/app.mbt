///|
using @views {button, card, center, column, scroll_view, text}

///|
pub struct Model {
  count : Int32
}

///|
pub(all) enum Msg {
  Increment
}

///|
pub fn Model::new() -> Model {
  { count: 0, }
}

///|
pub fn update(model : Model, msg : Msg) -> Model {
  match msg {
    Increment => { count: model.count + 1, }
  }
}

///|
fn rows() -> Array[@moui.View[Msg]] {
  let rows : Array[@moui.View[Msg]] = []
  for index in 0..<40 {
    rows.push(text("Row \{index}"))
  }
  rows
}

///|
pub fn view(model : Model) -> @moui.View[Msg] {
  center(
    card(
      column([
        text("Web Hot Reload Fixture").title(),
        text("Count: \{model.count}").title(),
        button("+", on_click=Increment),
        scroll_view(column(rows()), width=300.0, height=120.0),
      ]),
    ),
  )
}

///|
pub fn program() -> @moui.Program[Model, Msg] {
  @moui.Program::simple(init=Model::new(), update~, view~)
}

///|
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
