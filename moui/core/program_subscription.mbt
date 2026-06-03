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
  duplicate_keys : Array[String]
  max_depth : Int
  descriptors : Array[SubscriptionDescriptor]
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
pub(all) enum EffectTaskLifecycleStatus {
  EffectTaskActive
  EffectTaskCompleted
  EffectTaskCancelled
} derive(Eq, Debug, ToJson)

///|
pub(all) enum EffectTaskCancelReason {
  EffectTaskKeyChanged
  EffectTaskRuntimeDestroyed
} derive(Eq, Debug, ToJson)

///|
pub(all) struct EffectTaskLifecycleSnapshot {
  key : String
  kind : String
  label : String
  status : EffectTaskLifecycleStatus
  cancel_reason : EffectTaskCancelReason?
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ProgramRuntimeSnapshot {
  dispatched_count : Int
  update_count : Int
  message_enqueue_count : Int
  message_drain_count : Int
  pending_message_count : Int
  max_pending_message_count : Int
  effect_plan_count : Int
  effect_count : Int
  effect_none_count : Int
  effect_batch_count : Int
  effect_send_count : Int
  effect_dispatch_count : Int
  effect_run_count : Int
  effect_task_count : Int
  duplicate_effect_descriptor_key_count : Int
  last_effect_summary : EffectPlanSummary
  last_scheduled_effect_summary : EffectPlanSummary
  active_effect_task_count : Int
  started_effect_task_count : Int
  completed_effect_task_count : Int
  cancelled_effect_task_count : Int
  ignored_effect_task_dispatch_count : Int
  active_effect_tasks : Array[EffectDescriptor]
  effect_task_lifecycle : Array[EffectTaskLifecycleSnapshot]
  subscription_plan_count : Int
  last_subscription_plan_summary : SubscriptionPlanSummary
  active_subscription_count : Int
  started_subscription_count : Int
  reused_subscription_count : Int
  cancelled_subscription_count : Int
  duplicate_subscription_key_count : Int
  ignored_subscription_dispatch_count : Int
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
priv struct ActiveProgramEffectTask {
  token : Int
  key : String
  kind : String
  label : String
  active : Ref[Bool]
  cancel : Ref[(() -> Unit)?]
}

///|
priv struct ProgramRuntimeDiagnostics {
  mut dispatched_count : Int
  mut update_count : Int
  mut message_enqueue_count : Int
  mut message_drain_count : Int
  mut pending_message_count : Int
  mut max_pending_message_count : Int
  mut effect_plan_count : Int
  mut effect_count : Int
  mut effect_none_count : Int
  mut effect_batch_count : Int
  mut effect_send_count : Int
  mut effect_dispatch_count : Int
  mut effect_run_count : Int
  mut effect_task_count : Int
  mut duplicate_effect_descriptor_key_count : Int
  mut last_effect_summary : EffectPlanSummary
  mut last_scheduled_effect_summary : EffectPlanSummary
  mut next_effect_task_value : Int
  mut started_effect_task_count : Int
  mut completed_effect_task_count : Int
  mut cancelled_effect_task_count : Int
  mut ignored_effect_task_dispatch_count : Int
  mut active_effect_tasks : Array[ActiveProgramEffectTask]
  effect_task_lifecycle : Array[EffectTaskLifecycleSnapshot]
  mut subscription_plan_count : Int
  mut last_subscription_plan_summary : SubscriptionPlanSummary
  mut started_subscription_count : Int
  mut reused_subscription_count : Int
  mut cancelled_subscription_count : Int
  mut duplicate_subscription_key_count : Int
  mut ignored_subscription_dispatch_count : Int
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
pub fn[Msg] Subscription::timer(
  key~ : String,
  start~ : ((Msg) -> Unit) -> (() -> Unit)?,
  label? : String = "",
) -> Subscription[Msg] {
  Subscription::listen(key~, start~, kind="timer", label~)
}

///|
pub fn[Msg] Subscription::animation_tick(
  key~ : String,
  start~ : ((Msg) -> Unit) -> (() -> Unit)?,
  label? : String = "",
) -> Subscription[Msg] {
  Subscription::listen(key~, start~, kind="animation", label~)
}

///|
pub fn[Msg] Subscription::window_event(
  key~ : String,
  start~ : ((Msg) -> Unit) -> (() -> Unit)?,
  label? : String = "",
) -> Subscription[Msg] {
  Subscription::listen(key~, start~, kind="window-event", label~)
}

///|
pub fn[Msg] Subscription::route_event(
  key~ : String,
  start~ : ((Msg) -> Unit) -> (() -> Unit)?,
  label? : String = "",
) -> Subscription[Msg] {
  Subscription::listen(key~, start~, kind="route-event", label~)
}

///|
pub fn[Msg] Subscription::service_completion(
  key~ : String,
  start~ : ((Msg) -> Unit) -> (() -> Unit)?,
  label? : String = "",
) -> Subscription[Msg] {
  Subscription::listen(key~, start~, kind="host-service", label~)
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
  {
    ..summary,
    duplicate_key_count: self.duplicate_key_count(),
    duplicate_keys: self.duplicate_keys(),
  }
}

///|
pub fn SubscriptionPlanSummary::empty() -> SubscriptionPlanSummary {
  {
    root_kind: SubscriptionPlanKind::SubscriptionPlanNone,
    none_count: 0,
    batch_count: 0,
    source_count: 0,
    duplicate_key_count: 0,
    duplicate_keys: [],
    max_depth: 0,
    descriptors: [],
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
fn[Msg] Subscription::duplicate_keys(self : Subscription[Msg]) -> Array[String] {
  let seen_keys : Array[String] = []
  let duplicate_keys : Array[String] = []
  for source in self.sources() {
    if seen_keys.any(key => key == source.key) {
      if !duplicate_keys.any(key => key == source.key) {
        duplicate_keys.push(source.key)
      }
    } else {
      seen_keys.push(source.key)
    }
  }
  duplicate_keys
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
        duplicate_keys: [],
        max_depth: depth,
        descriptors: [],
      }
    SubscriptionSource(source) =>
      {
        root_kind: SubscriptionPlanKind::SubscriptionPlanSource,
        none_count: 0,
        batch_count: 0,
        source_count: 1,
        duplicate_key_count: 0,
        duplicate_keys: [],
        max_depth: depth,
        descriptors: [source.descriptor()],
      }
    SubscriptionBatch(subscriptions) => {
      let mut none_count = 0
      let mut batch_count = 1
      let mut source_count = 0
      let mut max_depth = depth
      let descriptors : Array[SubscriptionDescriptor] = []
      for child in subscriptions {
        let child_summary = subscription_plan_summary(child, depth=depth + 1)
        none_count = none_count + child_summary.none_count
        batch_count = batch_count + child_summary.batch_count
        source_count = source_count + child_summary.source_count
        if child_summary.max_depth > max_depth {
          max_depth = child_summary.max_depth
        }
        descriptors.append(child_summary.descriptors)
      }
      {
        root_kind: SubscriptionPlanKind::SubscriptionPlanBatch,
        none_count,
        batch_count,
        source_count,
        duplicate_key_count: 0,
        duplicate_keys: [],
        max_depth,
        descriptors,
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
    message_enqueue_count: 0,
    message_drain_count: 0,
    pending_message_count: 0,
    max_pending_message_count: 0,
    effect_plan_count: 0,
    effect_count: 0,
    effect_none_count: 0,
    effect_batch_count: 0,
    effect_send_count: 0,
    effect_dispatch_count: 0,
    effect_run_count: 0,
    effect_task_count: 0,
    duplicate_effect_descriptor_key_count: 0,
    last_effect_summary: EffectPlanSummary::empty(),
    last_scheduled_effect_summary: EffectPlanSummary::empty(),
    next_effect_task_value: 1,
    started_effect_task_count: 0,
    completed_effect_task_count: 0,
    cancelled_effect_task_count: 0,
    ignored_effect_task_dispatch_count: 0,
    active_effect_tasks: [],
    effect_task_lifecycle: [],
    subscription_plan_count: 0,
    last_subscription_plan_summary: SubscriptionPlanSummary::empty(),
    started_subscription_count: 0,
    reused_subscription_count: 0,
    cancelled_subscription_count: 0,
    duplicate_subscription_key_count: 0,
    ignored_subscription_dispatch_count: 0,
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
fn ProgramRuntimeDiagnostics::record_message_enqueued(
  self : ProgramRuntimeDiagnostics,
  pending_count : Int,
) -> Unit {
  self.message_enqueue_count = self.message_enqueue_count + 1
  self.record_pending_message_count(pending_count)
}

///|
fn ProgramRuntimeDiagnostics::record_message_drain_started(
  self : ProgramRuntimeDiagnostics,
  pending_count : Int,
) -> Unit {
  if pending_count > 0 {
    self.message_drain_count = self.message_drain_count + 1
  }
  self.record_pending_message_count(pending_count)
}

///|
fn ProgramRuntimeDiagnostics::record_message_processed(
  self : ProgramRuntimeDiagnostics,
  pending_count : Int,
) -> Unit {
  self.record_pending_message_count(pending_count)
}

///|
fn ProgramRuntimeDiagnostics::record_message_queue_cleared(
  self : ProgramRuntimeDiagnostics,
) -> Unit {
  self.record_pending_message_count(0)
}

///|
fn ProgramRuntimeDiagnostics::record_pending_message_count(
  self : ProgramRuntimeDiagnostics,
  pending_count : Int,
) -> Unit {
  self.pending_message_count = pending_count
  if pending_count > self.max_pending_message_count {
    self.max_pending_message_count = pending_count
  }
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
  self.effect_run_count = self.effect_run_count + summary.run_count
  self.effect_task_count = self.effect_task_count + summary.task_count
  self.duplicate_effect_descriptor_key_count = self.duplicate_effect_descriptor_key_count +
    summary.duplicate_descriptor_key_count
  self.last_effect_summary = summary
  if summary.scheduled_count > 0 {
    self.last_scheduled_effect_summary = summary
  }
}

///|
fn ProgramRuntimeDiagnostics::record_ignored_effect_task_dispatch(
  self : ProgramRuntimeDiagnostics,
) -> Unit {
  self.ignored_effect_task_dispatch_count = self.ignored_effect_task_dispatch_count +
    1
}

///|
fn[Msg] ProgramRuntimeDiagnostics::start_effect_task(
  self : ProgramRuntimeDiagnostics,
  descriptor : EffectDescriptor,
  start : ((Msg) -> Unit) -> (() -> Unit)?,
  dispatch : (Msg) -> Unit,
) -> Unit {
  self.cancel_effect_tasks_by_key(
    descriptor.key,
    EffectTaskCancelReason::EffectTaskKeyChanged,
  )
  let token = self.next_effect_task_value
  self.next_effect_task_value = self.next_effect_task_value + 1
  let active = Ref(true)
  let cancel : Ref[(() -> Unit)?] = Ref(None)
  self.active_effect_tasks.push({
    token,
    key: descriptor.key,
    kind: descriptor.kind,
    label: descriptor.label,
    active,
    cancel,
  })
  self.started_effect_task_count = self.started_effect_task_count + 1
  self.effect_task_lifecycle.push({
    key: descriptor.key,
    kind: descriptor.kind,
    label: descriptor.label,
    status: EffectTaskLifecycleStatus::EffectTaskActive,
    cancel_reason: None,
  })
  let cleanup = start(message => {
    if active.val {
      active.val = false
      ignore(self.complete_effect_task(token))
      dispatch(message)
    } else {
      self.record_ignored_effect_task_dispatch()
    }
  })
  cancel.val = cleanup
  if cleanup is None && active.val {
    active.val = false
    ignore(self.complete_effect_task(token))
  }
}

///|
fn ProgramRuntimeDiagnostics::complete_effect_task(
  self : ProgramRuntimeDiagnostics,
  token : Int,
) -> Bool {
  let mut completed : ActiveProgramEffectTask? = None
  let remaining : Array[ActiveProgramEffectTask] = []
  for task in self.active_effect_tasks {
    match completed {
      None =>
        if task.token == token {
          completed = Some(task)
        } else {
          remaining.push(task)
        }
      Some(_) => remaining.push(task)
    }
  }
  self.active_effect_tasks = remaining
  match completed {
    Some(task) => {
      self.completed_effect_task_count = self.completed_effect_task_count + 1
      self.effect_task_lifecycle.push({
        key: task.key,
        kind: task.kind,
        label: task.label,
        status: EffectTaskLifecycleStatus::EffectTaskCompleted,
        cancel_reason: None,
      })
      true
    }
    None => false
  }
}

///|
fn ProgramRuntimeDiagnostics::cancel_effect_tasks_by_key(
  self : ProgramRuntimeDiagnostics,
  key : String,
  reason : EffectTaskCancelReason,
) -> Unit {
  let remaining : Array[ActiveProgramEffectTask] = []
  for task in self.active_effect_tasks {
    if task.key == key {
      self.cancel_effect_task(task, reason)
    } else {
      remaining.push(task)
    }
  }
  self.active_effect_tasks = remaining
}

///|
fn ProgramRuntimeDiagnostics::cancel_all_effect_tasks(
  self : ProgramRuntimeDiagnostics,
  reason : EffectTaskCancelReason,
) -> Unit {
  for task in self.active_effect_tasks {
    self.cancel_effect_task(task, reason)
  }
  self.active_effect_tasks = []
}

///|
fn ProgramRuntimeDiagnostics::cancel_effect_task(
  self : ProgramRuntimeDiagnostics,
  task : ActiveProgramEffectTask,
  reason : EffectTaskCancelReason,
) -> Unit {
  task.active.val = false
  match task.cancel.val {
    Some(cancel) => cancel()
    None => ()
  }
  self.cancelled_effect_task_count = self.cancelled_effect_task_count + 1
  self.effect_task_lifecycle.push({
    key: task.key,
    kind: task.kind,
    label: task.label,
    status: EffectTaskLifecycleStatus::EffectTaskCancelled,
    cancel_reason: Some(reason),
  })
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
fn ProgramRuntimeDiagnostics::record_ignored_subscription_dispatch(
  self : ProgramRuntimeDiagnostics,
) -> Unit {
  self.ignored_subscription_dispatch_count = self.ignored_subscription_dispatch_count +
    1
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
  let cancel = (source.start)(message => {
    if active.val {
      dispatch(message)
    } else {
      self.record_ignored_subscription_dispatch()
    }
  })
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
    message_enqueue_count: self.message_enqueue_count,
    message_drain_count: self.message_drain_count,
    pending_message_count: self.pending_message_count,
    max_pending_message_count: self.max_pending_message_count,
    effect_plan_count: self.effect_plan_count,
    effect_count: self.effect_count,
    effect_none_count: self.effect_none_count,
    effect_batch_count: self.effect_batch_count,
    effect_send_count: self.effect_send_count,
    effect_dispatch_count: self.effect_dispatch_count,
    effect_run_count: self.effect_run_count,
    effect_task_count: self.effect_task_count,
    duplicate_effect_descriptor_key_count: self.duplicate_effect_descriptor_key_count,
    last_effect_summary: self.last_effect_summary,
    last_scheduled_effect_summary: self.last_scheduled_effect_summary,
    active_effect_task_count: self.active_effect_tasks.length(),
    started_effect_task_count: self.started_effect_task_count,
    completed_effect_task_count: self.completed_effect_task_count,
    cancelled_effect_task_count: self.cancelled_effect_task_count,
    ignored_effect_task_dispatch_count: self.ignored_effect_task_dispatch_count,
    active_effect_tasks: self.active_effect_tasks.map(task => {
      key: task.key,
      kind: task.kind,
      label: task.label,
    }),
    effect_task_lifecycle: self.effect_task_lifecycle.copy(),
    subscription_plan_count: self.subscription_plan_count,
    last_subscription_plan_summary: self.last_subscription_plan_summary,
    active_subscription_count: self.active_subscriptions.length(),
    started_subscription_count: self.started_subscription_count,
    reused_subscription_count: self.reused_subscription_count,
    cancelled_subscription_count: self.cancelled_subscription_count,
    duplicate_subscription_key_count: self.duplicate_subscription_key_count,
    ignored_subscription_dispatch_count: self.ignored_subscription_dispatch_count,
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
    message_enqueue_count: 0,
    message_drain_count: 0,
    pending_message_count: 0,
    max_pending_message_count: 0,
    effect_plan_count: 0,
    effect_count: 0,
    effect_none_count: 0,
    effect_batch_count: 0,
    effect_send_count: 0,
    effect_dispatch_count: 0,
    effect_run_count: 0,
    effect_task_count: 0,
    duplicate_effect_descriptor_key_count: 0,
    last_effect_summary: EffectPlanSummary::empty(),
    last_scheduled_effect_summary: EffectPlanSummary::empty(),
    active_effect_task_count: 0,
    started_effect_task_count: 0,
    completed_effect_task_count: 0,
    cancelled_effect_task_count: 0,
    ignored_effect_task_dispatch_count: 0,
    active_effect_tasks: [],
    effect_task_lifecycle: [],
    subscription_plan_count: 0,
    last_subscription_plan_summary: SubscriptionPlanSummary::empty(),
    active_subscription_count: 0,
    started_subscription_count: 0,
    reused_subscription_count: 0,
    cancelled_subscription_count: 0,
    duplicate_subscription_key_count: 0,
    ignored_subscription_dispatch_count: 0,
    active_subscriptions: [],
    subscription_lifecycle: [],
  }
}
