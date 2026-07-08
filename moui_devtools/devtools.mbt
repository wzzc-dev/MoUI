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
  SnapshotSummary::from_snapshot(snapshot).text()
}

///|
pub fn snapshot_json(
  snapshot : @runtime.InspectorSnapshot,
  indent? : Int = 2,
) -> String {
  snapshot.to_json().stringify(indent~)
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
