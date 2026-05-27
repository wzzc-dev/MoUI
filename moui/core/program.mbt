///|
pub(all) enum Effect[Msg] {
  NoEffect
  Batch(Array[Effect[Msg]])
  Send(Msg)
}

///|
pub(all) struct Program[Model, Msg] {
  init : () -> (Model, Effect[Msg])
  update : (Msg, Model) -> (Model, Effect[Msg])
  view : (Model) -> View[Msg]
}

///|
pub fn[Msg] Effect::none() -> Effect[Msg] {
  NoEffect
}

///|
pub fn[Msg] Effect::batch(effects : Array[Effect[Msg]]) -> Effect[Msg] {
  Batch(effects)
}

///|
pub fn[Msg] Effect::send(message : Msg) -> Effect[Msg] {
  Send(message)
}

///|
pub fn[Model, Msg] Program::new(
  init~ : () -> (Model, Effect[Msg]),
  update~ : (Msg, Model) -> (Model, Effect[Msg]),
  view~ : (Model) -> View[Msg],
) -> Program[Model, Msg] {
  { init, update, view }
}

///|
fn[Msg] run_effect(effect : Effect[Msg], dispatch : (Msg) -> Unit) -> Unit {
  match effect {
    NoEffect => ()
    Batch(effects) =>
      for effect in effects {
        run_effect(effect, dispatch)
      }
    Send(message) => dispatch(message)
  }
}
