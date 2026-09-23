///|
/// A composable TEA unit: the same five-tuple as `Program` (init, update,
/// view, subscriptions, commands) packaged as a value that can be defined,
/// tested, and mounted into a parent with `Feature::scope` independently of
/// the runtime root. `Program` stays the runtime-facing root; bridge the two
/// with `Program::from_feature`.
///
/// P13 note: the `write` half of a `Feature::scope` lens is a pure function
/// `(Child, Parent) -> Parent`. It is not an arbitrary setter — application
/// state still changes only inside `update`, and `Feature` introduces no
/// lifecycle state machine, binding, context, or mutable holder. Lens laws
/// expected of every `read`/`write` pair: `read(write(child, parent)) ==
/// child`, `write(read(parent), parent) == parent`, and a later `write`
/// supersedes an earlier one (last writer wins).
///
/// There is intentionally no `Feature::map`: a one-way message map is not
/// closed over `update`, because the input side would also need the inverse
/// function. Message lifting lives in `Feature::scope(wrap)`, where the
/// parent match arm has already unwrapped the child message — the same shape
/// as hand-written wrapper variants that lift with `Effect::map`.
///
/// Terminology: this `Feature` (core TEA composition unit) is unrelated to
/// `RendererFeature` (renderer capability tags) and to the feature-status /
/// feature-proof documentation pages.
struct Feature[Model, Msg] {
  init : () -> (Model, Effect[Msg])
  update : (Model, Msg) -> (Model, Effect[Msg])
  view : (Model, ViewEnvironment) -> View[Msg]
  subscriptions : (Model) -> Subscription[Msg]
  commands : (Model) -> Array[ProgramCommand[Msg]]
}

///|
pub fn[Model, Msg] Feature::new(
  init~ : () -> (Model, Effect[Msg]),
  update~ : (Model, Msg) -> (Model, Effect[Msg]),
  view~ : (Model) -> View[Msg],
  subscriptions? : (Model) -> Subscription[Msg] = _model => Subscription::none(),
) -> Feature[Model, Msg] {
  {
    init,
    update,
    view: (model, _env) => view(model),
    subscriptions,
    commands: _model => [],
  }
}

///|
pub fn[Model, Msg] Feature::new_with_environment(
  init~ : () -> (Model, Effect[Msg]),
  update~ : (Model, Msg) -> (Model, Effect[Msg]),
  view~ : (Model, ViewEnvironment) -> View[Msg],
  subscriptions? : (Model) -> Subscription[Msg] = _model => Subscription::none(),
) -> Feature[Model, Msg] {
  { init, update, view, subscriptions, commands: _model => [], }
}

///|
pub fn[Model, Msg] Feature::with_commands(
  self : Feature[Model, Msg],
  commands~ : (Model) -> Array[ProgramCommand[Msg]],
) -> Feature[Model, Msg] {
  { ..self, commands, }
}

///|
pub fn[Model, Msg] Feature::runtime_init(
  self : Feature[Model, Msg],
) -> (Model, Effect[Msg]) {
  (self.init)()
}

///|
pub fn[Model, Msg] Feature::runtime_update(
  self : Feature[Model, Msg],
  model : Model,
  message : Msg,
) -> (Model, Effect[Msg]) {
  (self.update)(model, message)
}

///|
pub fn[Model, Msg] Feature::runtime_view(
  self : Feature[Model, Msg],
  model : Model,
  environment : ViewEnvironment,
) -> View[Msg] {
  (self.view)(model, environment)
}

///|
pub fn[Model, Msg] Feature::runtime_subscriptions(
  self : Feature[Model, Msg],
  model : Model,
) -> Subscription[Msg] {
  (self.subscriptions)(model)
}

///|
pub fn[Model, Msg] Feature::runtime_commands(
  self : Feature[Model, Msg],
  model : Model,
) -> Array[ProgramCommand[Msg]] {
  (self.commands)(model)
}

///|
/// Mount `self` into a parent model through a `read`/`write` lens pair and a
/// `wrap` message constructor. The returned handle lifts child messages,
/// effects, views, subscriptions, and commands into the parent's types; the
/// parent `update` routes through one match arm per wrapper variant, exactly
/// like the hand-written delegation this replaces.
pub fn[Child, ChildMsg, Parent, ParentMsg] Feature::scope(
  self : Feature[Child, ChildMsg],
  read~ : (Parent) -> Child,
  write~ : (Child, Parent) -> Parent,
  wrap~ : (ChildMsg) -> ParentMsg,
) -> ScopedFeature[Parent, Child, ChildMsg, ParentMsg] {
  { read, write, feature: self, wrap, }
}

///|
/// A `Feature` mounted into a parent model, produced by `Feature::scope`.
/// Holds only pure functions (lens pair, message constructor, and the child
/// feature); it carries no state and can be rebuilt at any time.
pub struct ScopedFeature[Parent, Child, ChildMsg, ParentMsg] {
  priv read : (Parent) -> Child
  priv write : (Child, Parent) -> Parent
  priv feature : Feature[Child, ChildMsg]
  priv wrap : (ChildMsg) -> ParentMsg
}

///|
/// Run the child feature's `init`, returning the initial child model for the
/// parent to place and the startup effect already lifted to the parent's
/// message type. Batch several scopes' startup effects with
/// `Effect::batch`.
pub fn[Parent, Child, ChildMsg, ParentMsg] ScopedFeature::init(
  self : ScopedFeature[Parent, Child, ChildMsg, ParentMsg],
) -> (Child, Effect[ParentMsg]) {
  let (child, effect) = (self.feature.init)()
  (child, effect.map(self.wrap))
}

///|
/// Delegate one child message: read the child model through the lens, run
/// the child update, write the result back, and lift the effect to the
/// parent's message type.
pub fn[Parent, Child, ChildMsg, ParentMsg] ScopedFeature::update(
  self : ScopedFeature[Parent, Child, ChildMsg, ParentMsg],
  parent : Parent,
  message : ChildMsg,
) -> (Parent, Effect[ParentMsg]) {
  let (child, effect) = (self.feature.update)((self.read)(parent), message)
  ((self.write)(child, parent), effect.map(self.wrap))
}

///|
/// Build the child view from the parent model and lift its messages to the
/// parent's message type.
pub fn[Parent, Child, ChildMsg, ParentMsg] ScopedFeature::view(
  self : ScopedFeature[Parent, Child, ChildMsg, ParentMsg],
  parent : Parent,
  environment : ViewEnvironment,
) -> View[ParentMsg] {
  (self.feature.view)((self.read)(parent), environment).map(self.wrap)
}

///|
/// Derive the child subscriptions from the parent model and lift their
/// messages to the parent's message type.
pub fn[Parent, Child, ChildMsg, ParentMsg] ScopedFeature::subscriptions(
  self : ScopedFeature[Parent, Child, ChildMsg, ParentMsg],
  parent : Parent,
) -> Subscription[ParentMsg] {
  (self.feature.subscriptions)((self.read)(parent)).map(self.wrap)
}

///|
/// Derive the child program commands from the parent model and lift their
/// messages to the parent's message type.
pub fn[Parent, Child, ChildMsg, ParentMsg] ScopedFeature::commands(
  self : ScopedFeature[Parent, Child, ChildMsg, ParentMsg],
  parent : Parent,
) -> Array[ProgramCommand[ParentMsg]] {
  (self.feature.commands)((self.read)(parent)).map(command => {
    command.map(self.wrap)
  })
}

///|
/// Bridge a `Feature` into the runtime-facing `Program` root. The two types
/// are field-isomorphic; this is a record copy, not a wrapper with extra
/// behavior. App roots stay `Program`; children stay `Feature` until they
/// are scoped.
pub fn[Model, Msg] Program::from_feature(
  feature~ : Feature[Model, Msg],
) -> Program[Model, Msg] {
  {
    init: feature.init,
    update: feature.update,
    view: feature.view,
    subscriptions: feature.subscriptions,
    commands: feature.commands,
  }
}
