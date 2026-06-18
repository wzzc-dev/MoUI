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
  active_effect_tasks : Array[@core.EffectDescriptor]
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
  active_subscriptions : Array[@core.SubscriptionDescriptor]
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

test {
  ignore(ProgramRuntimeSnapshot::empty())
}

///|
pub(all) struct RuntimeInspectorSnapshot {
  size : @core.Size
  dirty_count : Int
  dirty_element_ids : Array[@core.ElementId]
  dirty_build_count : Int
  dirty_build_element_ids : Array[@core.ElementId]
  dirty_layout_count : Int
  dirty_layout_element_ids : Array[@core.ElementId]
  dirty_paint_count : Int
  dirty_paint_element_ids : Array[@core.ElementId]
  dirty_state : RuntimeDirtyStateSummary
  needs_rebuild : Bool
  needs_layout : Bool
  needs_paint : Bool
  needs_redraw : Bool
  draw_command_count : Int
  rebuild_pass_count : Int
  layout_pass_count : Int
  paint_pass_count : Int
  draw_command_build_count : Int
  program_dispatched_count : Int
  program_update_count : Int
  ignored_program_dispatch_count : Int
  program_message_enqueue_count : Int
  program_message_drain_count : Int
  program_pending_message_count : Int
  program_max_pending_message_count : Int
  program_effect_plan_count : Int
  program_effect_count : Int
  program_effect_none_count : Int
  program_effect_batch_count : Int
  program_effect_send_count : Int
  program_effect_dispatch_count : Int
  program_effect_run_count : Int
  program_effect_task_count : Int
  duplicate_effect_descriptor_key_count : Int
  duplicate_effect_descriptor_keys : Array[String]
  last_effect_summary : EffectPlanSummary
  last_scheduled_effect_summary : EffectPlanSummary
  active_effect_task_count : Int
  started_effect_task_count : Int
  completed_effect_task_count : Int
  cancelled_effect_task_count : Int
  ignored_effect_task_dispatch_count : Int
  active_effect_tasks : Array[@core.EffectDescriptor]
  effect_task_lifecycle : Array[EffectTaskLifecycleSnapshot]
  program_subscription_plan_count : Int
  last_subscription_plan_summary : SubscriptionPlanSummary
  active_subscription_count : Int
  started_subscription_count : Int
  reused_subscription_count : Int
  cancelled_subscription_count : Int
  duplicate_subscription_key_count : Int
  duplicate_subscription_keys : Array[String]
  ignored_subscription_dispatch_count : Int
  active_subscriptions : Array[@core.SubscriptionDescriptor]
  active_subscription_kind_counts : Array[SubscriptionKindCount]
  subscription_lifecycle : Array[SubscriptionLifecycleSnapshot]
  rebuild_reason : String
  dirty_reasons : Array[String]
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RuntimeDirtyStateSummary {
  dirty_count : Int
  dirty_element_ids : Array[@core.ElementId]
  dirty_build_count : Int
  dirty_build_element_ids : Array[@core.ElementId]
  dirty_layout_count : Int
  dirty_layout_element_ids : Array[@core.ElementId]
  dirty_paint_count : Int
  dirty_paint_element_ids : Array[@core.ElementId]
  needs_rebuild : Bool
  needs_layout : Bool
  needs_paint : Bool
  needs_redraw : Bool
  has_pending_work : Bool
  reason : String
  reasons : Array[String]
  damage_kind : String
  damage_rect_count : Int
  damage_full_reason : String
  cache_epoch : Int
  cached_layer_count : Int
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ViewInspectorSummary {
  element_id : @core.ElementId
  kind : String
  key : String
  child_count : Int
  needs_build : Bool
  needs_layout : Bool
  needs_paint : Bool
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ViewTreeInspectorSnapshot {
  root_kind : String
  node_count : Int
  component_count : Int
  control_count : Int
  modified_count : Int
  dirty_build_count : Int
  dirty_layout_count : Int
  dirty_paint_count : Int
  nodes : Array[ViewInspectorSummary]
} derive(Eq, Debug, ToJson)

///|
pub(all) struct LayoutBoundsInspectorEntry {
  element_id : @core.ElementId
  frame : @core.Rect
  depth : Int
  child_count : Int
} derive(Eq, Debug, ToJson)

///|
pub(all) struct LayoutInspectorSnapshot {
  root_frame : @core.Rect
  node_count : Int
  leaf_count : Int
  max_depth : Int
  bounds : Array[LayoutBoundsInspectorEntry]
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RenderInspectorSnapshot {
  command_count : Int
  text_count : Int
  image_count : Int
  clip_depth : Int
  open_clip_depth : Int
  layer_depth : Int
  open_layer_depth : Int
  filter_depth : Int
  open_filter_depth : Int
  path_count : Int
  shader_count : Int
  unbalanced_pop_count : Int
} derive(Eq, Debug, ToJson)

///|
pub(all) struct SemanticsInspectorSnapshot {
  root_role : @core.SemanticsRole
  node_count : Int
  focusable_count : Int
  action_count : Int
  max_depth : Int
  selected_count : Int
  checked_count : Int
  expanded_count : Int
  invalid_count : Int
  required_count : Int
  described_count : Int
} derive(Eq, Debug, ToJson)

///|
pub(all) struct InspectorSnapshot {
  runtime : RuntimeInspectorSnapshot
  view_tree : ViewTreeInspectorSnapshot
  layout : LayoutInspectorSnapshot
  render : RenderInspectorSnapshot
  semantics : SemanticsInspectorSnapshot
} derive(Eq, Debug, ToJson)

///|
pub fn RenderInspectorSnapshot::from_commands(
  commands : Array[@core.DrawCommand],
) -> RenderInspectorSnapshot {
  render_inspector_from_commands(commands)
}
