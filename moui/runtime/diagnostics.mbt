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
pub struct RuntimeInspectorSnapshot {
  priv size : @core.Size
  priv dirty_count : Int
  priv dirty_element_ids : Array[@core.ElementId]
  priv dirty_build_count : Int
  priv dirty_build_element_ids : Array[@core.ElementId]
  priv dirty_layout_count : Int
  priv dirty_layout_element_ids : Array[@core.ElementId]
  priv dirty_paint_count : Int
  priv dirty_paint_element_ids : Array[@core.ElementId]
  priv dirty_state : RuntimeDirtyStateSummary
  priv needs_rebuild : Bool
  priv needs_layout : Bool
  priv needs_paint : Bool
  priv needs_redraw : Bool
  priv draw_command_count : Int
  priv rebuild_pass_count : Int
  priv layout_pass_count : Int
  priv paint_pass_count : Int
  priv draw_command_build_count : Int
  priv program_dispatched_count : Int
  priv program_update_count : Int
  priv ignored_program_dispatch_count : Int
  priv program_message_enqueue_count : Int
  priv program_message_drain_count : Int
  priv program_pending_message_count : Int
  priv program_max_pending_message_count : Int
  priv program_effect_plan_count : Int
  priv program_effect_count : Int
  priv program_effect_none_count : Int
  priv program_effect_batch_count : Int
  priv program_effect_send_count : Int
  priv program_effect_dispatch_count : Int
  priv program_effect_run_count : Int
  priv program_effect_task_count : Int
  priv duplicate_effect_descriptor_key_count : Int
  priv duplicate_effect_descriptor_keys : Array[String]
  priv last_effect_summary : EffectPlanSummary
  priv last_scheduled_effect_summary : EffectPlanSummary
  priv active_effect_task_count : Int
  priv started_effect_task_count : Int
  priv completed_effect_task_count : Int
  priv cancelled_effect_task_count : Int
  priv ignored_effect_task_dispatch_count : Int
  priv active_effect_tasks : Array[@core.EffectDescriptor]
  priv effect_task_lifecycle : Array[EffectTaskLifecycleSnapshot]
  priv program_subscription_plan_count : Int
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
  priv rebuild_reason : String
  priv dirty_reasons : Array[String]
} derive(Eq, Debug, ToJson)

///|
pub struct RuntimeDirtyStateSummary {
  priv dirty_count : Int
  priv dirty_element_ids : Array[@core.ElementId]
  priv dirty_build_count : Int
  priv dirty_build_element_ids : Array[@core.ElementId]
  priv dirty_layout_count : Int
  priv dirty_layout_element_ids : Array[@core.ElementId]
  priv dirty_paint_count : Int
  priv dirty_paint_element_ids : Array[@core.ElementId]
  priv needs_rebuild : Bool
  priv needs_layout : Bool
  priv needs_paint : Bool
  priv needs_redraw : Bool
  priv has_pending_work : Bool
  priv reason : String
  priv reasons : Array[String]
  priv damage_kind : String
  priv damage_rect_count : Int
  priv damage_full_reason : String
  priv cache_epoch : Int
  priv cached_layer_count : Int
} derive(Eq, Debug, ToJson)

///|
pub struct ViewInspectorSummary {
  priv element_id : @core.ElementId
  priv kind : String
  priv key : String
  priv child_count : Int
  priv needs_build : Bool
  priv needs_layout : Bool
  priv needs_paint : Bool
} derive(Eq, Debug, ToJson)

///|
pub struct ViewTreeInspectorSnapshot {
  priv root_kind : String
  priv node_count : Int
  priv component_count : Int
  priv control_count : Int
  priv modified_count : Int
  priv dirty_build_count : Int
  priv dirty_layout_count : Int
  priv dirty_paint_count : Int
  priv nodes : Array[ViewInspectorSummary]
} derive(Eq, Debug, ToJson)

///|
pub struct LayoutBoundsInspectorEntry {
  priv element_id : @core.ElementId
  priv frame : @core.Rect
  priv depth : Int
  priv child_count : Int
} derive(Eq, Debug, ToJson)

///|
pub struct LayoutInspectorSnapshot {
  priv root_frame : @core.Rect
  priv node_count : Int
  priv leaf_count : Int
  priv max_depth : Int
  priv bounds : Array[LayoutBoundsInspectorEntry]
} derive(Eq, Debug, ToJson)

///|
pub struct RenderInspectorSnapshot {
  priv command_count : Int
  priv text_count : Int
  priv image_count : Int
  priv clip_depth : Int
  priv open_clip_depth : Int
  priv layer_depth : Int
  priv open_layer_depth : Int
  priv filter_depth : Int
  priv open_filter_depth : Int
  priv path_count : Int
  priv shader_count : Int
  priv unbalanced_pop_count : Int
} derive(Eq, Debug, ToJson)

///|
pub struct SemanticsInspectorSnapshot {
  priv root_role : @core.SemanticsRole
  priv node_count : Int
  priv focusable_count : Int
  priv action_count : Int
  priv max_depth : Int
  priv selected_count : Int
  priv checked_count : Int
  priv expanded_count : Int
  priv invalid_count : Int
  priv required_count : Int
  priv described_count : Int
} derive(Eq, Debug, ToJson)

///|
pub struct InspectorSnapshot {
  priv runtime : RuntimeInspectorSnapshot
  priv view_tree : ViewTreeInspectorSnapshot
  priv layout : LayoutInspectorSnapshot
  priv render : RenderInspectorSnapshot
  priv semantics : SemanticsInspectorSnapshot
} derive(Eq, Debug, ToJson)

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
pub fn RuntimeInspectorSnapshot::size(
  self : RuntimeInspectorSnapshot,
) -> @core.Size {
  self.size
}

///|
pub fn RuntimeInspectorSnapshot::dirty_count(
  self : RuntimeInspectorSnapshot,
) -> Int {
  self.dirty_count
}

///|
pub fn RuntimeInspectorSnapshot::dirty_element_ids(
  self : RuntimeInspectorSnapshot,
) -> Array[@core.ElementId] {
  self.dirty_element_ids
}

///|
pub fn RuntimeInspectorSnapshot::dirty_build_count(
  self : RuntimeInspectorSnapshot,
) -> Int {
  self.dirty_build_count
}

///|
pub fn RuntimeInspectorSnapshot::dirty_build_element_ids(
  self : RuntimeInspectorSnapshot,
) -> Array[@core.ElementId] {
  self.dirty_build_element_ids
}

///|
pub fn RuntimeInspectorSnapshot::dirty_layout_count(
  self : RuntimeInspectorSnapshot,
) -> Int {
  self.dirty_layout_count
}

///|
pub fn RuntimeInspectorSnapshot::dirty_layout_element_ids(
  self : RuntimeInspectorSnapshot,
) -> Array[@core.ElementId] {
  self.dirty_layout_element_ids
}

///|
pub fn RuntimeInspectorSnapshot::dirty_paint_count(
  self : RuntimeInspectorSnapshot,
) -> Int {
  self.dirty_paint_count
}

///|
pub fn RuntimeInspectorSnapshot::dirty_paint_element_ids(
  self : RuntimeInspectorSnapshot,
) -> Array[@core.ElementId] {
  self.dirty_paint_element_ids
}

///|
pub fn RuntimeInspectorSnapshot::dirty_state(
  self : RuntimeInspectorSnapshot,
) -> RuntimeDirtyStateSummary {
  self.dirty_state
}

///|
pub fn RuntimeInspectorSnapshot::needs_rebuild(
  self : RuntimeInspectorSnapshot,
) -> Bool {
  self.needs_rebuild
}

///|
pub fn RuntimeInspectorSnapshot::needs_layout(
  self : RuntimeInspectorSnapshot,
) -> Bool {
  self.needs_layout
}

///|
pub fn RuntimeInspectorSnapshot::needs_paint(
  self : RuntimeInspectorSnapshot,
) -> Bool {
  self.needs_paint
}

///|
pub fn RuntimeInspectorSnapshot::needs_redraw(
  self : RuntimeInspectorSnapshot,
) -> Bool {
  self.needs_redraw
}

///|
pub fn RuntimeInspectorSnapshot::draw_command_count(
  self : RuntimeInspectorSnapshot,
) -> Int {
  self.draw_command_count
}

///|
pub fn RuntimeInspectorSnapshot::rebuild_pass_count(
  self : RuntimeInspectorSnapshot,
) -> Int {
  self.rebuild_pass_count
}

///|
pub fn RuntimeInspectorSnapshot::layout_pass_count(
  self : RuntimeInspectorSnapshot,
) -> Int {
  self.layout_pass_count
}

///|
pub fn RuntimeInspectorSnapshot::paint_pass_count(
  self : RuntimeInspectorSnapshot,
) -> Int {
  self.paint_pass_count
}

///|
pub fn RuntimeInspectorSnapshot::draw_command_build_count(
  self : RuntimeInspectorSnapshot,
) -> Int {
  self.draw_command_build_count
}

///|
pub fn RuntimeInspectorSnapshot::program_dispatched_count(
  self : RuntimeInspectorSnapshot,
) -> Int {
  self.program_dispatched_count
}

///|
pub fn RuntimeInspectorSnapshot::program_update_count(
  self : RuntimeInspectorSnapshot,
) -> Int {
  self.program_update_count
}

///|
pub fn RuntimeInspectorSnapshot::ignored_program_dispatch_count(
  self : RuntimeInspectorSnapshot,
) -> Int {
  self.ignored_program_dispatch_count
}

///|
pub fn RuntimeInspectorSnapshot::program_message_enqueue_count(
  self : RuntimeInspectorSnapshot,
) -> Int {
  self.program_message_enqueue_count
}

///|
pub fn RuntimeInspectorSnapshot::program_message_drain_count(
  self : RuntimeInspectorSnapshot,
) -> Int {
  self.program_message_drain_count
}

///|
pub fn RuntimeInspectorSnapshot::program_pending_message_count(
  self : RuntimeInspectorSnapshot,
) -> Int {
  self.program_pending_message_count
}

///|
pub fn RuntimeInspectorSnapshot::program_max_pending_message_count(
  self : RuntimeInspectorSnapshot,
) -> Int {
  self.program_max_pending_message_count
}

///|
pub fn RuntimeInspectorSnapshot::program_effect_plan_count(
  self : RuntimeInspectorSnapshot,
) -> Int {
  self.program_effect_plan_count
}

///|
pub fn RuntimeInspectorSnapshot::program_effect_count(
  self : RuntimeInspectorSnapshot,
) -> Int {
  self.program_effect_count
}

///|
pub fn RuntimeInspectorSnapshot::program_effect_none_count(
  self : RuntimeInspectorSnapshot,
) -> Int {
  self.program_effect_none_count
}

///|
pub fn RuntimeInspectorSnapshot::program_effect_batch_count(
  self : RuntimeInspectorSnapshot,
) -> Int {
  self.program_effect_batch_count
}

///|
pub fn RuntimeInspectorSnapshot::program_effect_send_count(
  self : RuntimeInspectorSnapshot,
) -> Int {
  self.program_effect_send_count
}

///|
pub fn RuntimeInspectorSnapshot::program_effect_dispatch_count(
  self : RuntimeInspectorSnapshot,
) -> Int {
  self.program_effect_dispatch_count
}

///|
pub fn RuntimeInspectorSnapshot::program_effect_run_count(
  self : RuntimeInspectorSnapshot,
) -> Int {
  self.program_effect_run_count
}

///|
pub fn RuntimeInspectorSnapshot::program_effect_task_count(
  self : RuntimeInspectorSnapshot,
) -> Int {
  self.program_effect_task_count
}

///|
pub fn RuntimeInspectorSnapshot::duplicate_effect_descriptor_key_count(
  self : RuntimeInspectorSnapshot,
) -> Int {
  self.duplicate_effect_descriptor_key_count
}

///|
pub fn RuntimeInspectorSnapshot::duplicate_effect_descriptor_keys(
  self : RuntimeInspectorSnapshot,
) -> Array[String] {
  self.duplicate_effect_descriptor_keys
}

///|
pub fn RuntimeInspectorSnapshot::last_effect_summary(
  self : RuntimeInspectorSnapshot,
) -> EffectPlanSummary {
  self.last_effect_summary
}

///|
pub fn RuntimeInspectorSnapshot::last_scheduled_effect_summary(
  self : RuntimeInspectorSnapshot,
) -> EffectPlanSummary {
  self.last_scheduled_effect_summary
}

///|
pub fn RuntimeInspectorSnapshot::active_effect_task_count(
  self : RuntimeInspectorSnapshot,
) -> Int {
  self.active_effect_task_count
}

///|
pub fn RuntimeInspectorSnapshot::started_effect_task_count(
  self : RuntimeInspectorSnapshot,
) -> Int {
  self.started_effect_task_count
}

///|
pub fn RuntimeInspectorSnapshot::completed_effect_task_count(
  self : RuntimeInspectorSnapshot,
) -> Int {
  self.completed_effect_task_count
}

///|
pub fn RuntimeInspectorSnapshot::cancelled_effect_task_count(
  self : RuntimeInspectorSnapshot,
) -> Int {
  self.cancelled_effect_task_count
}

///|
pub fn RuntimeInspectorSnapshot::ignored_effect_task_dispatch_count(
  self : RuntimeInspectorSnapshot,
) -> Int {
  self.ignored_effect_task_dispatch_count
}

///|
pub fn RuntimeInspectorSnapshot::active_effect_tasks(
  self : RuntimeInspectorSnapshot,
) -> Array[@core.EffectDescriptor] {
  self.active_effect_tasks
}

///|
pub fn RuntimeInspectorSnapshot::effect_task_lifecycle(
  self : RuntimeInspectorSnapshot,
) -> Array[EffectTaskLifecycleSnapshot] {
  self.effect_task_lifecycle
}

///|
pub fn RuntimeInspectorSnapshot::program_subscription_plan_count(
  self : RuntimeInspectorSnapshot,
) -> Int {
  self.program_subscription_plan_count
}

///|
pub fn RuntimeInspectorSnapshot::last_subscription_plan_summary(
  self : RuntimeInspectorSnapshot,
) -> SubscriptionPlanSummary {
  self.last_subscription_plan_summary
}

///|
pub fn RuntimeInspectorSnapshot::active_subscription_count(
  self : RuntimeInspectorSnapshot,
) -> Int {
  self.active_subscription_count
}

///|
pub fn RuntimeInspectorSnapshot::started_subscription_count(
  self : RuntimeInspectorSnapshot,
) -> Int {
  self.started_subscription_count
}

///|
pub fn RuntimeInspectorSnapshot::reused_subscription_count(
  self : RuntimeInspectorSnapshot,
) -> Int {
  self.reused_subscription_count
}

///|
pub fn RuntimeInspectorSnapshot::cancelled_subscription_count(
  self : RuntimeInspectorSnapshot,
) -> Int {
  self.cancelled_subscription_count
}

///|
pub fn RuntimeInspectorSnapshot::duplicate_subscription_key_count(
  self : RuntimeInspectorSnapshot,
) -> Int {
  self.duplicate_subscription_key_count
}

///|
pub fn RuntimeInspectorSnapshot::duplicate_subscription_keys(
  self : RuntimeInspectorSnapshot,
) -> Array[String] {
  self.duplicate_subscription_keys
}

///|
pub fn RuntimeInspectorSnapshot::ignored_subscription_dispatch_count(
  self : RuntimeInspectorSnapshot,
) -> Int {
  self.ignored_subscription_dispatch_count
}

///|
pub fn RuntimeInspectorSnapshot::active_subscriptions(
  self : RuntimeInspectorSnapshot,
) -> Array[@core.SubscriptionDescriptor] {
  self.active_subscriptions
}

///|
pub fn RuntimeInspectorSnapshot::active_subscription_kind_counts(
  self : RuntimeInspectorSnapshot,
) -> Array[SubscriptionKindCount] {
  self.active_subscription_kind_counts
}

///|
pub fn RuntimeInspectorSnapshot::subscription_lifecycle(
  self : RuntimeInspectorSnapshot,
) -> Array[SubscriptionLifecycleSnapshot] {
  self.subscription_lifecycle
}

///|
pub fn RuntimeInspectorSnapshot::rebuild_reason(
  self : RuntimeInspectorSnapshot,
) -> String {
  self.rebuild_reason
}

///|
pub fn RuntimeInspectorSnapshot::dirty_reasons(
  self : RuntimeInspectorSnapshot,
) -> Array[String] {
  self.dirty_reasons
}

///|
pub fn RuntimeDirtyStateSummary::dirty_count(
  self : RuntimeDirtyStateSummary,
) -> Int {
  self.dirty_count
}

///|
pub fn RuntimeDirtyStateSummary::dirty_element_ids(
  self : RuntimeDirtyStateSummary,
) -> Array[@core.ElementId] {
  self.dirty_element_ids
}

///|
pub fn RuntimeDirtyStateSummary::dirty_build_count(
  self : RuntimeDirtyStateSummary,
) -> Int {
  self.dirty_build_count
}

///|
pub fn RuntimeDirtyStateSummary::dirty_build_element_ids(
  self : RuntimeDirtyStateSummary,
) -> Array[@core.ElementId] {
  self.dirty_build_element_ids
}

///|
pub fn RuntimeDirtyStateSummary::dirty_layout_count(
  self : RuntimeDirtyStateSummary,
) -> Int {
  self.dirty_layout_count
}

///|
pub fn RuntimeDirtyStateSummary::dirty_layout_element_ids(
  self : RuntimeDirtyStateSummary,
) -> Array[@core.ElementId] {
  self.dirty_layout_element_ids
}

///|
pub fn RuntimeDirtyStateSummary::dirty_paint_count(
  self : RuntimeDirtyStateSummary,
) -> Int {
  self.dirty_paint_count
}

///|
pub fn RuntimeDirtyStateSummary::dirty_paint_element_ids(
  self : RuntimeDirtyStateSummary,
) -> Array[@core.ElementId] {
  self.dirty_paint_element_ids
}

///|
pub fn RuntimeDirtyStateSummary::needs_rebuild(
  self : RuntimeDirtyStateSummary,
) -> Bool {
  self.needs_rebuild
}

///|
pub fn RuntimeDirtyStateSummary::needs_layout(
  self : RuntimeDirtyStateSummary,
) -> Bool {
  self.needs_layout
}

///|
pub fn RuntimeDirtyStateSummary::needs_paint(
  self : RuntimeDirtyStateSummary,
) -> Bool {
  self.needs_paint
}

///|
pub fn RuntimeDirtyStateSummary::needs_redraw(
  self : RuntimeDirtyStateSummary,
) -> Bool {
  self.needs_redraw
}

///|
pub fn RuntimeDirtyStateSummary::has_pending_work(
  self : RuntimeDirtyStateSummary,
) -> Bool {
  self.has_pending_work
}

///|
pub fn RuntimeDirtyStateSummary::reason(
  self : RuntimeDirtyStateSummary,
) -> String {
  self.reason
}

///|
pub fn RuntimeDirtyStateSummary::reasons(
  self : RuntimeDirtyStateSummary,
) -> Array[String] {
  self.reasons
}

///|
pub fn RuntimeDirtyStateSummary::damage_kind(
  self : RuntimeDirtyStateSummary,
) -> String {
  self.damage_kind
}

///|
pub fn RuntimeDirtyStateSummary::damage_rect_count(
  self : RuntimeDirtyStateSummary,
) -> Int {
  self.damage_rect_count
}

///|
pub fn RuntimeDirtyStateSummary::damage_full_reason(
  self : RuntimeDirtyStateSummary,
) -> String {
  self.damage_full_reason
}

///|
pub fn RuntimeDirtyStateSummary::cache_epoch(
  self : RuntimeDirtyStateSummary,
) -> Int {
  self.cache_epoch
}

///|
pub fn RuntimeDirtyStateSummary::cached_layer_count(
  self : RuntimeDirtyStateSummary,
) -> Int {
  self.cached_layer_count
}

///|
pub fn ViewInspectorSummary::element_id(
  self : ViewInspectorSummary,
) -> @core.ElementId {
  self.element_id
}

///|
pub fn ViewInspectorSummary::kind(self : ViewInspectorSummary) -> String {
  self.kind
}

///|
pub fn ViewInspectorSummary::key(self : ViewInspectorSummary) -> String {
  self.key
}

///|
pub fn ViewInspectorSummary::child_count(self : ViewInspectorSummary) -> Int {
  self.child_count
}

///|
pub fn ViewInspectorSummary::needs_build(self : ViewInspectorSummary) -> Bool {
  self.needs_build
}

///|
pub fn ViewInspectorSummary::needs_layout(self : ViewInspectorSummary) -> Bool {
  self.needs_layout
}

///|
pub fn ViewInspectorSummary::needs_paint(self : ViewInspectorSummary) -> Bool {
  self.needs_paint
}

///|
pub fn ViewTreeInspectorSnapshot::root_kind(
  self : ViewTreeInspectorSnapshot,
) -> String {
  self.root_kind
}

///|
pub fn ViewTreeInspectorSnapshot::node_count(
  self : ViewTreeInspectorSnapshot,
) -> Int {
  self.node_count
}

///|
pub fn ViewTreeInspectorSnapshot::component_count(
  self : ViewTreeInspectorSnapshot,
) -> Int {
  self.component_count
}

///|
pub fn ViewTreeInspectorSnapshot::control_count(
  self : ViewTreeInspectorSnapshot,
) -> Int {
  self.control_count
}

///|
pub fn ViewTreeInspectorSnapshot::modified_count(
  self : ViewTreeInspectorSnapshot,
) -> Int {
  self.modified_count
}

///|
pub fn ViewTreeInspectorSnapshot::dirty_build_count(
  self : ViewTreeInspectorSnapshot,
) -> Int {
  self.dirty_build_count
}

///|
pub fn ViewTreeInspectorSnapshot::dirty_layout_count(
  self : ViewTreeInspectorSnapshot,
) -> Int {
  self.dirty_layout_count
}

///|
pub fn ViewTreeInspectorSnapshot::dirty_paint_count(
  self : ViewTreeInspectorSnapshot,
) -> Int {
  self.dirty_paint_count
}

///|
pub fn ViewTreeInspectorSnapshot::nodes(
  self : ViewTreeInspectorSnapshot,
) -> Array[ViewInspectorSummary] {
  self.nodes
}

///|
pub fn LayoutBoundsInspectorEntry::element_id(
  self : LayoutBoundsInspectorEntry,
) -> @core.ElementId {
  self.element_id
}

///|
pub fn LayoutBoundsInspectorEntry::frame(
  self : LayoutBoundsInspectorEntry,
) -> @core.Rect {
  self.frame
}

///|
pub fn LayoutBoundsInspectorEntry::depth(
  self : LayoutBoundsInspectorEntry,
) -> Int {
  self.depth
}

///|
pub fn LayoutBoundsInspectorEntry::child_count(
  self : LayoutBoundsInspectorEntry,
) -> Int {
  self.child_count
}

///|
pub fn LayoutInspectorSnapshot::root_frame(
  self : LayoutInspectorSnapshot,
) -> @core.Rect {
  self.root_frame
}

///|
pub fn LayoutInspectorSnapshot::node_count(
  self : LayoutInspectorSnapshot,
) -> Int {
  self.node_count
}

///|
pub fn LayoutInspectorSnapshot::leaf_count(
  self : LayoutInspectorSnapshot,
) -> Int {
  self.leaf_count
}

///|
pub fn LayoutInspectorSnapshot::max_depth(
  self : LayoutInspectorSnapshot,
) -> Int {
  self.max_depth
}

///|
pub fn LayoutInspectorSnapshot::bounds(
  self : LayoutInspectorSnapshot,
) -> Array[LayoutBoundsInspectorEntry] {
  self.bounds
}

///|
pub fn RenderInspectorSnapshot::command_count(
  self : RenderInspectorSnapshot,
) -> Int {
  self.command_count
}

///|
pub fn RenderInspectorSnapshot::text_count(
  self : RenderInspectorSnapshot,
) -> Int {
  self.text_count
}

///|
pub fn RenderInspectorSnapshot::image_count(
  self : RenderInspectorSnapshot,
) -> Int {
  self.image_count
}

///|
pub fn RenderInspectorSnapshot::clip_depth(
  self : RenderInspectorSnapshot,
) -> Int {
  self.clip_depth
}

///|
pub fn RenderInspectorSnapshot::open_clip_depth(
  self : RenderInspectorSnapshot,
) -> Int {
  self.open_clip_depth
}

///|
pub fn RenderInspectorSnapshot::layer_depth(
  self : RenderInspectorSnapshot,
) -> Int {
  self.layer_depth
}

///|
pub fn RenderInspectorSnapshot::open_layer_depth(
  self : RenderInspectorSnapshot,
) -> Int {
  self.open_layer_depth
}

///|
pub fn RenderInspectorSnapshot::filter_depth(
  self : RenderInspectorSnapshot,
) -> Int {
  self.filter_depth
}

///|
pub fn RenderInspectorSnapshot::open_filter_depth(
  self : RenderInspectorSnapshot,
) -> Int {
  self.open_filter_depth
}

///|
pub fn RenderInspectorSnapshot::path_count(
  self : RenderInspectorSnapshot,
) -> Int {
  self.path_count
}

///|
pub fn RenderInspectorSnapshot::shader_count(
  self : RenderInspectorSnapshot,
) -> Int {
  self.shader_count
}

///|
pub fn RenderInspectorSnapshot::unbalanced_pop_count(
  self : RenderInspectorSnapshot,
) -> Int {
  self.unbalanced_pop_count
}

///|
pub fn SemanticsInspectorSnapshot::root_role(
  self : SemanticsInspectorSnapshot,
) -> @core.SemanticsRole {
  self.root_role
}

///|
pub fn SemanticsInspectorSnapshot::node_count(
  self : SemanticsInspectorSnapshot,
) -> Int {
  self.node_count
}

///|
pub fn SemanticsInspectorSnapshot::focusable_count(
  self : SemanticsInspectorSnapshot,
) -> Int {
  self.focusable_count
}

///|
pub fn SemanticsInspectorSnapshot::action_count(
  self : SemanticsInspectorSnapshot,
) -> Int {
  self.action_count
}

///|
pub fn SemanticsInspectorSnapshot::max_depth(
  self : SemanticsInspectorSnapshot,
) -> Int {
  self.max_depth
}

///|
pub fn SemanticsInspectorSnapshot::selected_count(
  self : SemanticsInspectorSnapshot,
) -> Int {
  self.selected_count
}

///|
pub fn SemanticsInspectorSnapshot::checked_count(
  self : SemanticsInspectorSnapshot,
) -> Int {
  self.checked_count
}

///|
pub fn SemanticsInspectorSnapshot::expanded_count(
  self : SemanticsInspectorSnapshot,
) -> Int {
  self.expanded_count
}

///|
pub fn SemanticsInspectorSnapshot::invalid_count(
  self : SemanticsInspectorSnapshot,
) -> Int {
  self.invalid_count
}

///|
pub fn SemanticsInspectorSnapshot::required_count(
  self : SemanticsInspectorSnapshot,
) -> Int {
  self.required_count
}

///|
pub fn SemanticsInspectorSnapshot::described_count(
  self : SemanticsInspectorSnapshot,
) -> Int {
  self.described_count
}

///|
pub fn InspectorSnapshot::runtime(
  self : InspectorSnapshot,
) -> RuntimeInspectorSnapshot {
  self.runtime
}

///|
pub fn InspectorSnapshot::view_tree(
  self : InspectorSnapshot,
) -> ViewTreeInspectorSnapshot {
  self.view_tree
}

///|
pub fn InspectorSnapshot::layout(
  self : InspectorSnapshot,
) -> LayoutInspectorSnapshot {
  self.layout
}

///|
pub fn InspectorSnapshot::render(
  self : InspectorSnapshot,
) -> RenderInspectorSnapshot {
  self.render
}

///|
pub fn InspectorSnapshot::semantics(
  self : InspectorSnapshot,
) -> SemanticsInspectorSnapshot {
  self.semantics
}

///|
pub fn RenderInspectorSnapshot::from_commands(
  commands : Array[@core.DrawCommand],
) -> RenderInspectorSnapshot {
  render_inspector_from_commands(commands)
}
