///|
pub(all) struct SnapshotSummary {
  width : Double
  height : Double
  dirty_count : Int
  draw_command_count : Int
  view_node_count : Int
  layout_node_count : Int
  semantics_node_count : Int
  active_effect_task_count : Int
  active_subscription_count : Int
} derive(Eq, Debug, ToJson)

///|
/// A structured Inspector view for DevTools clients. The runtime owns the
/// detailed tree snapshots; this report keeps the five sections together so a
/// tool can inspect one section without parsing a large summary string.
pub(all) struct InspectorReport {
  runtime : @runtime.RuntimeInspectorSnapshot
  view_tree : @runtime.ViewTreeInspectorSnapshot
  layout : @runtime.LayoutInspectorSnapshot
  render : @runtime.RenderInspectorSnapshot
  semantics : @runtime.SemanticsInspectorSnapshot
} derive(Eq, Debug, ToJson)

///|
pub fn InspectorReport::from_snapshot(
  snapshot : @runtime.InspectorSnapshot,
) -> InspectorReport {
  {
    runtime: snapshot.runtime(),
    view_tree: snapshot.view_tree(),
    layout: snapshot.layout(),
    render: snapshot.render(),
    semantics: snapshot.semantics(),
  }
}

///|
pub fn InspectorReport::runtime(
  self : InspectorReport,
) -> @runtime.RuntimeInspectorSnapshot {
  self.runtime
}

///|
pub fn InspectorReport::view_tree(
  self : InspectorReport,
) -> @runtime.ViewTreeInspectorSnapshot {
  self.view_tree
}

///|
pub fn InspectorReport::layout(
  self : InspectorReport,
) -> @runtime.LayoutInspectorSnapshot {
  self.layout
}

///|
pub fn InspectorReport::render(
  self : InspectorReport,
) -> @runtime.RenderInspectorSnapshot {
  self.render
}

///|
pub fn InspectorReport::semantics(
  self : InspectorReport,
) -> @runtime.SemanticsInspectorSnapshot {
  self.semantics
}

///|
pub fn inspector_report(
  snapshot : @runtime.InspectorSnapshot,
) -> InspectorReport {
  InspectorReport::from_snapshot(snapshot)
}

///|
pub struct SnapshotHistory {
  priv entries : Array[SnapshotSummary]
}

///|
pub fn SnapshotSummary::from_snapshot(
  snapshot : @runtime.InspectorSnapshot,
) -> SnapshotSummary {
  {
    width: snapshot.runtime().size().width,
    height: snapshot.runtime().size().height,
    dirty_count: snapshot.runtime().dirty_count(),
    draw_command_count: snapshot.runtime().draw_command_count(),
    view_node_count: snapshot.view_tree().node_count(),
    layout_node_count: snapshot.layout().node_count(),
    semantics_node_count: snapshot.semantics().node_count(),
    active_effect_task_count: snapshot.runtime().active_effect_task_count(),
    active_subscription_count: snapshot.runtime().active_subscription_count(),
  }
}

///|
pub fn snapshot_summary(
  snapshot : @runtime.InspectorSnapshot,
) -> SnapshotSummary {
  SnapshotSummary::from_snapshot(snapshot)
}

///|
pub fn SnapshotSummary::text(self : SnapshotSummary) -> String {
  "size=\{self.width}x\{self.height}; dirty=\{self.dirty_count}; commands=\{self.draw_command_count}; view_nodes=\{self.view_node_count}; layout_nodes=\{self.layout_node_count}; semantics_nodes=\{self.semantics_node_count}; effects=\{self.active_effect_task_count}; subscriptions=\{self.active_subscription_count}"
}

///|
pub fn snapshot_debug_text(snapshot : @runtime.InspectorSnapshot) -> String {
  inspector_report_text(snapshot)
}

///|
/// Render a compact, sectioned Inspector report for terminal output and
/// overlays. Full node details remain available through `inspector_report` and
/// `snapshot_report_json`.
pub fn inspector_report_text(snapshot : @runtime.InspectorSnapshot) -> String {
  let report = InspectorReport::from_snapshot(snapshot)
  let runtime = report.runtime
  let dirty = runtime.dirty_state()
  let size = runtime.size()
  let view = report.view_tree
  let layout = report.layout
  let render = report.render
  let semantics = report.semantics
  let dirty_reasons = dirty.reasons().join(",")
  let root_role = Repr(semantics.root_role()).to_string()
  let hit_path = runtime
    .last_event_hit_path()
    .map(id => id.to_string())
    .join(" > ")
  [
    "[runtime] size=\{size.width}x\{size.height}; rebuild=\{runtime.rebuild_pass_count()}; layout=\{runtime.layout_pass_count()}; paint=\{runtime.paint_pass_count()}; commands=\{runtime.draw_command_count()}",
    "[view] root=\{view.root_kind()}; nodes=\{view.node_count()}; controls=\{view.control_count()}; modified=\{view.modified_count()}; dirty(build/layout/paint)=\{view.dirty_build_count()}/\{view.dirty_layout_count()}/\{view.dirty_paint_count()}",
    "[layout] nodes=\{layout.node_count()}; leaves=\{layout.leaf_count()}; depth=\{layout.max_depth()}; entries=\{layout.bounds().length()}; constraints=available",
    "[render] commands=\{render.command_count()}; text=\{render.text_count()}; images=\{render.image_count()}; paths=\{render.path_count()}; clips/layers/filters=\{render.clip_depth()}/\{render.layer_depth()}/\{render.filter_depth()}",
    "[semantics] root=\{root_role}; nodes=\{semantics.node_count()}; focusable=\{semantics.focusable_count()}; actions=\{semantics.action_count()}; depth=\{semantics.max_depth()}",
    "[dirty] count=\{runtime.dirty_count()}; kind=\{dirty.damage_kind()}; rects=\{dirty.damage_rect_count()}; reason=\{dirty.reason()}; reasons=\{dirty_reasons}",
    "[effects] active=\{runtime.active_effect_task_count()}; started=\{runtime.started_effect_task_count()}; completed=\{runtime.completed_effect_task_count()}; cancelled=\{runtime.cancelled_effect_task_count()}; lifecycle=\{runtime.effect_task_lifecycle().length()}",
    "[subscriptions] active=\{runtime.active_subscription_count()}; started=\{runtime.started_subscription_count()}; reused=\{runtime.reused_subscription_count()}; cancelled=\{runtime.cancelled_subscription_count()}; lifecycle=\{runtime.subscription_lifecycle().length()}",
    "[cache] layout(hit/miss)=\{runtime.layout_cache_hit_count()}/\{runtime.layout_cache_miss_count()}; render(hit/miss)=\{runtime.render_cache_hit_count()}/\{runtime.render_cache_miss_count()}",
    "[event] hit_path=\{hit_path}",
    "[timing] frame_timing=runtime-host; presentation=renderer-session (query the owning host/session for wall-clock samples)",
  ].join("\n")
}

///|
pub fn snapshot_report_json(
  snapshot : @runtime.InspectorSnapshot,
  indent? : Int = 2,
) -> String {
  ToJson::to_json(InspectorReport::from_snapshot(snapshot)).stringify(indent~)
}

///|
pub fn snapshot_json(
  snapshot : @runtime.InspectorSnapshot,
  indent? : Int = 2,
) -> String {
  snapshot_report_json(snapshot, indent~)
}

///|
pub fn SnapshotHistory::new() -> SnapshotHistory {
  { entries: [] }
}

///|
pub fn SnapshotHistory::push(
  self : SnapshotHistory,
  snapshot : @runtime.InspectorSnapshot,
) -> Unit {
  self.entries.push(SnapshotSummary::from_snapshot(snapshot))
}

///|
pub fn SnapshotHistory::length(self : SnapshotHistory) -> Int {
  self.entries.length()
}

///|
pub fn SnapshotHistory::latest(self : SnapshotHistory) -> SnapshotSummary? {
  if self.entries.is_empty() {
    None
  } else {
    Some(self.entries[self.entries.length() - 1])
  }
}

///|
pub fn SnapshotHistory::debug_text(self : SnapshotHistory) -> String {
  let lines : Array[String] = []
  for index in 0..<self.entries.length() {
    let entry = self.entries[index]
    lines.push("#\{index}: " + entry.text())
  }
  lines.join("\n")
}
