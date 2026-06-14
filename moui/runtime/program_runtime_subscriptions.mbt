///|
fn ProgramRuntimeDiagnostics::record_subscription_plan(
  self : ProgramRuntimeDiagnostics,
  summary : @core.SubscriptionPlanSummary,
) -> Unit {
  self.subscription_plan_count = self.subscription_plan_count + 1
  self.record_duplicate_subscription_keys(summary.duplicate_keys)
  self.last_subscription_plan_summary = summary
}

///|
fn ProgramRuntimeDiagnostics::record_duplicate_subscription_keys(
  self : ProgramRuntimeDiagnostics,
  keys : Array[String],
) -> Unit {
  for key in keys {
    if !self.duplicate_subscription_keys.any(existing => existing == key) {
      self.duplicate_subscription_keys.push(key)
    }
  }
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
  subscription : @core.Subscription[Msg],
  dispatch : (Msg) -> Unit,
) -> Unit {
  self.record_subscription_plan(subscription.plan_summary())
  let next : Array[ActiveProgramSubscription] = []
  let seen_keys : Array[String] = []
  for active in self.active_subscriptions {
    active.reused = false
  }
  for source in subscription.runtime_sources() {
    if seen_keys.any(key => key == source.key()) {
      self.duplicate_subscription_key_count = self.duplicate_subscription_key_count +
        1
      continue
    }
    seen_keys.push(source.key())
    match self.reusable_subscription(source.key(), source.kind()) {
      Some(active) => {
        active.reused = true
        active.kind = source.kind()
        active.label = source.label()
        active.descriptor = source.descriptor()
        self.reused_subscription_count = self.reused_subscription_count + 1
        next.push(active)
      }
      None => next.push(self.start_subscription(source, dispatch))
    }
  }
  for active in self.active_subscriptions {
    if !active.reused {
      self.cancel_subscription(active, subscription_cancel_reason(active, next))
    }
  }
  self.active_subscriptions = next
}

///|
fn ProgramRuntimeDiagnostics::cancel_all_subscriptions(
  self : ProgramRuntimeDiagnostics,
  reason : @core.SubscriptionCancelReason,
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
  kind : String,
) -> ActiveProgramSubscription? {
  for active in self.active_subscriptions {
    if !active.reused && active.key == key && active.kind == kind {
      return Some(active)
    }
  }
  None
}

///|
fn subscription_cancel_reason(
  active : ActiveProgramSubscription,
  next : Array[ActiveProgramSubscription],
) -> @core.SubscriptionCancelReason {
  if next.any(subscription => subscription.key == active.key) {
    @core.SubscriptionCancelReason::SubscriptionKindChanged
  } else {
    @core.SubscriptionCancelReason::SubscriptionKeyChanged
  }
}

///|
fn[Msg] ProgramRuntimeDiagnostics::start_subscription(
  self : ProgramRuntimeDiagnostics,
  source : @core.SubscriptionRuntimeSource[Msg],
  dispatch : (Msg) -> Unit,
) -> ActiveProgramSubscription {
  let active = Ref(true)
  let cancel = source.start(message => {
    if active.val {
      dispatch(message)
    } else {
      self.record_ignored_subscription_dispatch()
    }
  })
  self.started_subscription_count = self.started_subscription_count + 1
  self.subscription_lifecycle.push({
    key: source.key(),
    kind: source.kind(),
    label: source.label(),
    status: @core.SubscriptionLifecycleStatus::SubscriptionActive,
    cancel_reason: None,
  })
  {
    key: source.key(),
    kind: source.kind(),
    label: source.label(),
    descriptor: source.descriptor(),
    active,
    cancel,
    reused: true,
  }
}

///|
fn ProgramRuntimeDiagnostics::cancel_subscription(
  self : ProgramRuntimeDiagnostics,
  active : ActiveProgramSubscription,
  reason : @core.SubscriptionCancelReason,
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
    status: @core.SubscriptionLifecycleStatus::SubscriptionCancelled,
    cancel_reason: Some(reason),
  })
}

///|
fn ProgramRuntimeDiagnostics::active_subscription_kind_counts(
  self : ProgramRuntimeDiagnostics,
) -> Array[@core.SubscriptionKindCount] {
  let counts : Array[@core.SubscriptionKindCount] = []
  for active in self.active_subscriptions {
    let mut found = false
    for index, count in counts {
      if count.kind == active.kind {
        counts[index] = { ..count, count: count.count + 1 }
        found = true
      }
    }
    if !found {
      counts.push({ kind: active.kind, count: 1 })
    }
  }
  counts
}
