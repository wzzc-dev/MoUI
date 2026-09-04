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
) -> Array[Int] {
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
) -> Array[Int] {
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
) -> Array[Int] {
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
) -> Array[Int] {
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
pub fn RuntimeInspectorSnapshot::layout_cache_hit_count(
  self : RuntimeInspectorSnapshot,
) -> Int {
  self.layout_cache_hit_count
}

///|
pub fn RuntimeInspectorSnapshot::layout_cache_miss_count(
  self : RuntimeInspectorSnapshot,
) -> Int {
  self.layout_cache_miss_count
}

///|
pub fn RuntimeInspectorSnapshot::render_cache_hit_count(
  self : RuntimeInspectorSnapshot,
) -> Int {
  self.render_cache_hit_count
}

///|
pub fn RuntimeInspectorSnapshot::render_cache_miss_count(
  self : RuntimeInspectorSnapshot,
) -> Int {
  self.render_cache_miss_count
}

///|
pub fn RuntimeInspectorSnapshot::last_event_hit_path(
  self : RuntimeInspectorSnapshot,
) -> Array[Int] {
  self.last_event_hit_path.copy()
}

///|
pub fn RuntimeInspectorSnapshot::last_frame_timing(
  self : RuntimeInspectorSnapshot,
) -> RuntimeFrameTiming {
  self.last_frame_timing
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
pub fn RuntimeInspectorSnapshot::superseded_effect_task_key_count(
  self : RuntimeInspectorSnapshot,
) -> Int {
  self.superseded_effect_task_key_count
}

///|
pub fn RuntimeInspectorSnapshot::superseded_effect_task_keys(
  self : RuntimeInspectorSnapshot,
) -> Array[String] {
  self.superseded_effect_task_keys
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
) -> Array[Int] {
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
) -> Array[Int] {
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
) -> Array[Int] {
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
) -> Array[Int] {
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
pub fn ViewInspectorSummary::element_id(self : ViewInspectorSummary) -> Int {
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
pub fn ViewInspectorSummary::depth(self : ViewInspectorSummary) -> Int {
  self.depth
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
) -> Int {
  self.element_id
}

///|
pub fn LayoutBoundsInspectorEntry::frame(
  self : LayoutBoundsInspectorEntry,
) -> @core.Rect {
  self.frame
}

///|
pub fn LayoutBoundsInspectorEntry::constraints(
  self : LayoutBoundsInspectorEntry,
) -> @core.Constraints {
  self.constraints
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
pub fn RenderInspectorEntry::element_id(self : RenderInspectorEntry) -> Int {
  self.element_id
}

///|
pub fn RenderInspectorEntry::frame(self : RenderInspectorEntry) -> @core.Rect {
  self.frame
}

///|
pub fn RenderInspectorEntry::paint_bounds(
  self : RenderInspectorEntry,
) -> @core.Rect {
  self.paint_bounds
}

///|
pub fn RenderInspectorEntry::depth(self : RenderInspectorEntry) -> Int {
  self.depth
}

///|
pub fn RenderInspectorEntry::child_count(self : RenderInspectorEntry) -> Int {
  self.child_count
}

///|
pub fn RenderInspectorEntry::command_count(self : RenderInspectorEntry) -> Int {
  self.command_count
}

///|
pub fn RenderInspectorEntry::overlay_command_count(
  self : RenderInspectorEntry,
) -> Int {
  self.overlay_command_count
}

///|
pub fn RenderInspectorEntry::repaint_boundary(
  self : RenderInspectorEntry,
) -> Bool {
  self.repaint_boundary
}

///|
pub fn RenderInspectorEntry::cache_key(self : RenderInspectorEntry) -> String {
  self.cache_key
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
pub fn RenderInspectorSnapshot::nodes(
  self : RenderInspectorSnapshot,
) -> Array[RenderInspectorEntry] {
  self.nodes.copy()
}

///|
pub fn SemanticsInspectorEntry::node_id(
  self : SemanticsInspectorEntry,
) -> String {
  self.node_id
}

///|
pub fn SemanticsInspectorEntry::role(
  self : SemanticsInspectorEntry,
) -> @core.SemanticsRole {
  self.role
}

///|
pub fn SemanticsInspectorEntry::label(self : SemanticsInspectorEntry) -> String {
  self.label
}

///|
pub fn SemanticsInspectorEntry::value(self : SemanticsInspectorEntry) -> String {
  self.value
}

///|
pub fn SemanticsInspectorEntry::frame(
  self : SemanticsInspectorEntry,
) -> @core.Rect {
  self.frame
}

///|
pub fn SemanticsInspectorEntry::depth(self : SemanticsInspectorEntry) -> Int {
  self.depth
}

///|
pub fn SemanticsInspectorEntry::child_count(
  self : SemanticsInspectorEntry,
) -> Int {
  self.child_count
}

///|
pub fn SemanticsInspectorEntry::action_count(
  self : SemanticsInspectorEntry,
) -> Int {
  self.action_count
}

///|
pub fn SemanticsInspectorEntry::focusable(
  self : SemanticsInspectorEntry,
) -> Bool {
  self.focusable
}

///|
pub fn SemanticsInspectorEntry::selected(
  self : SemanticsInspectorEntry,
) -> Bool {
  self.selected
}

///|
pub fn SemanticsInspectorEntry::checked(self : SemanticsInspectorEntry) -> Bool {
  self.checked
}

///|
pub fn SemanticsInspectorEntry::expanded(
  self : SemanticsInspectorEntry,
) -> Bool {
  self.expanded
}

///|
pub fn SemanticsInspectorEntry::disabled(
  self : SemanticsInspectorEntry,
) -> Bool {
  self.disabled
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
pub fn SemanticsInspectorSnapshot::nodes(
  self : SemanticsInspectorSnapshot,
) -> Array[SemanticsInspectorEntry] {
  self.nodes.copy()
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
