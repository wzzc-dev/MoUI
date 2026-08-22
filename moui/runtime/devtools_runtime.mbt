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
  let dirty_element_ids = state.dirty_element_ids().map(id => id.value())
  let dirty_build_element_ids = state.dirty.dirty_build_elements.map(id => {
    id.value()
  })
  let dirty_layout_element_ids = state.dirty.dirty_layout_elements.map(id => {
    id.value()
  })
  let dirty_paint_element_ids = state.dirty.dirty_paint_elements.map(id => {
    id.value()
  })
  let dirty_build_count = dirty_build_element_ids.length()
  let dirty_layout_count = dirty_layout_element_ids.length()
  let dirty_paint_count = dirty_paint_element_ids.length()
  let needs_rebuild = state.dirty.needs_rebuild
  let needs_layout = state.dirty.needs_layout
  let needs_paint = state.dirty.needs_paint
  let needs_redraw = state.dirty.needs_redraw
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
    damage_kind: state.stats.last_damage_region.kind(),
    damage_rect_count: state.stats.last_damage_region.rect_count(),
    damage_full_reason: state.stats.last_damage_region.full_reason(),
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
    rebuild_pass_count: state.stats.rebuild_pass_count,
    layout_pass_count: state.stats.layout_pass_count,
    paint_pass_count: state.stats.paint_pass_count,
    draw_command_build_count: state.stats.draw_command_build_count,
    layout_cache_hit_count: state.element_tree.root.inspector_layout_cache_hits(),
    layout_cache_miss_count: state.element_tree.root.inspector_layout_cache_misses(),
    render_cache_hit_count: state.element_tree.root.inspector_render_cache_hits(),
    render_cache_miss_count: state.element_tree.root.inspector_render_cache_misses(),
    last_event_hit_path: state.last_event_hit_path.copy(),
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
    bounds: layout_bounds_entries(
      state.cached_layout_tree_root(),
      state.element_tree.root,
      depth=0,
    ),
  }
}

///|
fn render_inspector_snapshot_from_state(
  state : RuntimeState,
) -> RenderInspectorSnapshot {
  {
    ..render_inspector_from_commands(state.cached_draw_commands()),
    nodes: render_inspector_entries(state.render_tree.root, depth=0),
  }
}

///|
fn semantics_inspector_snapshot_from_state(
  state : RuntimeState,
) -> SemanticsInspectorSnapshot {
  let semantics = state.cached_semantics()
  let nodes = semantics.nodes()
  let mut root_role = SemanticsRole::None
  match semantics.root() {
    Some(root) =>
      for node in nodes {
        if node.node_id == root {
          root_role = node.role
          break
        }
      }
    None => ()
  }
  let mut focusable_count = 0
  let mut action_count = 0
  let mut selected_count = 0
  let mut checked_count = 0
  let mut expanded_count = 0
  let mut invalid_count = 0
  let mut required_count = 0
  let mut described_count = 0
  let nodes_by_id : Map[SemanticsNodeId, SemanticsNode] = Map([])
  for node in nodes {
    nodes_by_id[node.node_id] = node
    if node.focus_order is Some(_) {
      focusable_count = focusable_count + 1
    }
    action_count = action_count + node.actions.length()
    if node.state.selected {
      selected_count = selected_count + 1
    }
    if node.state.checked == Some(SemanticsCheckedState::Checked) {
      checked_count = checked_count + 1
    }
    if node.state.expanded {
      expanded_count = expanded_count + 1
    }
    if node.state.invalid {
      invalid_count = invalid_count + 1
    }
    if node.state.required {
      required_count = required_count + 1
    }
    if node.description != "" {
      described_count = described_count + 1
    }
  }
  let max_depth = match semantics.root() {
    Some(root) => semantics_depth_from(root, nodes_by_id)
    None => 0
  }
  SemanticsInspectorSnapshot::{
    root_role,
    node_count: nodes.length(),
    focusable_count,
    action_count,
    max_depth,
    selected_count,
    checked_count,
    expanded_count,
    invalid_count,
    required_count,
    described_count,
    nodes: match semantics.root() {
      Some(root) => semantics_inspector_entries(root, nodes_by_id, depth=0)
      None => []
    },
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
  element : ElementNode,
  depth~ : Int,
) -> Array[LayoutBoundsInspectorEntry] {
  let entries : Array[LayoutBoundsInspectorEntry] = [
    LayoutBoundsInspectorEntry::{
      element_id: node.element_id.value(),
      frame: node.frame,
      constraints: element.layout_cache.cached_measure_constraints.unwrap_or(
        @core.Constraints::tight(node.frame.size),
      ),
      depth,
      child_count: node.children.length(),
    },
  ]
  for index, child in node.children {
    if index < element.children.length() {
      entries.append(
        layout_bounds_entries(child, element.children[index], depth=depth + 1),
      )
    }
  }
  entries
}

///|
fn render_inspector_entries(
  node : RenderNode,
  depth~ : Int,
) -> Array[RenderInspectorEntry] {
  let entries : Array[RenderInspectorEntry] = [
    {
      element_id: node.element_id.value(),
      frame: node.frame,
      paint_bounds: node.paint_bounds,
      depth,
      child_count: node.children.length(),
      command_count: node.paint_commands.length() +
      node.post_paint_commands.length(),
      overlay_command_count: node.overlay_paint_commands.length(),
      repaint_boundary: node.is_repaint_boundary,
      cache_key: node.layer_cache_key.unwrap_or(""),
    },
  ]
  for child in node.children {
    entries.append(render_inspector_entries(child, depth=depth + 1))
  }
  entries
}

///|
fn semantics_inspector_entries(
  id : SemanticsNodeId,
  nodes : Map[SemanticsNodeId, SemanticsNode],
  depth~ : Int,
) -> Array[SemanticsInspectorEntry] {
  guard nodes.get(id) is Some(node) else { return [] }
  let entries : Array[SemanticsInspectorEntry] = [
    {
      node_id: node.node_id.to_wire(),
      role: node.role,
      label: node.label,
      value: node.value,
      frame: node.frame,
      depth,
      child_count: node.children.length(),
      action_count: node.actions.length(),
      focusable: node.focus_order is Some(_),
      selected: node.state.selected,
      checked: node.state.checked == Some(SemanticsCheckedState::Checked),
      expanded: node.state.expanded,
      disabled: node.state.disabled,
    },
  ]
  for child in node.children {
    entries.append(semantics_inspector_entries(child, nodes, depth=depth + 1))
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
      PushLayer(_) | BeginRetainedLayer(_) => {
        layer_depth = layer_depth + 1
        max_layer_depth = runtime_devtools_max_int(max_layer_depth, layer_depth)
      }
      PopLayer | EndRetainedLayer(_) =>
        if layer_depth == 0 {
          unbalanced_pop_count = unbalanced_pop_count + 1
        } else {
          layer_depth = layer_depth - 1
        }
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
    nodes: [],
  }
}

///|
fn semantics_depth_from(
  id : SemanticsNodeId,
  nodes : Map[SemanticsNodeId, SemanticsNode],
) -> Int {
  match nodes.get(id) {
    Some(node) => {
      let mut depth = 1
      for child in node.children {
        depth = runtime_devtools_max_int(
          depth,
          1 + semantics_depth_from(child, nodes),
        )
      }
      depth
    }
    None => 0
  }
}

///|
fn runtime_devtools_max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}
