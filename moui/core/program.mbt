///|
#derive(Eq, Debug, ToJson)
struct EffectDescriptor {
  key : String
  kind : String
  label : String
}

///|
pub extend EffectDescriptor with Debug::{to_repr}

///|
pub extend EffectDescriptor with Eq::{not_equal, equal}

///|
pub extend EffectDescriptor with ToJson::{to_json}

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
  state_persistence : ProgramStatePersistence[Model]?
}

///|
pub fn[Msg] ProgramCommand::new(
  command~ : ActionCommand,
  message~ : Msg,
) -> ProgramCommand[Msg] {
  { command, message, }
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
  kind~ : String = "custom",
  label~ : String = "",
) -> Effect[Msg] {
  Run({ key, kind, label, }, run)
}

///|
pub fn[Msg] Effect::task(
  key~ : String,
  start~ : ((Msg) -> Unit) -> (() -> Unit)?,
  kind~ : String = "task",
  label~ : String = "",
) -> Effect[Msg] {
  Task({ key, kind, label, }, start)
}

///|
pub fn[Msg] Effect::service_task(
  key~ : String,
  start~ : ((Msg) -> Unit) -> (() -> Unit)?,
  label~ : String = "",
) -> Effect[Msg] {
  Effect::task(key~, start~, kind="service", label~)
}

///|
/// Encode a stable scope id once at mount construction. Escape `%` before `/`
/// so an id containing either character cannot alias a different scope/key
/// pair. An empty id is the root namespace.
fn scope_identity_prefix(scope_id : String) -> String {
  if scope_id == "" {
    ""
  } else {
    scope_id.replace_all(old="%", new="%25").replace_all(old="/", new="%2F") +
    "/"
  }
}

///|
fn scope_identity_key(scope_prefix : String, key : String) -> String {
  if scope_prefix == "" {
    key
  } else {
    scope_prefix + key
  }
}

///|
fn EffectDescriptor::prefix_scope(
  self : EffectDescriptor,
  scope_prefix : String,
) -> EffectDescriptor {
  { ..self, key: scope_identity_key(scope_prefix, self.key), }
}

///|
fn[Msg] Effect::prefix_scope(
  self : Effect[Msg],
  scope_prefix : String,
) -> Effect[Msg] {
  match self {
    NoEffect => NoEffect
    Batch(effects) =>
      Batch(effects.map(effect => effect.prefix_scope(scope_prefix)))
    Send(message) => Send(message)
    Dispatch(run) => Dispatch(run)
    Run(descriptor, run) => Run(descriptor.prefix_scope(scope_prefix), run)
    Task(descriptor, start) =>
      Task(descriptor.prefix_scope(scope_prefix), start)
  }
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
  subscriptions~ : (Model) -> Subscription[Msg] = _model => Subscription::none(),
) -> Program[Model, Msg] {
  {
    init,
    update,
    view: (model, _env) => view(model),
    subscriptions,
    commands: _model => [],
    state_persistence: None,
  }
}

///|
pub fn[Model, Msg] Program::new_with_environment(
  init~ : () -> (Model, Effect[Msg]),
  update~ : (Model, Msg) -> (Model, Effect[Msg]),
  view~ : (Model, ViewEnvironment) -> View[Msg],
  subscriptions~ : (Model) -> Subscription[Msg] = _model => Subscription::none(),
) -> Program[Model, Msg] {
  {
    init,
    update,
    view,
    subscriptions,
    commands: _model => [],
    state_persistence: None,
  }
}

///|
pub fn[Model, Msg] Program::with_commands(
  self : Program[Model, Msg],
  commands~ : (Model) -> Array[ProgramCommand[Msg]],
) -> Program[Model, Msg] {
  { ..self, commands, }
}

///|
/// Declare the model serialization used for state-preserving dev restarts.
/// When the composition root also supplies a `ProgramStateTransport`, the
/// runtime restores the model from the transport payload at construction and
/// writes the serialized model after every committed update. See
/// `ProgramStatePersistence` for the save/load contract.
pub fn[Model, Msg] Program::with_state_persistence(
  self : Program[Model, Msg],
  save~ : (Model) -> String,
  load~ : (String) -> Model?,
) -> Program[Model, Msg] {
  {
    ..self,
    state_persistence: Some(ProgramStatePersistence::new(save~, load~)),
  }
}

///|
pub fn[Model, Msg] Program::simple(
  init~ : Model,
  update~ : (Model, Msg) -> Model,
  view~ : (Model) -> View[Msg],
  subscriptions~ : (Model) -> Subscription[Msg] = _model => Subscription::none(),
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
  subscriptions~ : (Model) -> Subscription[Msg] = _model => Subscription::none(),
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

///|
pub fn[Model, Msg] Program::runtime_state_persistence(
  self : Program[Model, Msg],
) -> ProgramStatePersistence[Model]? {
  self.state_persistence
}
