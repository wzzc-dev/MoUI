///|
pub(all) struct SubscriptionKindCount {
  kind : String
  count : Int
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
  EffectTaskKindChanged
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
  ignored_program_dispatch_count : Int
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
  duplicate_effect_descriptor_keys : Array[String]
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
  duplicate_subscription_keys : Array[String]
  ignored_subscription_dispatch_count : Int
  active_subscriptions : Array[SubscriptionDescriptor]
  active_subscription_kind_counts : Array[SubscriptionKindCount]
  subscription_lifecycle : Array[SubscriptionLifecycleSnapshot]
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
