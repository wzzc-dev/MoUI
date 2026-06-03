///|
pub struct Subscription[Msg] {
  priv node : SubscriptionNode[Msg]
}

///|
priv enum SubscriptionNode[Msg] {
  SubscriptionNone
  SubscriptionBatch(Array[Subscription[Msg]])
  SubscriptionSource(SubscriptionSource[Msg])
}

///|
priv struct SubscriptionSource[Msg] {
  key : String
  kind : String
  label : String
  start : ((Msg) -> Unit) -> (() -> Unit)?
}

///|
pub(all) struct SubscriptionDescriptor {
  key : String
  kind : String
  label : String
} derive(Eq, Debug, ToJson)

///|
pub(all) enum SubscriptionPlanKind {
  SubscriptionPlanNone
  SubscriptionPlanBatch
  SubscriptionPlanSource
} derive(Eq, Debug, ToJson)

///|
pub(all) struct SubscriptionPlanSummary {
  root_kind : SubscriptionPlanKind
  none_count : Int
  batch_count : Int
  source_count : Int
  duplicate_key_count : Int
  max_depth : Int
} derive(Eq, Debug, ToJson)

///|
pub(all) enum SubscriptionLifecycleStatus {
  SubscriptionActive
  SubscriptionCancelled
} derive(Eq, Debug, ToJson)

///|
pub(all) enum SubscriptionCancelReason {
  SubscriptionKeyChanged
  SubscriptionRuntimeDestroyed
} derive(Eq, Debug, ToJson)

///|
pub(all) struct SubscriptionLifecycleSnapshot {
  key : String
  kind : String
  label : String
  status : SubscriptionLifecycleStatus
  cancel_reason : SubscriptionCancelReason?
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ProgramRuntimeSnapshot {
  dispatched_count : Int
  update_count : Int
  effect_plan_count : Int
  effect_count : Int
  effect_none_count : Int
  effect_batch_count : Int
  effect_send_count : Int
  effect_dispatch_count : Int
  last_effect_summary : EffectPlanSummary
  last_scheduled_effect_summary : EffectPlanSummary
  subscription_plan_count : Int
  last_subscription_plan_summary : SubscriptionPlanSummary
  active_subscription_count : Int
  started_subscription_count : Int
  reused_subscription_count : Int
  cancelled_subscription_count : Int
  duplicate_subscription_key_count : Int
  active_subscriptions : Array[SubscriptionDescriptor]
  subscription_lifecycle : Array[SubscriptionLifecycleSnapshot]
} derive(Eq, Debug, ToJson)

///|
priv struct ActiveProgramSubscription {
  key : String
  mut kind : String
  mut label : String
  active : Ref[Bool]
  cancel : (() -> Unit)?
  mut reused : Bool
}

///|
priv struct ProgramRuntimeDiagnostics {
  mut dispatched_count : Int
  mut update_count : Int
  mut effect_plan_count : Int
  mut effect_count : Int
  mut effect_none_count : Int
  mut effect_batch_count : Int
  mut effect_send_count : Int
  mut effect_dispatch_count : Int
  mut last_effect_summary : EffectPlanSummary
  mut last_scheduled_effect_summary : EffectPlanSummary
  mut subscription_plan_count : Int
  mut last_subscription_plan_summary : SubscriptionPlanSummary
  mut started_subscription_count : Int
  mut reused_subscription_count : Int
  mut cancelled_subscription_count : Int
  mut duplicate_subscription_key_count : Int
  mut active_subscriptions : Array[ActiveProgramSubscription]
  subscription_lifecycle : Array[SubscriptionLifecycleSnapshot]
}

///|
pub fn[Msg] Subscription::none() -> Subscription[Msg] {
  { node: SubscriptionNone }
}

///|
pub fn[Msg] Subscription::batch(
  subscriptions : Array[Subscription[Msg]],
) -> Subscription[Msg] {
  { node: SubscriptionBatch(subscriptions) }
}

///|
pub fn[Msg] Subscription::run(
  key~ : String,
  start~ : ((Msg) -> Unit) -> (() -> Unit)?,
  kind? : String = "custom",
  label? : String = "",
) -> Subscription[Msg] {
  Subscription::listen(key~, start~, kind~, label~)
}

///|
pub fn[Msg] Subscription::listen(
  key~ : String,
  start~ : ((Msg) -> Unit) -> (() -> Unit)?,
  kind? : String = "custom",
  label? : String = "",
) -> Subscription[Msg] {
  { node: SubscriptionSource({ key, kind, label, start }) }
}

///|
pub fn[Msg, NextMsg] Subscription::map(
  self : Subscription[Msg],
  map : (Msg) -> NextMsg,
) -> Subscription[NextMsg] {
  match self.node {
    SubscriptionNone => Subscription::none()
    SubscriptionBatch(subscriptions) =>
      Subscription::batch(
        subscriptions.map(subscription => subscription.map(map)),
      )
    SubscriptionSource(source) =>
      Subscription::listen(
        key=source.key,
        kind=source.kind,
        label=source.label,
        start=dispatch => (source.start)(message => dispatch(map(message))),
      )
  }
}

///|
pub fn[Msg] Subscription::descriptors(
  self : Subscription[Msg],
) -> Array[SubscriptionDescriptor] {
  self.sources().map(source => source.descriptor())
}

///|
pub fn[Msg] Subscription::plan_summary(
  self : Subscription[Msg],
) -> SubscriptionPlanSummary {
  let summary = subscription_plan_summary(self, depth=1)
  { ..summary, duplicate_key_count: self.duplicate_key_count() }
}

///|
pub fn SubscriptionPlanSummary::empty() -> SubscriptionPlanSummary {
  {
    root_kind: SubscriptionPlanKind::SubscriptionPlanNone,
    none_count: 0,
    batch_count: 0,
    source_count: 0,
    duplicate_key_count: 0,
    max_depth: 0,
  }
}

///|
fn[Msg] Subscription::sources(
  self : Subscription[Msg],
) -> Array[SubscriptionSource[Msg]] {
  match self.node {
    SubscriptionNone => []
    SubscriptionBatch(subscriptions) => {
      let sources : Array[SubscriptionSource[Msg]] = []
      for subscription in subscriptions {
        sources.append(subscription.sources())
      }
      sources
    }
    SubscriptionSource(source) => [source]
  }
}

///|
fn[Msg] Subscription::duplicate_key_count(self : Subscription[Msg]) -> Int {
  let seen_keys : Array[String] = []
  let mut duplicate_count = 0
  for source in self.sources() {
    if seen_keys.any(key => key == source.key) {
      duplicate_count = duplicate_count + 1
    } else {
      seen_keys.push(source.key)
    }
  }
  duplicate_count
}

///|
fn[Msg] subscription_plan_summary(
  subscription : Subscription[Msg],
  depth~ : Int,
) -> SubscriptionPlanSummary {
  match subscription.node {
    SubscriptionNone =>
      {
        root_kind: SubscriptionPlanKind::SubscriptionPlanNone,
        none_count: 1,
        batch_count: 0,
        source_count: 0,
        duplicate_key_count: 0,
        max_depth: depth,
      }
    SubscriptionSource(_) =>
      {
        root_kind: SubscriptionPlanKind::SubscriptionPlanSource,
        none_count: 0,
        batch_count: 0,
        source_count: 1,
        duplicate_key_count: 0,
        max_depth: depth,
      }
    SubscriptionBatch(subscriptions) => {
      let mut none_count = 0
      let mut batch_count = 1
      let mut source_count = 0
      let mut max_depth = depth
      for child in subscriptions {
        let child_summary = subscription_plan_summary(child, depth=depth + 1)
        none_count = none_count + child_summary.none_count
        batch_count = batch_count + child_summary.batch_count
        source_count = source_count + child_summary.source_count
        if child_summary.max_depth > max_depth {
          max_depth = child_summary.max_depth
        }
      }
      {
        root_kind: SubscriptionPlanKind::SubscriptionPlanBatch,
        none_count,
        batch_count,
        source_count,
        duplicate_key_count: 0,
        max_depth,
      }
    }
  }
}

///|
fn[Msg] SubscriptionSource::descriptor(
  self : SubscriptionSource[Msg],
) -> SubscriptionDescriptor {
  { key: self.key, kind: self.kind, label: self.label }
}

///|
fn ProgramRuntimeDiagnostics::new() -> ProgramRuntimeDiagnostics {
  {
    dispatched_count: 0,
    update_count: 0,
    effect_plan_count: 0,
    effect_count: 0,
    effect_none_count: 0,
    effect_batch_count: 0,
    effect_send_count: 0,
    effect_dispatch_count: 0,
    last_effect_summary: EffectPlanSummary::empty(),
    last_scheduled_effect_summary: EffectPlanSummary::empty(),
    subscription_plan_count: 0,
    last_subscription_plan_summary: SubscriptionPlanSummary::empty(),
    started_subscription_count: 0,
    reused_subscription_count: 0,
    cancelled_subscription_count: 0,
    duplicate_subscription_key_count: 0,
    active_subscriptions: [],
    subscription_lifecycle: [],
  }
}

///|
fn ProgramRuntimeDiagnostics::record_dispatch(
  self : ProgramRuntimeDiagnostics,
) -> Unit {
  self.dispatched_count = self.dispatched_count + 1
}

///|
fn ProgramRuntimeDiagnostics::record_update(
  self : ProgramRuntimeDiagnostics,
) -> Unit {
  self.update_count = self.update_count + 1
}

///|
fn ProgramRuntimeDiagnostics::record_effects(
  self : ProgramRuntimeDiagnostics,
  summary : EffectPlanSummary,
  executed_count : Int,
) -> Unit {
  self.effect_plan_count = self.effect_plan_count + 1
  self.effect_count = self.effect_count + executed_count
  self.effect_none_count = self.effect_none_count + summary.none_count
  self.effect_batch_count = self.effect_batch_count + summary.batch_count
  self.effect_send_count = self.effect_send_count + summary.send_count
  self.effect_dispatch_count = self.effect_dispatch_count +
    summary.dispatch_count
  self.last_effect_summary = summary
  if summary.scheduled_count > 0 {
    self.last_scheduled_effect_summary = summary
  }
}

///|
fn ProgramRuntimeDiagnostics::record_subscription_plan(
  self : ProgramRuntimeDiagnostics,
  summary : SubscriptionPlanSummary,
) -> Unit {
  self.subscription_plan_count = self.subscription_plan_count + 1
  self.last_subscription_plan_summary = summary
}

///|
fn[Msg] ProgramRuntimeDiagnostics::sync_subscriptions(
  self : ProgramRuntimeDiagnostics,
  subscription : Subscription[Msg],
  dispatch : (Msg) -> Unit,
) -> Unit {
  self.record_subscription_plan(subscription.plan_summary())
  let next : Array[ActiveProgramSubscription] = []
  let seen_keys : Array[String] = []
  for active in self.active_subscriptions {
    active.reused = false
  }
  for source in subscription.sources() {
    if seen_keys.any(key => key == source.key) {
      self.duplicate_subscription_key_count = self.duplicate_subscription_key_count +
        1
      continue
    }
    seen_keys.push(source.key)
    match self.reusable_subscription(source.key) {
      Some(active) => {
        active.reused = true
        active.kind = source.kind
        active.label = source.label
        self.reused_subscription_count = self.reused_subscription_count + 1
        next.push(active)
      }
      None => next.push(self.start_subscription(source, dispatch))
    }
  }
  for active in self.active_subscriptions {
    if !active.reused {
      self.cancel_subscription(
        active,
        SubscriptionCancelReason::SubscriptionKeyChanged,
      )
    }
  }
  self.active_subscriptions = next
}

///|
fn ProgramRuntimeDiagnostics::cancel_all_subscriptions(
  self : ProgramRuntimeDiagnostics,
  reason : SubscriptionCancelReason,
) -> Unit {
  for active in self.active_subscriptions {
    self.cancel_subscription(active, reason)
  }
  self.active_subscriptions = []
}

///|
fn ProgramRuntimeDiagnostics::reusable_subscription(
  self : ProgramRuntimeDiagnostics,
  key : String,
) -> ActiveProgramSubscription? {
  for active in self.active_subscriptions {
    if !active.reused && active.key == key {
      return Some(active)
    }
  }
  None
}

///|
fn[Msg] ProgramRuntimeDiagnostics::start_subscription(
  self : ProgramRuntimeDiagnostics,
  source : SubscriptionSource[Msg],
  dispatch : (Msg) -> Unit,
) -> ActiveProgramSubscription {
  let active = Ref(true)
  let cancel = (source.start)(message => if active.val { dispatch(message) })
  self.started_subscription_count = self.started_subscription_count + 1
  self.subscription_lifecycle.push({
    key: source.key,
    kind: source.kind,
    label: source.label,
    status: SubscriptionLifecycleStatus::SubscriptionActive,
    cancel_reason: None,
  })
  {
    key: source.key,
    kind: source.kind,
    label: source.label,
    active,
    cancel,
    reused: true,
  }
}

///|
fn ProgramRuntimeDiagnostics::cancel_subscription(
  self : ProgramRuntimeDiagnostics,
  active : ActiveProgramSubscription,
  reason : SubscriptionCancelReason,
) -> Unit {
  active.active.val = false
  match active.cancel {
    Some(cancel) => cancel()
    None => ()
  }
  self.cancelled_subscription_count = self.cancelled_subscription_count + 1
  self.subscription_lifecycle.push({
    key: active.key,
    kind: active.kind,
    label: active.label,
    status: SubscriptionLifecycleStatus::SubscriptionCancelled,
    cancel_reason: Some(reason),
  })
}

///|
fn ProgramRuntimeDiagnostics::snapshot(
  self : ProgramRuntimeDiagnostics,
) -> ProgramRuntimeSnapshot {
  {
    dispatched_count: self.dispatched_count,
    update_count: self.update_count,
    effect_plan_count: self.effect_plan_count,
    effect_count: self.effect_count,
    effect_none_count: self.effect_none_count,
    effect_batch_count: self.effect_batch_count,
    effect_send_count: self.effect_send_count,
    effect_dispatch_count: self.effect_dispatch_count,
    last_effect_summary: self.last_effect_summary,
    last_scheduled_effect_summary: self.last_scheduled_effect_summary,
    subscription_plan_count: self.subscription_plan_count,
    last_subscription_plan_summary: self.last_subscription_plan_summary,
    active_subscription_count: self.active_subscriptions.length(),
    started_subscription_count: self.started_subscription_count,
    reused_subscription_count: self.reused_subscription_count,
    cancelled_subscription_count: self.cancelled_subscription_count,
    duplicate_subscription_key_count: self.duplicate_subscription_key_count,
    active_subscriptions: self.active_subscriptions.map(active => {
      key: active.key,
      kind: active.kind,
      label: active.label,
    }),
    subscription_lifecycle: self.subscription_lifecycle.copy(),
  }
}

///|
fn ProgramRuntimeSnapshot::empty() -> ProgramRuntimeSnapshot {
  {
    dispatched_count: 0,
    update_count: 0,
    effect_plan_count: 0,
    effect_count: 0,
    effect_none_count: 0,
    effect_batch_count: 0,
    effect_send_count: 0,
    effect_dispatch_count: 0,
    last_effect_summary: EffectPlanSummary::empty(),
    last_scheduled_effect_summary: EffectPlanSummary::empty(),
    subscription_plan_count: 0,
    last_subscription_plan_summary: SubscriptionPlanSummary::empty(),
    active_subscription_count: 0,
    started_subscription_count: 0,
    reused_subscription_count: 0,
    cancelled_subscription_count: 0,
    duplicate_subscription_key_count: 0,
    active_subscriptions: [],
    subscription_lifecycle: [],
  }
}
