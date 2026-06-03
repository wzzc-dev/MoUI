///|
pub(all) struct EffectDescriptor {
  key : String
  kind : String
  label : String
} derive(Eq, Debug, ToJson)

///|
pub(all) enum Effect[Msg] {
  NoEffect
  Batch(Array[Effect[Msg]])
  Send(Msg)
  Dispatch(((Msg) -> Unit) -> Unit)
  Run(EffectDescriptor, ((Msg) -> Unit) -> Unit)
}

///|
pub(all) enum EffectPlanKind {
  EffectPlanNone
  EffectPlanBatch
  EffectPlanSend
  EffectPlanDispatch
} derive(Eq, Debug, ToJson)

///|
pub(all) struct EffectPlanSummary {
  root_kind : EffectPlanKind
  none_count : Int
  batch_count : Int
  send_count : Int
  dispatch_count : Int
  scheduled_count : Int
  max_depth : Int
  descriptors : Array[EffectDescriptor]
  duplicate_descriptor_key_count : Int
} derive(Eq, Debug, ToJson)

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
pub fn[Msg] Effect::run(
  key~ : String,
  run~ : ((Msg) -> Unit) -> Unit,
  kind? : String = "custom",
  label? : String = "",
) -> Effect[Msg] {
  Run({ key, kind, label }, run)
}

///|
pub fn[Msg] Effect::plan_summary(self : Effect[Msg]) -> EffectPlanSummary {
  effect_plan_summary(self, depth=1)
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
    scheduled_count: 0,
    max_depth: 0,
    descriptors: [],
    duplicate_descriptor_key_count: 0,
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
        scheduled_count: 0,
        max_depth: depth,
        descriptors: [],
        duplicate_descriptor_key_count: 0,
      }
    Send(_) =>
      {
        root_kind: EffectPlanKind::EffectPlanSend,
        none_count: 0,
        batch_count: 0,
        send_count: 1,
        dispatch_count: 0,
        scheduled_count: 1,
        max_depth: depth,
        descriptors: [],
        duplicate_descriptor_key_count: 0,
      }
    Dispatch(_) =>
      {
        root_kind: EffectPlanKind::EffectPlanDispatch,
        none_count: 0,
        batch_count: 0,
        send_count: 0,
        dispatch_count: 1,
        scheduled_count: 1,
        max_depth: depth,
        descriptors: [],
        duplicate_descriptor_key_count: 0,
      }
    Run(descriptor, _) =>
      {
        root_kind: EffectPlanKind::EffectPlanDispatch,
        none_count: 0,
        batch_count: 0,
        send_count: 0,
        dispatch_count: 1,
        scheduled_count: 1,
        max_depth: depth,
        descriptors: [descriptor],
        duplicate_descriptor_key_count: 0,
      }
    Batch(effects) => {
      let mut none_count = 0
      let mut batch_count = 1
      let mut send_count = 0
      let mut dispatch_count = 0
      let mut scheduled_count = 0
      let mut max_depth = depth
      let descriptors : Array[EffectDescriptor] = []
      for child in effects {
        let child_summary = effect_plan_summary(child, depth=depth + 1)
        none_count = none_count + child_summary.none_count
        batch_count = batch_count + child_summary.batch_count
        send_count = send_count + child_summary.send_count
        dispatch_count = dispatch_count + child_summary.dispatch_count
        scheduled_count = scheduled_count + child_summary.scheduled_count
        if child_summary.max_depth > max_depth {
          max_depth = child_summary.max_depth
        }
        descriptors.append(child_summary.descriptors)
      }
      let duplicate_descriptor_key_count = duplicate_effect_descriptor_key_count(
        descriptors,
      )
      {
        root_kind: EffectPlanKind::EffectPlanBatch,
        none_count,
        batch_count,
        send_count,
        dispatch_count,
        scheduled_count,
        max_depth,
        descriptors,
        duplicate_descriptor_key_count,
      }
    }
  }
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
    Run(_descriptor, run) => {
      run(dispatch)
      1
    }
  }
}
