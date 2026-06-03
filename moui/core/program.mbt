///|
pub(all) enum Effect[Msg] {
  NoEffect
  Batch(Array[Effect[Msg]])
  Send(Msg)
  Dispatch(((Msg) -> Unit) -> Unit)
}

///|
pub(all) struct Program[Model, Msg] {
  init : () -> (Model, Effect[Msg])
  update : (Model, Msg) -> (Model, Effect[Msg])
  view : (Model, ViewEnvironment) -> View[Msg]
  subscriptions : (Model) -> Subscription[Msg]
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
pub fn[Msg] Effect::dispatch(run : ((Msg) -> Unit) -> Unit) -> Effect[Msg] {
  Dispatch(run)
}

///|
pub fn[Msg, NextMsg] Effect::map(
  self : Effect[Msg],
  map : (Msg) -> NextMsg,
) -> Effect[NextMsg] {
  match self {
    NoEffect => NoEffect
    Batch(effects) => Batch(effects.map(effect => effect.map(map)))
    Send(message) => Send(map(message))
    Dispatch(run) =>
      Dispatch(dispatch => run(message => dispatch(map(message))))
  }
}

///|
pub fn[Model, Msg] Program::new(
  init~ : () -> (Model, Effect[Msg]),
  update~ : (Model, Msg) -> (Model, Effect[Msg]),
  view~ : (Model) -> View[Msg],
  subscriptions? : (Model) -> Subscription[Msg] = _model => Subscription::none(),
) -> Program[Model, Msg] {
  { init, update, view: (model, _env) => view(model), subscriptions }
}

///|
pub fn[Model, Msg] Program::new_with_environment(
  init~ : () -> (Model, Effect[Msg]),
  update~ : (Model, Msg) -> (Model, Effect[Msg]),
  view~ : (Model, ViewEnvironment) -> View[Msg],
  subscriptions? : (Model) -> Subscription[Msg] = _model => Subscription::none(),
) -> Program[Model, Msg] {
  { init, update, view, subscriptions }
}

///|
pub fn[Model, Msg] Program::simple(
  init~ : Model,
  update~ : (Model, Msg) -> Model,
  view~ : (Model) -> View[Msg],
  subscriptions? : (Model) -> Subscription[Msg] = _model => Subscription::none(),
) -> Program[Model, Msg] {
  Program::new(
    init=() => (init, Effect::none()),
    update=(model, message) => (update(model, message), Effect::none()),
    view~,
    subscriptions~,
  )
}

///|
pub fn[Model, Msg] Program::simple_with_environment(
  init~ : Model,
  update~ : (Model, Msg) -> Model,
  view~ : (Model, ViewEnvironment) -> View[Msg],
  subscriptions? : (Model) -> Subscription[Msg] = _model => Subscription::none(),
) -> Program[Model, Msg] {
  Program::new_with_environment(
    init=() => (init, Effect::none()),
    update=(model, message) => (update(model, message), Effect::none()),
    view~,
    subscriptions~,
  )
}

///|
fn[Msg] run_effect(effect : Effect[Msg], dispatch : (Msg) -> Unit) -> Int {
  match effect {
    NoEffect => 0
    Batch(effects) => {
      let mut count = 0
      for effect in effects {
        count = count + run_effect(effect, dispatch)
      }
      count
    }
    Send(message) => {
      dispatch(message)
      1
    }
    Dispatch(run) => {
      run(dispatch)
      1
    }
  }
}
