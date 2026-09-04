///|
priv struct ActiveProgramSubscription {
  key : String
  mut kind : String
  mut label : String
  mut descriptor : @core.SubscriptionDescriptor
  active : Ref[Bool]
  cancel : (() -> Unit)?
  mut reused : Bool
}

///|
priv struct ActiveProgramEffectTask {
  token : Int
  descriptor : @core.EffectDescriptor
  active : Ref[Bool]
  cancel : Ref[(() -> Unit)?]
}

///|
priv struct ProgramRuntimeDiagnostics {
  mut dispatched_count : Int
  mut update_count : Int
  mut ignored_program_dispatch_count : Int
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
  duplicate_effect_descriptor_keys : Array[String]
  mut superseded_effect_task_key_count : Int
  superseded_effect_task_keys : Array[String]
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
  duplicate_subscription_keys : Array[String]
  mut ignored_subscription_dispatch_count : Int
  mut active_subscriptions : Array[ActiveProgramSubscription]
  subscription_lifecycle : Array[SubscriptionLifecycleSnapshot]
}

///|
fn ProgramRuntimeDiagnostics::new() -> ProgramRuntimeDiagnostics {
  {
    dispatched_count: 0,
    update_count: 0,
    ignored_program_dispatch_count: 0,
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
    duplicate_effect_descriptor_keys: [],
    superseded_effect_task_key_count: 0,
    superseded_effect_task_keys: [],
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
    duplicate_subscription_keys: [],
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
fn ProgramRuntimeDiagnostics::record_ignored_program_dispatch(
  self : ProgramRuntimeDiagnostics,
) -> Unit {
  self.ignored_program_dispatch_count = self.ignored_program_dispatch_count + 1
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
  self.record_duplicate_effect_descriptor_keys(
    summary.duplicate_descriptor_keys,
  )
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
/// Records a live task whose key was reused by a descriptor with a different
/// kind or label. The supersession itself stays silent-cancel (last-writer
/// semantics); only the collision evidence is recorded so apps can discover
/// accidental key collisions through the diagnostics snapshot.
fn ProgramRuntimeDiagnostics::record_effect_task_key_supersession(
  self : ProgramRuntimeDiagnostics,
  replaced : @core.EffectDescriptor,
  incoming : @core.EffectDescriptor,
) -> Unit {
  self.superseded_effect_task_key_count = self.superseded_effect_task_key_count +
    1
  let detail = if replaced.kind() != incoming.kind() {
    "kind: " + replaced.kind() + " -> " + incoming.kind()
  } else {
    "label: " + replaced.label() + " -> " + incoming.label()
  }
  let record = incoming.key() + " (" + detail + ")"
  if !self.superseded_effect_task_keys.any(existing => existing == record) {
    self.superseded_effect_task_keys.push(record)
  }
}

///|
fn ProgramRuntimeDiagnostics::record_duplicate_effect_descriptor_keys(
  self : ProgramRuntimeDiagnostics,
  keys : Array[String],
) -> Unit {
  for key in keys {
    if !self.duplicate_effect_descriptor_keys.any(existing => existing == key) {
      self.duplicate_effect_descriptor_keys.push(key)
    }
  }
}

///|
fn ProgramRuntimeDiagnostics::snapshot(
  self : ProgramRuntimeDiagnostics,
) -> ProgramRuntimeSnapshot {
  {
    dispatched_count: self.dispatched_count,
    update_count: self.update_count,
    ignored_program_dispatch_count: self.ignored_program_dispatch_count,
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
    duplicate_effect_descriptor_keys: self.duplicate_effect_descriptor_keys.copy(),
    superseded_effect_task_key_count: self.superseded_effect_task_key_count,
    superseded_effect_task_keys: self.superseded_effect_task_keys.copy(),
    last_effect_summary: self.last_effect_summary,
    last_scheduled_effect_summary: self.last_scheduled_effect_summary,
    active_effect_task_count: self.active_effect_tasks.length(),
    started_effect_task_count: self.started_effect_task_count,
    completed_effect_task_count: self.completed_effect_task_count,
    cancelled_effect_task_count: self.cancelled_effect_task_count,
    ignored_effect_task_dispatch_count: self.ignored_effect_task_dispatch_count,
    active_effect_tasks: self.active_effect_tasks.map(task => task.descriptor),
    effect_task_lifecycle: self.effect_task_lifecycle.copy(),
    subscription_plan_count: self.subscription_plan_count,
    last_subscription_plan_summary: self.last_subscription_plan_summary,
    active_subscription_count: self.active_subscriptions.length(),
    started_subscription_count: self.started_subscription_count,
    reused_subscription_count: self.reused_subscription_count,
    cancelled_subscription_count: self.cancelled_subscription_count,
    duplicate_subscription_key_count: self.duplicate_subscription_key_count,
    duplicate_subscription_keys: self.duplicate_subscription_keys.copy(),
    ignored_subscription_dispatch_count: self.ignored_subscription_dispatch_count,
    active_subscriptions: self.active_subscriptions.map(active => {
      active.descriptor
    }),
    active_subscription_kind_counts: self.active_subscription_kind_counts(),
    subscription_lifecycle: self.subscription_lifecycle.copy(),
  }
}
