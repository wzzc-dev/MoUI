///|
pub struct SubscriptionKindCount {
  priv kind : String
  priv count : Int
} derive(Eq, Debug, ToJson)

///|
pub(all) enum SubscriptionLifecycleStatus {
  SubscriptionActive
  SubscriptionCancelled
} derive(Eq, Debug, ToJson)

///|
pub(all) enum SubscriptionCancelReason {
  SubscriptionKeyChanged
  SubscriptionKindChanged
  SubscriptionRuntimeDestroyed
} derive(Eq, Debug, ToJson)

///|
pub struct SubscriptionLifecycleSnapshot {
  priv key : String
  priv kind : String
  priv label : String
  priv status : SubscriptionLifecycleStatus
  priv cancel_reason : SubscriptionCancelReason?
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
  EffectTaskKindChanged
  EffectTaskRuntimeDestroyed
} derive(Eq, Debug, ToJson)

///|
pub struct EffectTaskLifecycleSnapshot {
  priv key : String
  priv kind : String
  priv label : String
  priv status : EffectTaskLifecycleStatus
  priv cancel_reason : EffectTaskCancelReason?
} derive(Eq, Debug, ToJson)

///|
pub struct ProgramRuntimeSnapshot {
  priv dispatched_count : Int
  priv update_count : Int
  priv ignored_program_dispatch_count : Int
  priv message_enqueue_count : Int
  priv message_drain_count : Int
  priv pending_message_count : Int
  priv max_pending_message_count : Int
  priv effect_plan_count : Int
  priv effect_count : Int
  priv effect_none_count : Int
  priv effect_batch_count : Int
  priv effect_send_count : Int
  priv effect_dispatch_count : Int
  priv effect_run_count : Int
  priv effect_task_count : Int
  priv duplicate_effect_descriptor_key_count : Int
  priv duplicate_effect_descriptor_keys : Array[String]
  priv superseded_effect_task_key_count : Int
  priv superseded_effect_task_keys : Array[String]
  priv last_effect_summary : EffectPlanSummary
  priv last_scheduled_effect_summary : EffectPlanSummary
  priv active_effect_task_count : Int
  priv started_effect_task_count : Int
  priv completed_effect_task_count : Int
  priv cancelled_effect_task_count : Int
  priv ignored_effect_task_dispatch_count : Int
  priv active_effect_tasks : Array[@core.EffectDescriptor]
  priv effect_task_lifecycle : Array[EffectTaskLifecycleSnapshot]
  priv subscription_plan_count : Int
  priv last_subscription_plan_summary : SubscriptionPlanSummary
  priv active_subscription_count : Int
  priv started_subscription_count : Int
  priv reused_subscription_count : Int
  priv cancelled_subscription_count : Int
  priv duplicate_subscription_key_count : Int
  priv duplicate_subscription_keys : Array[String]
  priv ignored_subscription_dispatch_count : Int
  priv active_subscriptions : Array[@core.SubscriptionDescriptor]
  priv active_subscription_kind_counts : Array[SubscriptionKindCount]
  priv subscription_lifecycle : Array[SubscriptionLifecycleSnapshot]
} derive(Eq, Debug, ToJson)

///|
fn ProgramRuntimeSnapshot::empty() -> ProgramRuntimeSnapshot {
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
    duplicate_subscription_keys: [],
    ignored_subscription_dispatch_count: 0,
    active_subscriptions: [],
    active_subscription_kind_counts: [],
    subscription_lifecycle: [],
  }
}

///|
test {
  ignore(ProgramRuntimeSnapshot::empty())
}

///|
pub fn SubscriptionKindCount::kind(self : SubscriptionKindCount) -> String {
  self.kind
}

///|
pub fn SubscriptionKindCount::count(self : SubscriptionKindCount) -> Int {
  self.count
}

///|
pub fn SubscriptionLifecycleSnapshot::key(
  self : SubscriptionLifecycleSnapshot,
) -> String {
  self.key
}

///|
pub fn SubscriptionLifecycleSnapshot::kind(
  self : SubscriptionLifecycleSnapshot,
) -> String {
  self.kind
}

///|
pub fn SubscriptionLifecycleSnapshot::label(
  self : SubscriptionLifecycleSnapshot,
) -> String {
  self.label
}

///|
pub fn SubscriptionLifecycleSnapshot::status(
  self : SubscriptionLifecycleSnapshot,
) -> SubscriptionLifecycleStatus {
  self.status
}

///|
pub fn SubscriptionLifecycleSnapshot::cancel_reason(
  self : SubscriptionLifecycleSnapshot,
) -> SubscriptionCancelReason? {
  self.cancel_reason
}

///|
pub fn EffectTaskLifecycleSnapshot::key(
  self : EffectTaskLifecycleSnapshot,
) -> String {
  self.key
}

///|
pub fn EffectTaskLifecycleSnapshot::kind(
  self : EffectTaskLifecycleSnapshot,
) -> String {
  self.kind
}

///|
pub fn EffectTaskLifecycleSnapshot::label(
  self : EffectTaskLifecycleSnapshot,
) -> String {
  self.label
}

///|
pub fn EffectTaskLifecycleSnapshot::status(
  self : EffectTaskLifecycleSnapshot,
) -> EffectTaskLifecycleStatus {
  self.status
}

///|
pub fn EffectTaskLifecycleSnapshot::cancel_reason(
  self : EffectTaskLifecycleSnapshot,
) -> EffectTaskCancelReason? {
  self.cancel_reason
}

///|
pub fn ProgramRuntimeSnapshot::dispatched_count(
  self : ProgramRuntimeSnapshot,
) -> Int {
  self.dispatched_count
}

///|
pub fn ProgramRuntimeSnapshot::update_count(
  self : ProgramRuntimeSnapshot,
) -> Int {
  self.update_count
}

///|
pub fn ProgramRuntimeSnapshot::ignored_program_dispatch_count(
  self : ProgramRuntimeSnapshot,
) -> Int {
  self.ignored_program_dispatch_count
}

///|
pub fn ProgramRuntimeSnapshot::message_enqueue_count(
  self : ProgramRuntimeSnapshot,
) -> Int {
  self.message_enqueue_count
}

///|
pub fn ProgramRuntimeSnapshot::message_drain_count(
  self : ProgramRuntimeSnapshot,
) -> Int {
  self.message_drain_count
}

///|
pub fn ProgramRuntimeSnapshot::pending_message_count(
  self : ProgramRuntimeSnapshot,
) -> Int {
  self.pending_message_count
}

///|
pub fn ProgramRuntimeSnapshot::max_pending_message_count(
  self : ProgramRuntimeSnapshot,
) -> Int {
  self.max_pending_message_count
}

///|
pub fn ProgramRuntimeSnapshot::effect_plan_count(
  self : ProgramRuntimeSnapshot,
) -> Int {
  self.effect_plan_count
}

///|
pub fn ProgramRuntimeSnapshot::effect_count(
  self : ProgramRuntimeSnapshot,
) -> Int {
  self.effect_count
}

///|
pub fn ProgramRuntimeSnapshot::effect_none_count(
  self : ProgramRuntimeSnapshot,
) -> Int {
  self.effect_none_count
}

///|
pub fn ProgramRuntimeSnapshot::effect_batch_count(
  self : ProgramRuntimeSnapshot,
) -> Int {
  self.effect_batch_count
}

///|
pub fn ProgramRuntimeSnapshot::effect_send_count(
  self : ProgramRuntimeSnapshot,
) -> Int {
  self.effect_send_count
}

///|
pub fn ProgramRuntimeSnapshot::effect_dispatch_count(
  self : ProgramRuntimeSnapshot,
) -> Int {
  self.effect_dispatch_count
}

///|
pub fn ProgramRuntimeSnapshot::effect_run_count(
  self : ProgramRuntimeSnapshot,
) -> Int {
  self.effect_run_count
}

///|
pub fn ProgramRuntimeSnapshot::effect_task_count(
  self : ProgramRuntimeSnapshot,
) -> Int {
  self.effect_task_count
}

///|
pub fn ProgramRuntimeSnapshot::duplicate_effect_descriptor_key_count(
  self : ProgramRuntimeSnapshot,
) -> Int {
  self.duplicate_effect_descriptor_key_count
}

///|
pub fn ProgramRuntimeSnapshot::duplicate_effect_descriptor_keys(
  self : ProgramRuntimeSnapshot,
) -> Array[String] {
  self.duplicate_effect_descriptor_keys
}

///|
pub fn ProgramRuntimeSnapshot::superseded_effect_task_key_count(
  self : ProgramRuntimeSnapshot,
) -> Int {
  self.superseded_effect_task_key_count
}

///|
pub fn ProgramRuntimeSnapshot::superseded_effect_task_keys(
  self : ProgramRuntimeSnapshot,
) -> Array[String] {
  self.superseded_effect_task_keys
}

///|
pub fn ProgramRuntimeSnapshot::last_effect_summary(
  self : ProgramRuntimeSnapshot,
) -> EffectPlanSummary {
  self.last_effect_summary
}

///|
pub fn ProgramRuntimeSnapshot::last_scheduled_effect_summary(
  self : ProgramRuntimeSnapshot,
) -> EffectPlanSummary {
  self.last_scheduled_effect_summary
}

///|
pub fn ProgramRuntimeSnapshot::active_effect_task_count(
  self : ProgramRuntimeSnapshot,
) -> Int {
  self.active_effect_task_count
}

///|
pub fn ProgramRuntimeSnapshot::started_effect_task_count(
  self : ProgramRuntimeSnapshot,
) -> Int {
  self.started_effect_task_count
}

///|
pub fn ProgramRuntimeSnapshot::completed_effect_task_count(
  self : ProgramRuntimeSnapshot,
) -> Int {
  self.completed_effect_task_count
}

///|
pub fn ProgramRuntimeSnapshot::cancelled_effect_task_count(
  self : ProgramRuntimeSnapshot,
) -> Int {
  self.cancelled_effect_task_count
}

///|
pub fn ProgramRuntimeSnapshot::ignored_effect_task_dispatch_count(
  self : ProgramRuntimeSnapshot,
) -> Int {
  self.ignored_effect_task_dispatch_count
}

///|
pub fn ProgramRuntimeSnapshot::active_effect_tasks(
  self : ProgramRuntimeSnapshot,
) -> Array[@core.EffectDescriptor] {
  self.active_effect_tasks
}

///|
pub fn ProgramRuntimeSnapshot::effect_task_lifecycle(
  self : ProgramRuntimeSnapshot,
) -> Array[EffectTaskLifecycleSnapshot] {
  self.effect_task_lifecycle
}

///|
pub fn ProgramRuntimeSnapshot::subscription_plan_count(
  self : ProgramRuntimeSnapshot,
) -> Int {
  self.subscription_plan_count
}

///|
pub fn ProgramRuntimeSnapshot::last_subscription_plan_summary(
  self : ProgramRuntimeSnapshot,
) -> SubscriptionPlanSummary {
  self.last_subscription_plan_summary
}

///|
pub fn ProgramRuntimeSnapshot::active_subscription_count(
  self : ProgramRuntimeSnapshot,
) -> Int {
  self.active_subscription_count
}

///|
pub fn ProgramRuntimeSnapshot::started_subscription_count(
  self : ProgramRuntimeSnapshot,
) -> Int {
  self.started_subscription_count
}

///|
pub fn ProgramRuntimeSnapshot::reused_subscription_count(
  self : ProgramRuntimeSnapshot,
) -> Int {
  self.reused_subscription_count
}

///|
pub fn ProgramRuntimeSnapshot::cancelled_subscription_count(
  self : ProgramRuntimeSnapshot,
) -> Int {
  self.cancelled_subscription_count
}

///|
pub fn ProgramRuntimeSnapshot::duplicate_subscription_key_count(
  self : ProgramRuntimeSnapshot,
) -> Int {
  self.duplicate_subscription_key_count
}

///|
pub fn ProgramRuntimeSnapshot::duplicate_subscription_keys(
  self : ProgramRuntimeSnapshot,
) -> Array[String] {
  self.duplicate_subscription_keys
}

///|
pub fn ProgramRuntimeSnapshot::ignored_subscription_dispatch_count(
  self : ProgramRuntimeSnapshot,
) -> Int {
  self.ignored_subscription_dispatch_count
}

///|
pub fn ProgramRuntimeSnapshot::active_subscriptions(
  self : ProgramRuntimeSnapshot,
) -> Array[@core.SubscriptionDescriptor] {
  self.active_subscriptions
}

///|
pub fn ProgramRuntimeSnapshot::active_subscription_kind_counts(
  self : ProgramRuntimeSnapshot,
) -> Array[SubscriptionKindCount] {
  self.active_subscription_kind_counts
}

///|
pub fn ProgramRuntimeSnapshot::subscription_lifecycle(
  self : ProgramRuntimeSnapshot,
) -> Array[SubscriptionLifecycleSnapshot] {
  self.subscription_lifecycle
}

///|
