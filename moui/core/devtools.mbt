///|
pub(all) struct RuntimeInspectorSnapshot {
  size : Size
  dirty_count : Int
  dirty_element_ids : Array[ElementId]
  dirty_build_count : Int
  dirty_build_element_ids : Array[ElementId]
  dirty_layout_count : Int
  dirty_layout_element_ids : Array[ElementId]
  dirty_paint_count : Int
  dirty_paint_element_ids : Array[ElementId]
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
  active_effect_tasks : Array[EffectDescriptor]
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
  active_subscriptions : Array[SubscriptionDescriptor]
  active_subscription_kind_counts : Array[SubscriptionKindCount]
  subscription_lifecycle : Array[SubscriptionLifecycleSnapshot]
  rebuild_reason : String
  dirty_reasons : Array[String]
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RuntimeDirtyStateSummary {
  dirty_count : Int
  dirty_element_ids : Array[ElementId]
  dirty_build_count : Int
  dirty_build_element_ids : Array[ElementId]
  dirty_layout_count : Int
  dirty_layout_element_ids : Array[ElementId]
  dirty_paint_count : Int
  dirty_paint_element_ids : Array[ElementId]
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
pub(all) struct ViewNodeInspectorSummary {
  element_id : ElementId
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
  nodes : Array[ViewNodeInspectorSummary]
} derive(Eq, Debug, ToJson)

///|
pub(all) struct LayoutBoundsInspectorEntry {
  element_id : ElementId
  frame : Rect
  depth : Int
  child_count : Int
} derive(Eq, Debug, ToJson)

///|
pub(all) struct LayoutInspectorSnapshot {
  root_frame : Rect
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
  root_role : SemanticsRole
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
  commands : Array[DrawCommand],
) -> RenderInspectorSnapshot {
  render_inspector_from_commands(commands)
}

///|
fn render_inspector_from_commands(
  commands : Array[DrawCommand],
) -> RenderInspectorSnapshot {
  let mut text_count = 0
  let mut image_count = 0
  let mut clip_depth = 0
  let mut max_clip_depth = 0
  let mut layer_depth = 0
  let mut max_layer_depth = 0
  let mut filter_depth = 0
  let mut max_filter_depth = 0
  let mut path_count = 0
  let mut shader_count = 0
  let mut unbalanced_pop_count = 0
  for command in commands {
    match command {
      DrawText(_) => text_count = text_count + 1
      DrawImage(_) => image_count = image_count + 1
      PushClip(_) | PushRoundedClip(_) => {
        clip_depth = clip_depth + 1
        max_clip_depth = devtools_max_int(max_clip_depth, clip_depth)
      }
      PopClip | PopRoundedClip =>
        if clip_depth == 0 {
          unbalanced_pop_count = unbalanced_pop_count + 1
        } else {
          clip_depth = clip_depth - 1
        }
      PushLayer(_) | BeginCachedLayer(_) => {
        layer_depth = layer_depth + 1
        max_layer_depth = devtools_max_int(max_layer_depth, layer_depth)
      }
      PopLayer | EndCachedLayer(_) =>
        if layer_depth == 0 {
          unbalanced_pop_count = unbalanced_pop_count + 1
        } else {
          layer_depth = layer_depth - 1
        }
      DrawCachedLayer(_) => ()
      PushFilter(_) => {
        filter_depth = filter_depth + 1
        max_filter_depth = devtools_max_int(max_filter_depth, filter_depth)
      }
      PopFilter =>
        if filter_depth == 0 {
          unbalanced_pop_count = unbalanced_pop_count + 1
        } else {
          filter_depth = filter_depth - 1
        }
      DrawPath(_) => path_count = path_count + 1
      DrawShaderEffect(_) => shader_count = shader_count + 1
      _ => ()
    }
  }
  RenderInspectorSnapshot::{
    command_count: commands.length(),
    text_count,
    image_count,
    clip_depth: max_clip_depth,
    open_clip_depth: clip_depth,
    layer_depth: max_layer_depth,
    open_layer_depth: layer_depth,
    filter_depth: max_filter_depth,
    open_filter_depth: filter_depth,
    path_count,
    shader_count,
    unbalanced_pop_count,
  }
}

///|
fn devtools_max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}
