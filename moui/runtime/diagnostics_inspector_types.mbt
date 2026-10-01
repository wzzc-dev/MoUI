///|
pub struct RuntimeInspectorSnapshot {
  priv size : @core.Size
  priv dirty_count : Int
  priv dirty_element_ids : Array[Int]
  priv dirty_build_count : Int
  priv dirty_build_element_ids : Array[Int]
  priv dirty_layout_count : Int
  priv dirty_layout_element_ids : Array[Int]
  priv dirty_paint_count : Int
  priv dirty_paint_element_ids : Array[Int]
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
  priv layout_cache_hit_count : Int
  priv layout_cache_miss_count : Int
  priv render_cache_hit_count : Int
  priv render_cache_miss_count : Int
  priv last_event_hit_path : Array[Int]
  priv last_frame_timing : RuntimeFrameTiming
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
pub extend RuntimeInspectorSnapshot with Debug::{to_repr}

///|
pub extend RuntimeInspectorSnapshot with Eq::{not_equal, equal}

///|
pub extend RuntimeInspectorSnapshot with ToJson::{to_json}

///|
pub struct RuntimeDirtyStateSummary {
  priv dirty_count : Int
  priv dirty_element_ids : Array[Int]
  priv dirty_build_count : Int
  priv dirty_build_element_ids : Array[Int]
  priv dirty_layout_count : Int
  priv dirty_layout_element_ids : Array[Int]
  priv dirty_paint_count : Int
  priv dirty_paint_element_ids : Array[Int]
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
} derive(Eq, Debug, ToJson)

///|
pub extend RuntimeDirtyStateSummary with Debug::{to_repr}

///|
pub extend RuntimeDirtyStateSummary with Eq::{not_equal, equal}

///|
pub extend RuntimeDirtyStateSummary with ToJson::{to_json}

///|
pub struct ViewInspectorSummary {
  priv element_id : Int
  priv kind : String
  priv key : String
  priv depth : Int
  priv child_count : Int
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
  priv node_count : Int
  priv control_count : Int
  priv modified_count : Int
  priv dirty_build_count : Int
  priv dirty_layout_count : Int
  priv dirty_paint_count : Int
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
  priv element_id : Int
  priv frame : @core.Rect
  priv constraints : @core.Constraints
  priv depth : Int
  priv child_count : Int
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
  priv node_count : Int
  priv leaf_count : Int
  priv max_depth : Int
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
  priv element_id : Int
  priv frame : @core.Rect
  priv paint_bounds : @core.Rect
  priv depth : Int
  priv child_count : Int
  priv command_count : Int
  priv overlay_command_count : Int
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
  priv depth : Int
  priv child_count : Int
  priv action_count : Int
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
