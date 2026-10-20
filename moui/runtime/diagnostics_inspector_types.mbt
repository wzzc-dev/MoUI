///|
pub struct RuntimeInspectorSnapshot {
  priv size : @core.Size
  priv dirty_count : Int32
  priv dirty_element_ids : Array[Int32]
  priv dirty_build_count : Int32
  priv dirty_build_element_ids : Array[Int32]
  priv dirty_layout_count : Int32
  priv dirty_layout_element_ids : Array[Int32]
  priv dirty_paint_count : Int32
  priv dirty_paint_element_ids : Array[Int32]
  priv dirty_state : RuntimeDirtyStateSummary
  priv needs_rebuild : Bool
  priv needs_layout : Bool
  priv needs_paint : Bool
  priv needs_redraw : Bool
  priv draw_command_count : Int32
  priv rebuild_pass_count : Int32
  priv layout_pass_count : Int32
  priv paint_pass_count : Int32
  priv draw_command_build_count : Int32
  priv layout_cache_hit_count : Int32
  priv layout_cache_miss_count : Int32
  priv render_cache_hit_count : Int32
  priv render_cache_miss_count : Int32
  priv last_event_hit_path : Array[Int32]
  priv last_frame_timing : RuntimeFrameTiming
  priv program_dispatched_count : Int32
  priv program_update_count : Int32
  priv ignored_program_dispatch_count : Int32
  priv program_message_enqueue_count : Int32
  priv program_message_drain_count : Int32
  priv program_pending_message_count : Int32
  priv program_max_pending_message_count : Int32
  priv program_effect_plan_count : Int32
  priv program_effect_count : Int32
  priv program_effect_none_count : Int32
  priv program_effect_batch_count : Int32
  priv program_effect_send_count : Int32
  priv program_effect_dispatch_count : Int32
  priv program_effect_run_count : Int32
  priv program_effect_task_count : Int32
  priv duplicate_effect_descriptor_key_count : Int32
  priv duplicate_effect_descriptor_keys : Array[String]
  priv superseded_effect_task_key_count : Int32
  priv superseded_effect_task_keys : Array[String]
  priv last_effect_summary : EffectPlanSummary
  priv last_scheduled_effect_summary : EffectPlanSummary
  priv active_effect_task_count : Int32
  priv started_effect_task_count : Int32
  priv completed_effect_task_count : Int32
  priv cancelled_effect_task_count : Int32
  priv ignored_effect_task_dispatch_count : Int32
  priv active_effect_tasks : Array[@core.EffectDescriptor]
  priv effect_task_lifecycle : Array[EffectTaskLifecycleSnapshot]
  priv program_subscription_plan_count : Int32
  priv last_subscription_plan_summary : SubscriptionPlanSummary
  priv active_subscription_count : Int32
  priv started_subscription_count : Int32
  priv reused_subscription_count : Int32
  priv cancelled_subscription_count : Int32
  priv duplicate_subscription_key_count : Int32
  priv duplicate_subscription_keys : Array[String]
  priv ignored_subscription_dispatch_count : Int32
  priv active_subscriptions : Array[@core.SubscriptionDescriptor]
  priv active_subscription_kind_counts : Array[SubscriptionKindCount]
  priv subscription_lifecycle : Array[SubscriptionLifecycleSnapshot]
  priv rebuild_reason : String
  priv dirty_reasons : Array[String]
} derive(Eq, Debug, ToJson)

///|
pub extend RuntimeInspectorSnapshot with Debug::{to_repr}

///|
pub extend RuntimeInspectorSnapshot with Eq::{not_equal, equal}

///|
pub extend RuntimeInspectorSnapshot with ToJson::{to_json}

///|
pub struct RuntimeDirtyStateSummary {
  priv dirty_count : Int32
  priv dirty_element_ids : Array[Int32]
  priv dirty_build_count : Int32
  priv dirty_build_element_ids : Array[Int32]
  priv dirty_layout_count : Int32
  priv dirty_layout_element_ids : Array[Int32]
  priv dirty_paint_count : Int32
  priv dirty_paint_element_ids : Array[Int32]
  priv needs_rebuild : Bool
  priv needs_layout : Bool
  priv needs_paint : Bool
  priv needs_redraw : Bool
  priv has_pending_work : Bool
  priv reason : String
  priv reasons : Array[String]
  priv damage_kind : String
  priv damage_rect_count : Int32
  priv damage_full_reason : String
} derive(Eq, Debug, ToJson)

///|
pub extend RuntimeDirtyStateSummary with Debug::{to_repr}

///|
pub extend RuntimeDirtyStateSummary with Eq::{not_equal, equal}

///|
pub extend RuntimeDirtyStateSummary with ToJson::{to_json}

///|
pub struct ViewInspectorSummary {
  priv element_id : Int32
  priv kind : String
  priv key : String
  priv depth : Int32
  priv child_count : Int32
  priv needs_build : Bool
  priv needs_layout : Bool
  priv needs_paint : Bool
} derive(Eq, Debug, ToJson)

///|
pub extend ViewInspectorSummary with Debug::{to_repr}

///|
pub extend ViewInspectorSummary with Eq::{not_equal, equal}

///|
pub extend ViewInspectorSummary with ToJson::{to_json}

///|
pub struct ViewTreeInspectorSnapshot {
  priv root_kind : String
  priv node_count : Int32
  priv control_count : Int32
  priv modified_count : Int32
  priv dirty_build_count : Int32
  priv dirty_layout_count : Int32
  priv dirty_paint_count : Int32
  priv nodes : Array[ViewInspectorSummary]
} derive(Eq, Debug, ToJson)

///|
pub extend ViewTreeInspectorSnapshot with Debug::{to_repr}

///|
pub extend ViewTreeInspectorSnapshot with Eq::{not_equal, equal}

///|
pub extend ViewTreeInspectorSnapshot with ToJson::{to_json}

///|
pub struct LayoutBoundsInspectorEntry {
  priv element_id : Int32
  priv frame : @core.Rect
  priv constraints : @core.Constraints
  priv depth : Int32
  priv child_count : Int32
} derive(Eq, Debug, ToJson)

///|
pub extend LayoutBoundsInspectorEntry with Debug::{to_repr}

///|
pub extend LayoutBoundsInspectorEntry with Eq::{not_equal, equal}

///|
pub extend LayoutBoundsInspectorEntry with ToJson::{to_json}

///|
pub struct LayoutInspectorSnapshot {
  priv root_frame : @core.Rect
  priv node_count : Int32
  priv leaf_count : Int32
  priv max_depth : Int32
  priv bounds : Array[LayoutBoundsInspectorEntry]
} derive(Eq, Debug, ToJson)

///|
pub extend LayoutInspectorSnapshot with Debug::{to_repr}

///|
pub extend LayoutInspectorSnapshot with Eq::{not_equal, equal}

///|
pub extend LayoutInspectorSnapshot with ToJson::{to_json}

///|
pub struct RenderInspectorEntry {
  priv element_id : Int32
  priv frame : @core.Rect
  priv paint_bounds : @core.Rect
  priv depth : Int32
  priv child_count : Int32
  priv command_count : Int32
  priv overlay_command_count : Int32
  priv repaint_boundary : Bool
  priv cache_key : String
} derive(Eq, Debug, ToJson)

///|
pub extend RenderInspectorEntry with Debug::{to_repr}

///|
pub extend RenderInspectorEntry with Eq::{not_equal, equal}

///|
pub extend RenderInspectorEntry with ToJson::{to_json}

///|
pub struct RenderInspectorSnapshot {
  priv command_count : Int32
  priv text_count : Int32
  priv image_count : Int32
  priv clip_depth : Int32
  priv open_clip_depth : Int32
  priv layer_depth : Int32
  priv open_layer_depth : Int32
  priv filter_depth : Int32
  priv open_filter_depth : Int32
  priv path_count : Int32
  priv shader_count : Int32
  priv unbalanced_pop_count : Int32
  priv nodes : Array[RenderInspectorEntry]
} derive(Eq, Debug, ToJson)

///|
pub extend RenderInspectorSnapshot with Debug::{to_repr}

///|
pub extend RenderInspectorSnapshot with Eq::{not_equal, equal}

///|
pub extend RenderInspectorSnapshot with ToJson::{to_json}

///|
pub struct SemanticsInspectorEntry {
  priv node_id : String
  priv role : @core.SemanticsRole
  priv label : String
  priv value : String
  priv frame : @core.Rect
  priv depth : Int32
  priv child_count : Int32
  priv action_count : Int32
  priv focusable : Bool
  priv selected : Bool
  priv checked : Bool
  priv expanded : Bool
  priv disabled : Bool
} derive(Eq, Debug, ToJson)

///|
pub extend SemanticsInspectorEntry with Debug::{to_repr}

///|
pub extend SemanticsInspectorEntry with Eq::{not_equal, equal}

///|
pub extend SemanticsInspectorEntry with ToJson::{to_json}

///|
pub struct SemanticsInspectorSnapshot {
  priv root_role : @core.SemanticsRole
  priv node_count : Int32
  priv focusable_count : Int32
  priv action_count : Int32
  priv max_depth : Int32
  priv selected_count : Int32
  priv checked_count : Int32
  priv expanded_count : Int32
  priv invalid_count : Int32
  priv required_count : Int32
  priv described_count : Int32
  priv nodes : Array[SemanticsInspectorEntry]
} derive(Eq, Debug, ToJson)

///|
pub extend SemanticsInspectorSnapshot with Debug::{to_repr}

///|
pub extend SemanticsInspectorSnapshot with Eq::{not_equal, equal}

///|
pub extend SemanticsInspectorSnapshot with ToJson::{to_json}

///|
pub struct InspectorSnapshot {
  priv runtime : RuntimeInspectorSnapshot
  priv view_tree : ViewTreeInspectorSnapshot
  priv layout : LayoutInspectorSnapshot
  priv render : RenderInspectorSnapshot
  priv semantics : SemanticsInspectorSnapshot
} derive(Eq, Debug, ToJson)

///|
pub extend InspectorSnapshot with Debug::{to_repr}

///|
pub extend InspectorSnapshot with Eq::{not_equal, equal}

///|
pub extend InspectorSnapshot with ToJson::{to_json}
