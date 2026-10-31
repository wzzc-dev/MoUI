///|
fn ProgramRuntimeDiagnostics::record_subscription_plan(
  self : ProgramRuntimeDiagnostics,
  summary : SubscriptionPlanSummary,
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
  self.record_subscription_plan(subscription_plan_summary(subscription))
  let next : Array[ActiveProgramSubscription] = []
  // Map-backed key identity (D2): source keys are unique per plan and active
  // keys are unique among actives, so both reuse lookups are O(1) instead of
  // O(n) `.any` scans per source (O(n²) per storm).
  let seen_keys : Map[String, Unit] = Map([])
  let active_by_key : Map[String, ActiveProgramSubscription] = Map([])
  for active in self.active_subscriptions {
    active.reused = false
    active_by_key[active.key] = active
  }
  for source in subscription.runtime_sources() {
    let key = source.key()
    if seen_keys.contains(key) {
      self.duplicate_subscription_key_count = self.duplicate_subscription_key_count +
        1
      continue
    }
    seen_keys[key] = ()
    match active_by_key.get(key) {
      Some(active) if active.kind == source.kind() => {
        active.reused = true
        active.kind = source.kind()
        active.label = source.label()
        active.descriptor = source.descriptor()
        self.reused_subscription_count = self.reused_subscription_count + 1
        next.push(active)
      }
      _ => next.push(self.start_subscription(source, dispatch))
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
  reason : SubscriptionCancelReason,
) -> Unit {
  for active in self.active_subscriptions {
    self.cancel_subscription(active, reason)
  }
  self.active_subscriptions = []
}

///|
fn subscription_cancel_reason(
  active : ActiveProgramSubscription,
  next : Array[ActiveProgramSubscription],
) -> SubscriptionCancelReason {
  if next.any(subscription => subscription.key == active.key) {
    SubscriptionKindChanged
  } else {
    SubscriptionKeyChanged
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
    status: SubscriptionActive,
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
    status: SubscriptionCancelled,
    cancel_reason: Some(reason),
  })
}

///|
fn ProgramRuntimeDiagnostics::active_subscription_kind_counts(
  self : ProgramRuntimeDiagnostics,
) -> Array[SubscriptionKindCount] {
  let counts : Array[SubscriptionKindCount] = []
  for active in self.active_subscriptions {
    let mut found = false
    for index, count in counts {
      if count.kind == active.kind {
        counts[index] = { ..count, count: count.count + 1, }
        found = true
      }
    }
    if !found {
      counts.push({ kind: active.kind, count: 1, })
    }
  }
  counts
}
