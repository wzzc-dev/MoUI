///|
struct EffectDescriptor {
  key : String
  kind : String
  label : String
} derive(Eq, Debug, ToJson)

///|
pub fn EffectDescriptor::key(self : EffectDescriptor) -> String {
  self.key
}

///|
pub fn EffectDescriptor::kind(self : EffectDescriptor) -> String {
  self.kind
}

///|
pub fn EffectDescriptor::label(self : EffectDescriptor) -> String {
  self.label
}

///|
pub(all) enum Effect[Msg] {
  NoEffect
  Batch(Array[Effect[Msg]])
  Send(Msg)
  Dispatch(((Msg) -> Unit) -> Unit)
  Run(EffectDescriptor, ((Msg) -> Unit) -> Unit)
  Task(EffectDescriptor, ((Msg) -> Unit) -> (() -> Unit)?)
}

///|
/// A host-visible command declaration whose action re-enters the Program as a
/// typed message. The runtime owns dispatch; applications only describe the
/// command and its message.
pub struct ProgramCommand[Msg] {
  command : ActionCommand
  message : Msg
}

///|
struct Program[Model, Msg] {
  init : () -> (Model, Effect[Msg])
  update : (Model, Msg) -> (Model, Effect[Msg])
  view : (Model, ViewEnvironment) -> View[Msg]
  subscriptions : (Model) -> Subscription[Msg]
  commands : (Model) -> Array[ProgramCommand[Msg]]
}

///|
pub fn[Msg] ProgramCommand::new(
  command~ : ActionCommand,
  message~ : Msg,
) -> ProgramCommand[Msg] {
  { command, message }
}

///|
pub fn[Msg] ProgramCommand::command(
  self : ProgramCommand[Msg],
) -> ActionCommand {
  self.command
}

///|
pub fn[Msg] ProgramCommand::message(self : ProgramCommand[Msg]) -> Msg {
  self.message
}

///|
pub fn[Msg, NextMsg] ProgramCommand::map(
  self : ProgramCommand[Msg],
  map : (Msg) -> NextMsg,
) -> ProgramCommand[NextMsg] {
  ProgramCommand::new(command=self.command, message=map(self.message))
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
pub fn[Msg] Effect::run(
  key~ : String,
  run~ : ((Msg) -> Unit) -> Unit,
  kind? : String = "custom",
  label? : String = "",
) -> Effect[Msg] {
  Run({ key, kind, label }, run)
}

///|
pub fn[Msg] Effect::task(
  key~ : String,
  start~ : ((Msg) -> Unit) -> (() -> Unit)?,
  kind? : String = "task",
  label? : String = "",
) -> Effect[Msg] {
  Task({ key, kind, label }, start)
}

///|
pub fn[Msg] Effect::service_task(
  key~ : String,
  start~ : ((Msg) -> Unit) -> (() -> Unit)?,
  label? : String = "",
) -> Effect[Msg] {
  Effect::task(key~, start~, kind="service", label~)
}

///|
pub fn[Msg] Effect::runtime_visit(
  self : Effect[Msg],
  send : (Msg) -> Unit,
  dispatch_effect : (((Msg) -> Unit) -> Unit) -> Unit,
  run_effect : (EffectDescriptor, ((Msg) -> Unit) -> Unit) -> Unit,
  start_task : (EffectDescriptor, ((Msg) -> Unit) -> (() -> Unit)?) -> Unit,
) -> Unit {
  match self {
    NoEffect => ()
    Batch(effects) =>
      for effect in effects {
        effect.runtime_visit(send, dispatch_effect, run_effect, start_task)
      }
    Send(message) => send(message)
    Dispatch(run) => dispatch_effect(run)
    Run(descriptor, run) => run_effect(descriptor, run)
    Task(descriptor, start) => start_task(descriptor, start)
  }
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
    Run(descriptor, run) =>
      Run(descriptor, dispatch => run(message => dispatch(map(message))))
    Task(descriptor, start) =>
      Task(descriptor, dispatch => start(message => dispatch(map(message))))
  }
}

///|
pub fn[Model, Msg] Program::new(
  init~ : () -> (Model, Effect[Msg]),
  update~ : (Model, Msg) -> (Model, Effect[Msg]),
  view~ : (Model) -> View[Msg],
  subscriptions? : (Model) -> Subscription[Msg] = _model => Subscription::none(),
) -> Program[Model, Msg] {
  {
    init,
    update,
    view: (model, _env) => view(model),
    subscriptions,
    commands: _model => [],
  }
}

///|
pub fn[Model, Msg] Program::new_with_environment(
  init~ : () -> (Model, Effect[Msg]),
  update~ : (Model, Msg) -> (Model, Effect[Msg]),
  view~ : (Model, ViewEnvironment) -> View[Msg],
  subscriptions? : (Model) -> Subscription[Msg] = _model => Subscription::none(),
) -> Program[Model, Msg] {
  { init, update, view, subscriptions, commands: _model => [] }
}

///|
pub fn[Model, Msg] Program::with_commands(
  self : Program[Model, Msg],
  commands~ : (Model) -> Array[ProgramCommand[Msg]],
) -> Program[Model, Msg] {
  { ..self, commands, }
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
pub fn[Model, Msg] Program::runtime_init(
  self : Program[Model, Msg],
) -> (Model, Effect[Msg]) {
  (self.init)()
}

///|
pub fn[Model, Msg] Program::runtime_update(
  self : Program[Model, Msg],
  model : Model,
  message : Msg,
) -> (Model, Effect[Msg]) {
  (self.update)(model, message)
}

///|
pub fn[Model, Msg] Program::runtime_view(
  self : Program[Model, Msg],
  model : Model,
  environment : ViewEnvironment,
) -> View[Msg] {
  (self.view)(model, environment)
}

///|
pub fn[Model, Msg] Program::runtime_subscriptions(
  self : Program[Model, Msg],
  model : Model,
) -> Subscription[Msg] {
  (self.subscriptions)(model)
}

///|
pub fn[Model, Msg] Program::runtime_commands(
  self : Program[Model, Msg],
  model : Model,
) -> Array[ProgramCommand[Msg]] {
  (self.commands)(model)
}
