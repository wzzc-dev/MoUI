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
pub(all) struct FrameProfile {
  frame : Frame
  dirty_count : Int
  draw_command_count : Int
  active_animations : Int
} derive(Eq, Debug, ToJson)

///|
pub fn InspectorSnapshot::from_runtime(
  runtime : AppRuntime,
) -> InspectorSnapshot {
  let view_tree = ViewTreeInspectorSnapshot::from_runtime(runtime)
  {
    runtime: RuntimeInspectorSnapshot::from_runtime(runtime),
    view_tree,
    layout: LayoutInspectorSnapshot::from_runtime(runtime),
    render: RenderInspectorSnapshot::from_runtime(runtime),
    semantics: SemanticsInspectorSnapshot::from_runtime(runtime),
  }
}

///|
pub fn RuntimeInspectorSnapshot::from_runtime(
  runtime : AppRuntime,
) -> RuntimeInspectorSnapshot {
  let dirty_count = runtime.dirty_count()
  let dirty_element_ids = runtime.dirty_element_ids()
  let dirty_build_element_ids = runtime.state.dirty_build_elements.copy()
  let dirty_layout_element_ids = runtime.state.dirty_layout_elements.copy()
  let dirty_paint_element_ids = runtime.state.dirty_paint_elements.copy()
  let dirty_build_count = dirty_build_element_ids.length()
  let dirty_layout_count = dirty_layout_element_ids.length()
  let dirty_paint_count = dirty_paint_element_ids.length()
  let needs_rebuild = runtime.needs_rebuild()
  let needs_layout = runtime.needs_layout()
  let needs_paint = runtime.needs_paint()
  let needs_redraw = runtime.needs_redraw()
  let rebuild_reason = runtime.inspector_rebuild_reason()
  let dirty_reasons = runtime.inspector_dirty_reasons()
  let dirty_state = RuntimeDirtyStateSummary::{
    dirty_count,
    dirty_element_ids: dirty_element_ids.copy(),
    dirty_build_count,
    dirty_build_element_ids: dirty_build_element_ids.copy(),
    dirty_layout_count,
    dirty_layout_element_ids: dirty_layout_element_ids.copy(),
    dirty_paint_count,
    dirty_paint_element_ids: dirty_paint_element_ids.copy(),
    needs_rebuild,
    needs_layout,
    needs_paint,
    needs_redraw,
    has_pending_work: needs_rebuild ||
    needs_layout ||
    needs_paint ||
    needs_redraw ||
    dirty_count > 0,
    reason: rebuild_reason,
    reasons: dirty_reasons.copy(),
  }
  let program = runtime.program_runtime_snapshot()
  let draw_commands = runtime.state.cached_draw_commands()
  RuntimeInspectorSnapshot::{
    size: runtime.size(),
    dirty_count,
    dirty_element_ids,
    dirty_build_count,
    dirty_build_element_ids,
    dirty_layout_count,
    dirty_layout_element_ids,
    dirty_paint_count,
    dirty_paint_element_ids,
    dirty_state,
    needs_rebuild,
    needs_layout,
    needs_paint,
    needs_redraw,
    draw_command_count: draw_commands.length(),
    rebuild_pass_count: runtime.state.rebuild_pass_count,
    layout_pass_count: runtime.state.layout_pass_count,
    paint_pass_count: runtime.state.paint_pass_count,
    draw_command_build_count: runtime.state.draw_command_build_count,
    program_dispatched_count: program.dispatched_count,
    program_update_count: program.update_count,
    ignored_program_dispatch_count: program.ignored_program_dispatch_count,
    program_message_enqueue_count: program.message_enqueue_count,
    program_message_drain_count: program.message_drain_count,
    program_pending_message_count: program.pending_message_count,
    program_max_pending_message_count: program.max_pending_message_count,
    program_effect_plan_count: program.effect_plan_count,
    program_effect_count: program.effect_count,
    program_effect_none_count: program.effect_none_count,
    program_effect_batch_count: program.effect_batch_count,
    program_effect_send_count: program.effect_send_count,
    program_effect_dispatch_count: program.effect_dispatch_count,
    program_effect_run_count: program.effect_run_count,
    program_effect_task_count: program.effect_task_count,
    duplicate_effect_descriptor_key_count: program.duplicate_effect_descriptor_key_count,
    duplicate_effect_descriptor_keys: program.duplicate_effect_descriptor_keys,
    last_effect_summary: program.last_effect_summary,
    last_scheduled_effect_summary: program.last_scheduled_effect_summary,
    active_effect_task_count: program.active_effect_task_count,
    started_effect_task_count: program.started_effect_task_count,
    completed_effect_task_count: program.completed_effect_task_count,
    cancelled_effect_task_count: program.cancelled_effect_task_count,
    ignored_effect_task_dispatch_count: program.ignored_effect_task_dispatch_count,
    active_effect_tasks: program.active_effect_tasks,
    effect_task_lifecycle: program.effect_task_lifecycle,
    program_subscription_plan_count: program.subscription_plan_count,
    last_subscription_plan_summary: program.last_subscription_plan_summary,
    active_subscription_count: program.active_subscription_count,
    started_subscription_count: program.started_subscription_count,
    reused_subscription_count: program.reused_subscription_count,
    cancelled_subscription_count: program.cancelled_subscription_count,
    duplicate_subscription_key_count: program.duplicate_subscription_key_count,
    duplicate_subscription_keys: program.duplicate_subscription_keys,
    ignored_subscription_dispatch_count: program.ignored_subscription_dispatch_count,
    active_subscriptions: program.active_subscriptions,
    active_subscription_kind_counts: program.active_subscription_kind_counts,
    subscription_lifecycle: program.subscription_lifecycle,
    rebuild_reason,
    dirty_reasons,
  }
}

///|
pub fn ViewTreeInspectorSnapshot::from_runtime(
  runtime : AppRuntime,
) -> ViewTreeInspectorSnapshot {
  runtime.view_tree_inspector_snapshot()
}

///|
pub fn LayoutInspectorSnapshot::from_runtime(
  runtime : AppRuntime,
) -> LayoutInspectorSnapshot {
  let layout = runtime.state.cached_layout()
  {
    root_frame: layout.frame,
    node_count: layout_node_count(layout),
    leaf_count: layout_leaf_count(layout),
    max_depth: layout_max_depth(layout),
    bounds: layout_bounds_entries(
      runtime.state.cached_layout_tree_root(),
      depth=0,
    ),
  }
}

///|
pub fn RenderInspectorSnapshot::from_runtime(
  runtime : AppRuntime,
) -> RenderInspectorSnapshot {
  RenderInspectorSnapshot::from_commands(runtime.state.cached_draw_commands())
}

///|
pub fn RenderInspectorSnapshot::from_commands(
  commands : Array[DrawCommand],
) -> RenderInspectorSnapshot {
  render_inspector_from_commands(commands)
}

///|
pub fn SemanticsInspectorSnapshot::from_runtime(
  runtime : AppRuntime,
) -> SemanticsInspectorSnapshot {
  let semantics = runtime.state.cached_semantics()
  {
    root_role: semantics.role,
    node_count: semantics_node_count(semantics),
    focusable_count: semantics_focusable_count(semantics),
    action_count: semantics_action_count(semantics),
    max_depth: semantics_max_depth(semantics),
    selected_count: semantics_selected_count(semantics),
    checked_count: semantics_checked_count(semantics),
    expanded_count: semantics_expanded_count(semantics),
    invalid_count: semantics_invalid_count(semantics),
    required_count: semantics_required_count(semantics),
    described_count: semantics_described_count(semantics),
  }
}

///|
pub fn FrameProfile::capture(
  runtime : AppRuntime,
  frame : Frame,
) -> FrameProfile {
  runtime.dispatch_event(AppEvent::FrameTick(frame))
  {
    frame,
    dirty_count: runtime.dirty_count(),
    draw_command_count: runtime.draw_commands().length(),
    active_animations: runtime.animation_count(),
  }
}

///|
fn layout_node_count(node : LayoutResult) -> Int {
  let mut count = 1
  for child in node.children {
    count = count + layout_node_count(child)
  }
  count
}

///|
fn layout_leaf_count(node : LayoutResult) -> Int {
  if node.children.length() == 0 {
    1
  } else {
    let mut count = 0
    for child in node.children {
      count = count + layout_leaf_count(child)
    }
    count
  }
}

///|
fn layout_max_depth(node : LayoutResult) -> Int {
  let mut depth = 1
  for child in node.children {
    depth = devtools_max_int(depth, 1 + layout_max_depth(child))
  }
  depth
}

///|
fn layout_bounds_entries(
  node : PlacedNode,
  depth~ : Int,
) -> Array[LayoutBoundsInspectorEntry] {
  let entries : Array[LayoutBoundsInspectorEntry] = [
    {
      element_id: node.element_id,
      frame: node.frame,
      depth,
      child_count: node.children.length(),
    },
  ]
  for child in node.children {
    entries.append(layout_bounds_entries(child, depth=depth + 1))
  }
  entries
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
      PushLayer(_) => {
        layer_depth = layer_depth + 1
        max_layer_depth = devtools_max_int(max_layer_depth, layer_depth)
      }
      PopLayer =>
        if layer_depth == 0 {
          unbalanced_pop_count = unbalanced_pop_count + 1
        } else {
          layer_depth = layer_depth - 1
        }
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
  {
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
fn semantics_node_count(node : SemanticsNode) -> Int {
  let mut count = 1
  for child in node.children {
    count = count + semantics_node_count(child)
  }
  count
}

///|
fn semantics_focusable_count(node : SemanticsNode) -> Int {
  let mut count = if node.focus_order is Some(_) { 1 } else { 0 }
  for child in node.children {
    count = count + semantics_focusable_count(child)
  }
  count
}

///|
fn semantics_action_count(node : SemanticsNode) -> Int {
  let mut count = node.actions.length()
  for child in node.children {
    count = count + semantics_action_count(child)
  }
  count
}

///|
fn semantics_max_depth(node : SemanticsNode) -> Int {
  let mut depth = 1
  for child in node.children {
    depth = devtools_max_int(depth, 1 + semantics_max_depth(child))
  }
  depth
}

///|
fn semantics_selected_count(node : SemanticsNode) -> Int {
  let mut count = if node.state.selected { 1 } else { 0 }
  for child in node.children {
    count = count + semantics_selected_count(child)
  }
  count
}

///|
fn semantics_checked_count(node : SemanticsNode) -> Int {
  let mut count = if node.state.checked { 1 } else { 0 }
  for child in node.children {
    count = count + semantics_checked_count(child)
  }
  count
}

///|
fn semantics_expanded_count(node : SemanticsNode) -> Int {
  let mut count = if node.state.expanded { 1 } else { 0 }
  for child in node.children {
    count = count + semantics_expanded_count(child)
  }
  count
}

///|
fn semantics_invalid_count(node : SemanticsNode) -> Int {
  let mut count = if node.state.invalid { 1 } else { 0 }
  for child in node.children {
    count = count + semantics_invalid_count(child)
  }
  count
}

///|
fn semantics_required_count(node : SemanticsNode) -> Int {
  let mut count = if node.state.required { 1 } else { 0 }
  for child in node.children {
    count = count + semantics_required_count(child)
  }
  count
}

///|
fn semantics_described_count(node : SemanticsNode) -> Int {
  let mut count = if node.description != "" { 1 } else { 0 }
  for child in node.children {
    count = count + semantics_described_count(child)
  }
  count
}

///|
fn devtools_max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}
