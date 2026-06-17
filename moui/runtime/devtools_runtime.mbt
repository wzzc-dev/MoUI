///|
fn AppRuntime::inspector_snapshot_from_state(
  self : AppRuntime,
) -> InspectorSnapshot {
  let view_tree = self.state.view_tree_inspector_snapshot()
  InspectorSnapshot::{
    runtime: runtime_inspector_snapshot_from_state(
      self.state,
      self.program_runtime_snapshot(),
    ),
    view_tree,
    layout: layout_inspector_snapshot_from_state(self.state),
    render: render_inspector_snapshot_from_state(self.state),
    semantics: semantics_inspector_snapshot_from_state(self.state),
  }
}

///|
fn program_runtime_snapshot_empty() -> ProgramRuntimeSnapshot {
  ProgramRuntimeSnapshot::{
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
fn runtime_inspector_snapshot_from_state(
  state : RuntimeState,
  program : ProgramRuntimeSnapshot,
) -> RuntimeInspectorSnapshot {
  let dirty_count = state.dirty_count()
  let dirty_element_ids = state.dirty_element_ids()
  let dirty_build_element_ids = state.dirty_build_elements.copy()
  let dirty_layout_element_ids = state.dirty_layout_elements.copy()
  let dirty_paint_element_ids = state.dirty_paint_elements.copy()
  let dirty_build_count = dirty_build_element_ids.length()
  let dirty_layout_count = dirty_layout_element_ids.length()
  let dirty_paint_count = dirty_paint_element_ids.length()
  let needs_rebuild = state.needs_rebuild
  let needs_layout = state.needs_layout
  let needs_paint = state.needs_paint
  let needs_redraw = state.needs_redraw
  let rebuild_reason = state.inspector_rebuild_reason()
  let dirty_reasons = state.inspector_dirty_reasons()
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
    damage_kind: state.last_damage_region.kind(),
    damage_rect_count: state.last_damage_region.rect_count(),
    damage_full_reason: state.last_damage_region.full_reason(),
    cache_epoch: state.cache_epoch,
    cached_layer_count: state.known_layer_cache_keys.length(),
  }
  let draw_commands = state.cached_draw_commands()
  RuntimeInspectorSnapshot::{
    size: state.size,
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
    rebuild_pass_count: state.rebuild_pass_count,
    layout_pass_count: state.layout_pass_count,
    paint_pass_count: state.paint_pass_count,
    draw_command_build_count: state.draw_command_build_count,
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
fn layout_inspector_snapshot_from_state(
  state : RuntimeState,
) -> LayoutInspectorSnapshot {
  let layout = state.cached_layout()
  LayoutInspectorSnapshot::{
    root_frame: layout.frame,
    node_count: layout_node_count(layout),
    leaf_count: layout_leaf_count(layout),
    max_depth: layout_max_depth(layout),
    bounds: layout_bounds_entries(state.cached_layout_tree_root(), depth=0),
  }
}

///|
fn render_inspector_snapshot_from_state(
  state : RuntimeState,
) -> RenderInspectorSnapshot {
  render_inspector_from_commands(state.cached_draw_commands())
}

///|
fn semantics_inspector_snapshot_from_state(
  state : RuntimeState,
) -> SemanticsInspectorSnapshot {
  let semantics = state.cached_semantics()
  SemanticsInspectorSnapshot::{
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
    depth = runtime_devtools_max_int(depth, 1 + layout_max_depth(child))
  }
  depth
}

///|
fn layout_bounds_entries(
  node : PlacedNode,
  depth~ : Int,
) -> Array[LayoutBoundsInspectorEntry] {
  let entries : Array[LayoutBoundsInspectorEntry] = [
    LayoutBoundsInspectorEntry::{
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
        max_clip_depth = runtime_devtools_max_int(max_clip_depth, clip_depth)
      }
      PopClip | PopRoundedClip =>
        if clip_depth == 0 {
          unbalanced_pop_count = unbalanced_pop_count + 1
        } else {
          clip_depth = clip_depth - 1
        }
      PushLayer(_) | BeginCachedLayer(_) => {
        layer_depth = layer_depth + 1
        max_layer_depth = runtime_devtools_max_int(max_layer_depth, layer_depth)
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
        max_filter_depth = runtime_devtools_max_int(
          max_filter_depth, filter_depth,
        )
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
    depth = runtime_devtools_max_int(depth, 1 + semantics_max_depth(child))
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
fn runtime_devtools_max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}
