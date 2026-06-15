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
priv enum EffectRuntimeOpNode[Msg] {
  EffectRuntimeSend(Msg)
  EffectRuntimeDispatch(((Msg) -> Unit) -> Unit)
  EffectRuntimeRun(EffectDescriptor, ((Msg) -> Unit) -> Unit)
  EffectRuntimeTask(EffectDescriptor, ((Msg) -> Unit) -> (() -> Unit)?)
}

///|
pub struct EffectRuntimeOp[Msg] {
  priv node : EffectRuntimeOpNode[Msg]
}

///|
pub(all) enum EffectPlanKind {
  EffectPlanNone
  EffectPlanBatch
  EffectPlanSend
  EffectPlanDispatch
  EffectPlanRun
  EffectPlanTask
} derive(Eq, Debug, ToJson)

///|
pub(all) struct EffectPlanSummary {
  root_kind : EffectPlanKind
  none_count : Int
  batch_count : Int
  send_count : Int
  dispatch_count : Int
  run_count : Int
  task_count : Int
  scheduled_count : Int
  max_depth : Int
  descriptors : Array[EffectDescriptor]
  duplicate_descriptor_key_count : Int
  duplicate_descriptor_keys : Array[String]
} derive(Eq, Debug, ToJson)

///|
struct Program[Model, Msg] {
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
pub fn[Msg] Effect::run(
  key~ : String,
  run~ : ((Msg) -> Unit) -> Unit,
  kind? : String = "custom",
  label? : String = "",
) -> Effect[Msg] {
  Run({ key, kind, label }, run)
}

///|
pub fn[Msg] Effect::host_service(
  key~ : String,
  run~ : ((Msg) -> Unit) -> Unit,
  label? : String = "",
) -> Effect[Msg] {
  Effect::run(key~, run~, kind="host-service", label~)
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
pub fn[Msg] Effect::plan_summary(self : Effect[Msg]) -> EffectPlanSummary {
  effect_plan_summary(self, depth=1)
}

///|
pub fn[Msg] Effect::runtime_ops(
  self : Effect[Msg],
) -> Array[EffectRuntimeOp[Msg]] {
  effect_runtime_ops(self)
}

///|
pub fn[Msg] EffectRuntimeOp::runtime_visit(
  self : EffectRuntimeOp[Msg],
  send : (Msg) -> Unit,
  dispatch_effect : (((Msg) -> Unit) -> Unit) -> Unit,
  run_effect : (EffectDescriptor, ((Msg) -> Unit) -> Unit) -> Unit,
  start_task : (EffectDescriptor, ((Msg) -> Unit) -> (() -> Unit)?) -> Unit,
) -> Unit {
  match self.node {
    EffectRuntimeSend(message) => send(message)
    EffectRuntimeDispatch(run) => dispatch_effect(run)
    EffectRuntimeRun(descriptor, run) => run_effect(descriptor, run)
    EffectRuntimeTask(descriptor, start) => start_task(descriptor, start)
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
pub fn EffectPlanSummary::empty() -> EffectPlanSummary {
  {
    root_kind: EffectPlanKind::EffectPlanNone,
    none_count: 0,
    batch_count: 0,
    send_count: 0,
    dispatch_count: 0,
    run_count: 0,
    task_count: 0,
    scheduled_count: 0,
    max_depth: 0,
    descriptors: [],
    duplicate_descriptor_key_count: 0,
    duplicate_descriptor_keys: [],
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
fn[Msg] effect_plan_summary(
  effect : Effect[Msg],
  depth~ : Int,
) -> EffectPlanSummary {
  match effect {
    NoEffect =>
      {
        root_kind: EffectPlanKind::EffectPlanNone,
        none_count: 1,
        batch_count: 0,
        send_count: 0,
        dispatch_count: 0,
        run_count: 0,
        task_count: 0,
        scheduled_count: 0,
        max_depth: depth,
        descriptors: [],
        duplicate_descriptor_key_count: 0,
        duplicate_descriptor_keys: [],
      }
    Send(_) =>
      {
        root_kind: EffectPlanKind::EffectPlanSend,
        none_count: 0,
        batch_count: 0,
        send_count: 1,
        dispatch_count: 0,
        run_count: 0,
        task_count: 0,
        scheduled_count: 1,
        max_depth: depth,
        descriptors: [],
        duplicate_descriptor_key_count: 0,
        duplicate_descriptor_keys: [],
      }
    Dispatch(_) =>
      {
        root_kind: EffectPlanKind::EffectPlanDispatch,
        none_count: 0,
        batch_count: 0,
        send_count: 0,
        dispatch_count: 1,
        run_count: 0,
        task_count: 0,
        scheduled_count: 1,
        max_depth: depth,
        descriptors: [],
        duplicate_descriptor_key_count: 0,
        duplicate_descriptor_keys: [],
      }
    Run(descriptor, _) =>
      {
        root_kind: EffectPlanKind::EffectPlanRun,
        none_count: 0,
        batch_count: 0,
        send_count: 0,
        dispatch_count: 0,
        run_count: 1,
        task_count: 0,
        scheduled_count: 1,
        max_depth: depth,
        descriptors: [descriptor],
        duplicate_descriptor_key_count: 0,
        duplicate_descriptor_keys: [],
      }
    Task(descriptor, _) =>
      {
        root_kind: EffectPlanKind::EffectPlanTask,
        none_count: 0,
        batch_count: 0,
        send_count: 0,
        dispatch_count: 0,
        run_count: 0,
        task_count: 1,
        scheduled_count: 1,
        max_depth: depth,
        descriptors: [descriptor],
        duplicate_descriptor_key_count: 0,
        duplicate_descriptor_keys: [],
      }
    Batch(effects) => {
      let mut none_count = 0
      let mut batch_count = 1
      let mut send_count = 0
      let mut dispatch_count = 0
      let mut run_count = 0
      let mut task_count = 0
      let mut scheduled_count = 0
      let mut max_depth = depth
      let descriptors : Array[EffectDescriptor] = []
      for child in effects {
        let child_summary = effect_plan_summary(child, depth=depth + 1)
        none_count = none_count + child_summary.none_count
        batch_count = batch_count + child_summary.batch_count
        send_count = send_count + child_summary.send_count
        dispatch_count = dispatch_count + child_summary.dispatch_count
        run_count = run_count + child_summary.run_count
        task_count = task_count + child_summary.task_count
        scheduled_count = scheduled_count + child_summary.scheduled_count
        if child_summary.max_depth > max_depth {
          max_depth = child_summary.max_depth
        }
        descriptors.append(child_summary.descriptors)
      }
      let duplicate_descriptor_key_count = duplicate_effect_descriptor_key_count(
        descriptors,
      )
      let duplicate_descriptor_keys = duplicate_effect_descriptor_keys(
        descriptors,
      )
      {
        root_kind: EffectPlanKind::EffectPlanBatch,
        none_count,
        batch_count,
        send_count,
        dispatch_count,
        run_count,
        task_count,
        scheduled_count,
        max_depth,
        descriptors,
        duplicate_descriptor_key_count,
        duplicate_descriptor_keys,
      }
    }
  }
}

///|
fn duplicate_effect_descriptor_keys(
  descriptors : Array[EffectDescriptor],
) -> Array[String] {
  let seen_keys : Array[String] = []
  let duplicate_keys : Array[String] = []
  for descriptor in descriptors {
    if seen_keys.any(key => key == descriptor.key) {
      if !duplicate_keys.any(key => key == descriptor.key) {
        duplicate_keys.push(descriptor.key)
      }
    } else {
      seen_keys.push(descriptor.key)
    }
  }
  duplicate_keys
}

///|
fn duplicate_effect_descriptor_key_count(
  descriptors : Array[EffectDescriptor],
) -> Int {
  let seen_keys : Array[String] = []
  let mut duplicate_count = 0
  for descriptor in descriptors {
    if seen_keys.any(key => key == descriptor.key) {
      duplicate_count = duplicate_count + 1
    } else {
      seen_keys.push(descriptor.key)
    }
  }
  duplicate_count
}

///|
fn[Msg] effect_runtime_ops(effect : Effect[Msg]) -> Array[EffectRuntimeOp[Msg]] {
  match effect {
    NoEffect => []
    Batch(effects) => {
      let ops : Array[EffectRuntimeOp[Msg]] = []
      for effect in effects {
        ops.append(effect_runtime_ops(effect))
      }
      ops
    }
    Send(message) => [{ node: EffectRuntimeSend(message) }]
    Dispatch(run) => [{ node: EffectRuntimeDispatch(run) }]
    Run(descriptor, run) => [{ node: EffectRuntimeRun(descriptor, run) }]
    Task(descriptor, start) => [{ node: EffectRuntimeTask(descriptor, start) }]
  }
}
