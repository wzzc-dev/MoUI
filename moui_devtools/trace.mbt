///|
/// A bounded, caller-owned read-only trace over runtime Inspector snapshots.
///
/// The trace stores deltas, not history of whole snapshots. The first sample
/// establishes the baseline; later samples carry message/effect/cache deltas,
/// frame-pass counters, and a bounded semantics-tree diff.
const DEFAULT_TRACE_CAPACITY : Int32 = 64

///|
const DEFAULT_TRACE_SEMANTICS_DIFF_LIMIT : Int32 = 128

///|
const TRACE_TEXT_ENTRY_LIMIT : Int32 = 16

///|
const TRACE_TEXT_DIFF_LIMIT : Int32 = 4

///|
pub(all) enum SemanticsTreeChangeKind {
  SemanticsTreeAdded
  SemanticsTreeRemoved
  SemanticsTreeChanged
} derive(Eq, Debug, ToJson)

///|
pub extend SemanticsTreeChangeKind with Debug::{to_repr}

///|
pub extend SemanticsTreeChangeKind with Eq::{not_equal, equal}

///|
pub extend SemanticsTreeChangeKind with ToJson::{to_json}

///|
pub(all) enum SemanticsTreeChangedField {
  SemanticsTreeFieldRole
  SemanticsTreeFieldLabel
  SemanticsTreeFieldValue
  SemanticsTreeFieldFrame
  SemanticsTreeFieldDepth
  SemanticsTreeFieldChildCount
  SemanticsTreeFieldActionCount
  SemanticsTreeFieldFocusable
  SemanticsTreeFieldSelected
  SemanticsTreeFieldChecked
  SemanticsTreeFieldExpanded
  SemanticsTreeFieldDisabled
} derive(Eq, Debug, ToJson)

///|
pub extend SemanticsTreeChangedField with Debug::{to_repr}

///|
pub extend SemanticsTreeChangedField with Eq::{not_equal, equal}

///|
pub extend SemanticsTreeChangedField with ToJson::{to_json}

///|
pub(all) struct SemanticsTreeDiffEntry {
  kind : SemanticsTreeChangeKind
  node_id : String
  before : @runtime.SemanticsInspectorEntry?
  after : @runtime.SemanticsInspectorEntry?
  changed_fields : Array[SemanticsTreeChangedField]
} derive(Eq, Debug, ToJson)

///|
pub extend SemanticsTreeDiffEntry with Debug::{to_repr}

///|
pub extend SemanticsTreeDiffEntry with Eq::{not_equal, equal}

///|
pub extend SemanticsTreeDiffEntry with ToJson::{to_json}

///|
pub(all) struct SemanticsTreeDiff {
  baseline : Bool
  added_count : Int32
  removed_count : Int32
  changed_count : Int32
  dropped_count : Int32
  entries : Array[SemanticsTreeDiffEntry]
} derive(Eq, Debug, ToJson)

///|
pub extend SemanticsTreeDiff with Debug::{to_repr}

///|
pub extend SemanticsTreeDiff with Eq::{not_equal, equal}

///|
pub extend SemanticsTreeDiff with ToJson::{to_json}

///|
pub(all) struct DevtoolsMessageTrace {
  dispatched_delta : Int32
  updated_delta : Int32
  ignored_delta : Int32
  enqueued_delta : Int32
  drained_delta : Int32
  pending_after : Int32
  max_pending_after : Int32
} derive(Eq, Debug, ToJson)

///|
pub extend DevtoolsMessageTrace with Debug::{to_repr}

///|
pub extend DevtoolsMessageTrace with Eq::{not_equal, equal}

///|
pub extend DevtoolsMessageTrace with ToJson::{to_json}

///|
pub(all) struct DevtoolsEffectTrace {
  planned_delta : Int32
  run_delta : Int32
  send_delta : Int32
  started_delta : Int32
  completed_delta : Int32
  cancelled_delta : Int32
  ignored_delta : Int32
  active_after : Int32
  descriptors : Array[@core.EffectDescriptor]
} derive(Eq, Debug, ToJson)

///|
pub extend DevtoolsEffectTrace with Debug::{to_repr}

///|
pub extend DevtoolsEffectTrace with Eq::{not_equal, equal}

///|
pub extend DevtoolsEffectTrace with ToJson::{to_json}

///|
pub(all) struct DevtoolsFrameTrace {
  timed : Bool
  rebuild_passes : Int32
  layout_passes : Int32
  paint_passes : Int32
  draw_builds : Int32
  build_ms : Double
  layout_ms : Double
  paint_ms : Double
  draw_ms : Double
  total_ms : Double
  damage_kind : String
  damage_rect_count : Int32
} derive(Eq, Debug, ToJson)

///|
pub extend DevtoolsFrameTrace with Debug::{to_repr}

///|
pub extend DevtoolsFrameTrace with Eq::{not_equal, equal}

///|
pub extend DevtoolsFrameTrace with ToJson::{to_json}

///|
pub(all) struct DevtoolsCacheTrace {
  layout_hits_delta : Int32
  layout_misses_delta : Int32
  render_hits_delta : Int32
  render_misses_delta : Int32
} derive(Eq, Debug, ToJson)

///|
pub extend DevtoolsCacheTrace with Debug::{to_repr}

///|
pub extend DevtoolsCacheTrace with Eq::{not_equal, equal}

///|
pub extend DevtoolsCacheTrace with ToJson::{to_json}

///|
pub(all) struct DevtoolsMemoTrace {
  available : Bool
  builds_delta : Int32
  hits_delta : Int32
  misses_delta : Int32
  builds_after : Int32
  hits_after : Int32
  misses_after : Int32
} derive(Eq, Debug, ToJson)

///|
pub extend DevtoolsMemoTrace with Debug::{to_repr}

///|
pub extend DevtoolsMemoTrace with Eq::{not_equal, equal}

///|
pub extend DevtoolsMemoTrace with ToJson::{to_json}

///|
pub(all) struct DevtoolsTraceEntry {
  sequence : Int32
  messages : DevtoolsMessageTrace
  effects : DevtoolsEffectTrace
  frame : DevtoolsFrameTrace
  caches : DevtoolsCacheTrace
  memo : DevtoolsMemoTrace
  semantics : SemanticsTreeDiff
} derive(Eq, Debug, ToJson)

///|
pub extend DevtoolsTraceEntry with Debug::{to_repr}

///|
pub extend DevtoolsTraceEntry with Eq::{not_equal, equal}

///|
pub extend DevtoolsTraceEntry with ToJson::{to_json}

///|
pub(all) struct DevtoolsTraceReport {
  capacity : Int32
  semantics_diff_limit : Int32
  entries : Array[DevtoolsTraceEntry]
} derive(Eq, Debug, ToJson)

///|
pub extend DevtoolsTraceReport with Debug::{to_repr}

///|
pub extend DevtoolsTraceReport with Eq::{not_equal, equal}

///|
pub extend DevtoolsTraceReport with ToJson::{to_json}

///|
priv struct DevtoolsTraceWatermark {
  runtime : @runtime.RuntimeInspectorSnapshot
  semantics : @runtime.SemanticsInspectorSnapshot
  memo : @core.ViewMemoStats?
}

///|
pub struct DevtoolsTrace {
  priv capacity : Int32
  priv semantics_diff_limit : Int32
  priv entries : Array[DevtoolsTraceEntry]
  priv mut previous : DevtoolsTraceWatermark?
  priv mut next_sequence : Int32
}

///|
/// Create a caller-owned trace. Retention and per-entry semantics-diff detail
/// are bounded independently so a large tree cannot consume unbounded memory.
pub fn DevtoolsTrace::new(
  capacity~ : Int32 = DEFAULT_TRACE_CAPACITY,
  semantics_diff_limit~ : Int32 = DEFAULT_TRACE_SEMANTICS_DIFF_LIMIT,
) -> DevtoolsTrace {
  {
    capacity: capacity.max(1),
    semantics_diff_limit: semantics_diff_limit.max(0),
    entries: [],
    previous: None,
    next_sequence: 0,
  }
}

///|
pub fn DevtoolsTrace::capacity(self : DevtoolsTrace) -> Int32 {
  self.capacity
}

///|
pub fn DevtoolsTrace::semantics_diff_limit(self : DevtoolsTrace) -> Int32 {
  self.semantics_diff_limit
}

///|
pub fn DevtoolsTrace::length(self : DevtoolsTrace) -> Int32 {
  self.entries.length()
}

///|
pub fn DevtoolsTrace::is_empty(self : DevtoolsTrace) -> Bool {
  self.entries.is_empty()
}

///|
pub fn DevtoolsTrace::entries(
  self : DevtoolsTrace,
) -> Array[DevtoolsTraceEntry] {
  self.entries.copy()
}

///|
pub fn DevtoolsTrace::latest(self : DevtoolsTrace) -> DevtoolsTraceEntry? {
  if self.entries.is_empty() {
    None
  } else {
    Some(self.entries[self.entries.length() - 1])
  }
}

///|
/// Drop retained samples and the comparison baseline. The next sample starts a
/// new baseline rather than being diffed against discarded state.
pub fn DevtoolsTrace::clear(self : DevtoolsTrace) -> Unit {
  self.entries.clear()
  self.previous = None
}

///|
/// Record a sample after an event/message turn. Frame pass counters are always
/// captured; timing stays zero unless `record_frame` receives profiled timing.
pub fn DevtoolsTrace::record(
  self : DevtoolsTrace,
  snapshot : @runtime.InspectorSnapshot,
  memo_stats? : @core.ViewMemoStats,
) -> DevtoolsTraceEntry {
  self.record_internal(snapshot, None, memo_stats)
}

///|
/// Record a sample after `AppRuntime::profile_draw_frame`. The supplied timing
/// belongs to that frame; pass counters still come from the Inspector snapshot.
pub fn DevtoolsTrace::record_frame(
  self : DevtoolsTrace,
  snapshot : @runtime.InspectorSnapshot,
  timing~ : @runtime.RuntimeFrameTiming,
  memo_stats? : @core.ViewMemoStats,
) -> DevtoolsTraceEntry {
  self.record_internal(snapshot, Some(timing), memo_stats)
}

///|
fn DevtoolsTrace::record_internal(
  self : DevtoolsTrace,
  snapshot : @runtime.InspectorSnapshot,
  timing : @runtime.RuntimeFrameTiming?,
  memo_stats : @core.ViewMemoStats?,
) -> DevtoolsTraceEntry {
  let runtime = snapshot.runtime()
  let semantics = snapshot.semantics()
  let previous_runtime = match self.previous {
    Some(previous) => Some(previous.runtime)
    None => None
  }
  let previous_semantics = match self.previous {
    Some(previous) => Some(previous.semantics)
    None => None
  }
  let previous_memo = match self.previous {
    Some(previous) => previous.memo
    None => None
  }
  let entry = {
    sequence: self.next_sequence,
    messages: message_trace_between(previous_runtime, runtime),
    effects: effect_trace_between(previous_runtime, runtime),
    frame: frame_trace_between(previous_runtime, runtime, timing),
    caches: cache_trace_between(previous_runtime, runtime),
    memo: memo_trace_between(previous_memo, memo_stats),
    semantics: semantics_tree_diff(
      previous_semantics,
      semantics,
      self.semantics_diff_limit,
    ),
  }
  self.entries.push(entry)
  if self.entries.length() > self.capacity {
    ignore(self.entries.remove(0))
  }
  self.previous = Some({ runtime, semantics, memo: memo_stats, })
  self.next_sequence = self.next_sequence + 1
  entry
}

///|
pub fn DevtoolsTrace::report(self : DevtoolsTrace) -> DevtoolsTraceReport {
  {
    capacity: self.capacity,
    semantics_diff_limit: self.semantics_diff_limit,
    entries: self.entries.copy(),
  }
}

///|
fn trace_counter_delta(current : Int32, previous : Int32) -> Int32 {
  if current >= previous {
    current - previous
  } else {
    current
  }
}

///|
fn message_trace_between(
  previous : @runtime.RuntimeInspectorSnapshot?,
  current : @runtime.RuntimeInspectorSnapshot,
) -> DevtoolsMessageTrace {
  let dispatched = match previous {
    Some(previous) => previous.program_dispatched_count()
    None => 0
  }
  let updated = match previous {
    Some(previous) => previous.program_update_count()
    None => 0
  }
  let ignored = match previous {
    Some(previous) => previous.ignored_program_dispatch_count()
    None => 0
  }
  let enqueued = match previous {
    Some(previous) => previous.program_message_enqueue_count()
    None => 0
  }
  let drained = match previous {
    Some(previous) => previous.program_message_drain_count()
    None => 0
  }
  {
    dispatched_delta: trace_counter_delta(
      current.program_dispatched_count(),
      dispatched,
    ),
    updated_delta: trace_counter_delta(current.program_update_count(), updated),
    ignored_delta: trace_counter_delta(
      current.ignored_program_dispatch_count(),
      ignored,
    ),
    enqueued_delta: trace_counter_delta(
      current.program_message_enqueue_count(),
      enqueued,
    ),
    drained_delta: trace_counter_delta(
      current.program_message_drain_count(),
      drained,
    ),
    pending_after: current.program_pending_message_count(),
    max_pending_after: current.program_max_pending_message_count(),
  }
}

///|
fn effect_trace_between(
  previous : @runtime.RuntimeInspectorSnapshot?,
  current : @runtime.RuntimeInspectorSnapshot,
) -> DevtoolsEffectTrace {
  let planned = match previous {
    Some(previous) => previous.program_effect_plan_count()
    None => 0
  }
  let executed = match previous {
    Some(previous) => previous.program_effect_run_count()
    None => 0
  }
  let sent = match previous {
    Some(previous) => previous.program_effect_send_count()
    None => 0
  }
  let started = match previous {
    Some(previous) => previous.started_effect_task_count()
    None => 0
  }
  let completed = match previous {
    Some(previous) => previous.completed_effect_task_count()
    None => 0
  }
  let cancelled = match previous {
    Some(previous) => previous.cancelled_effect_task_count()
    None => 0
  }
  let ignored = match previous {
    Some(previous) => previous.ignored_effect_task_dispatch_count()
    None => 0
  }
  {
    planned_delta: trace_counter_delta(
      current.program_effect_plan_count(),
      planned,
    ),
    run_delta: trace_counter_delta(current.program_effect_run_count(), executed),
    send_delta: trace_counter_delta(current.program_effect_send_count(), sent),
    started_delta: trace_counter_delta(
      current.started_effect_task_count(),
      started,
    ),
    completed_delta: trace_counter_delta(
      current.completed_effect_task_count(),
      completed,
    ),
    cancelled_delta: trace_counter_delta(
      current.cancelled_effect_task_count(),
      cancelled,
    ),
    ignored_delta: trace_counter_delta(
      current.ignored_effect_task_dispatch_count(),
      ignored,
    ),
    active_after: current.active_effect_task_count(),
    descriptors: current.last_effect_summary().descriptors().copy(),
  }
}

///|
fn frame_trace_between(
  previous : @runtime.RuntimeInspectorSnapshot?,
  current : @runtime.RuntimeInspectorSnapshot,
  timing : @runtime.RuntimeFrameTiming?,
) -> DevtoolsFrameTrace {
  let rebuild_passes = match previous {
    Some(previous) => previous.rebuild_pass_count()
    None => 0
  }
  let layout_passes = match previous {
    Some(previous) => previous.layout_pass_count()
    None => 0
  }
  let paint_passes = match previous {
    Some(previous) => previous.paint_pass_count()
    None => 0
  }
  let draw_builds = match previous {
    Some(previous) => previous.draw_command_build_count()
    None => 0
  }
  let timing_text = match timing {
    Some(timing) =>
      (
        true,
        timing.build_ms(),
        timing.layout_ms(),
        timing.paint_ms(),
        timing.draw_ms(),
        timing.total_ms(),
      )
    None => (false, 0.0, 0.0, 0.0, 0.0, 0.0)
  }
  let (timed, build_ms, layout_ms, paint_ms, draw_ms, total_ms) = timing_text
  let dirty = current.dirty_state()
  {
    timed,
    rebuild_passes: trace_counter_delta(
      current.rebuild_pass_count(),
      rebuild_passes,
    ),
    layout_passes: trace_counter_delta(
      current.layout_pass_count(),
      layout_passes,
    ),
    paint_passes: trace_counter_delta(current.paint_pass_count(), paint_passes),
    draw_builds: trace_counter_delta(
      current.draw_command_build_count(),
      draw_builds,
    ),
    build_ms,
    layout_ms,
    paint_ms,
    draw_ms,
    total_ms,
    damage_kind: dirty.damage_kind(),
    damage_rect_count: dirty.damage_rect_count(),
  }
}

///|
fn cache_trace_between(
  previous : @runtime.RuntimeInspectorSnapshot?,
  current : @runtime.RuntimeInspectorSnapshot,
) -> DevtoolsCacheTrace {
  let layout_hits = match previous {
    Some(previous) => previous.layout_cache_hit_count()
    None => 0
  }
  let layout_misses = match previous {
    Some(previous) => previous.layout_cache_miss_count()
    None => 0
  }
  let render_hits = match previous {
    Some(previous) => previous.render_cache_hit_count()
    None => 0
  }
  let render_misses = match previous {
    Some(previous) => previous.render_cache_miss_count()
    None => 0
  }
  {
    layout_hits_delta: trace_counter_delta(
      current.layout_cache_hit_count(),
      layout_hits,
    ),
    layout_misses_delta: trace_counter_delta(
      current.layout_cache_miss_count(),
      layout_misses,
    ),
    render_hits_delta: trace_counter_delta(
      current.render_cache_hit_count(),
      render_hits,
    ),
    render_misses_delta: trace_counter_delta(
      current.render_cache_miss_count(),
      render_misses,
    ),
  }
}

///|
fn memo_trace_between(
  previous : @core.ViewMemoStats?,
  current : @core.ViewMemoStats?,
) -> DevtoolsMemoTrace {
  match current {
    Some(current) => {
      let builds = match previous {
        Some(previous) => previous.build_count()
        None => 0
      }
      let hits = match previous {
        Some(previous) => previous.hit_count()
        None => 0
      }
      let misses = match previous {
        Some(previous) => previous.miss_count()
        None => 0
      }
      {
        available: true,
        builds_delta: trace_counter_delta(current.build_count(), builds),
        hits_delta: trace_counter_delta(current.hit_count(), hits),
        misses_delta: trace_counter_delta(current.miss_count(), misses),
        builds_after: current.build_count(),
        hits_after: current.hit_count(),
        misses_after: current.miss_count(),
      }
    }
    None =>
      {
        available: false,
        builds_delta: 0,
        hits_delta: 0,
        misses_delta: 0,
        builds_after: 0,
        hits_after: 0,
        misses_after: 0,
      }
  }
}

///|
fn semantics_tree_diff(
  previous : @runtime.SemanticsInspectorSnapshot?,
  current : @runtime.SemanticsInspectorSnapshot,
  limit : Int32,
) -> SemanticsTreeDiff {
  let before = match previous {
    Some(before) => before
    None =>
      return {
        baseline: true,
        added_count: 0,
        removed_count: 0,
        changed_count: 0,
        dropped_count: 0,
        entries: [],
      }
  }
  let previous_nodes : Map[String, @runtime.SemanticsInspectorEntry] = Map([])
  for node in before.nodes() {
    previous_nodes[node.node_id()] = node
  }
  let current_ids : Map[String, Bool] = Map([])
  let entries : Array[SemanticsTreeDiffEntry] = []
  let mut added_count = 0
  let mut removed_count = 0
  let mut changed_count = 0
  for node in current.nodes() {
    let node_id = node.node_id()
    current_ids[node_id] = true
    match previous_nodes.get(node_id) {
      Some(previous_node) =>
        if previous_node != node {
          changed_count = changed_count + 1
          if entries.length() < limit {
            entries.push({
              kind: SemanticsTreeChanged,
              node_id,
              before: Some(previous_node),
              after: Some(node),
              changed_fields: semantics_changed_fields(previous_node, node),
            })
          }
        }
      None => {
        added_count = added_count + 1
        if entries.length() < limit {
          entries.push({
            kind: SemanticsTreeAdded,
            node_id,
            before: None,
            after: Some(node),
            changed_fields: [],
          })
        }
      }
    }
  }
  for node in before.nodes() {
    let node_id = node.node_id()
    if !current_ids.contains(node_id) {
      removed_count = removed_count + 1
      if entries.length() < limit {
        entries.push({
          kind: SemanticsTreeRemoved,
          node_id,
          before: Some(node),
          after: None,
          changed_fields: [],
        })
      }
    }
  }
  let total = added_count + removed_count + changed_count
  {
    baseline: false,
    added_count,
    removed_count,
    changed_count,
    dropped_count: total - entries.length(),
    entries,
  }
}

///|
fn semantics_changed_fields(
  before : @runtime.SemanticsInspectorEntry,
  after : @runtime.SemanticsInspectorEntry,
) -> Array[SemanticsTreeChangedField] {
  let fields : Array[SemanticsTreeChangedField] = []
  if before.role() != after.role() {
    fields.push(SemanticsTreeFieldRole)
  }
  if before.label() != after.label() {
    fields.push(SemanticsTreeFieldLabel)
  }
  if before.value() != after.value() {
    fields.push(SemanticsTreeFieldValue)
  }
  if before.frame() != after.frame() {
    fields.push(SemanticsTreeFieldFrame)
  }
  if before.depth() != after.depth() {
    fields.push(SemanticsTreeFieldDepth)
  }
  if before.child_count() != after.child_count() {
    fields.push(SemanticsTreeFieldChildCount)
  }
  if before.action_count() != after.action_count() {
    fields.push(SemanticsTreeFieldActionCount)
  }
  if before.focusable() != after.focusable() {
    fields.push(SemanticsTreeFieldFocusable)
  }
  if before.selected() != after.selected() {
    fields.push(SemanticsTreeFieldSelected)
  }
  if before.checked() != after.checked() {
    fields.push(SemanticsTreeFieldChecked)
  }
  if before.expanded() != after.expanded() {
    fields.push(SemanticsTreeFieldExpanded)
  }
  if before.disabled() != after.disabled() {
    fields.push(SemanticsTreeFieldDisabled)
  }
  fields
}

///|
fn semantics_field_label(field : SemanticsTreeChangedField) -> String {
  match field {
    SemanticsTreeFieldRole => "role"
    SemanticsTreeFieldLabel => "label"
    SemanticsTreeFieldValue => "value"
    SemanticsTreeFieldFrame => "frame"
    SemanticsTreeFieldDepth => "depth"
    SemanticsTreeFieldChildCount => "children"
    SemanticsTreeFieldActionCount => "actions"
    SemanticsTreeFieldFocusable => "focusable"
    SemanticsTreeFieldSelected => "selected"
    SemanticsTreeFieldChecked => "checked"
    SemanticsTreeFieldExpanded => "expanded"
    SemanticsTreeFieldDisabled => "disabled"
  }
}

///|
fn semantics_diff_entry_text(entry : SemanticsTreeDiffEntry) -> String {
  match (entry.before, entry.after) {
    (Some(before), Some(after)) => {
      let fields = entry.changed_fields.map(semantics_field_label).join(",")
      "  ~ node=\{entry.node_id} role=\{Repr(after.role())} label=\{before.label()} -> \{after.label()} fields=\{fields}"
    }
    (None, Some(after)) =>
      "  + node=\{entry.node_id} role=\{Repr(after.role())} label=\{after.label()}"
    (Some(before), None) =>
      "  - node=\{entry.node_id} role=\{Repr(before.role())} label=\{before.label()}"
    (None, None) => ""
  }
}

///|
fn trace_entry_text(entry : DevtoolsTraceEntry) -> String {
  let messages = entry.messages
  let effects = entry.effects
  let frame = entry.frame
  let caches = entry.caches
  let memo = entry.memo
  let semantics = entry.semantics
  let memo_text = if memo.available {
    "b/h/m=\{memo.builds_delta}/\{memo.hits_delta}/\{memo.misses_delta} totals=\{memo.builds_after}/\{memo.hits_after}/\{memo.misses_after}"
  } else {
    "unavailable"
  }
  let semantics_text = if semantics.baseline {
    "baseline"
  } else {
    "+/-/~=\{semantics.added_count}/\{semantics.removed_count}/\{semantics.changed_count} dropped=\{semantics.dropped_count}"
  }
  let timing_text = if frame.timed {
    " timing=\{frame.build_ms}/\{frame.layout_ms}/\{frame.paint_ms}/\{frame.draw_ms}/\{frame.total_ms}ms"
  } else {
    ""
  }
  "#\{entry.sequence} messages(dispatch/update/enqueue/drain/pending)=\{messages.dispatched_delta}/\{messages.updated_delta}/\{messages.enqueued_delta}/\{messages.drained_delta}/\{messages.pending_after}; effects(plan/run/send/start/complete/cancel/active)=\{effects.planned_delta}/\{effects.run_delta}/\{effects.send_delta}/\{effects.started_delta}/\{effects.completed_delta}/\{effects.cancelled_delta}/\{effects.active_after}; frame(rebuild/layout/paint/draw)=\{frame.rebuild_passes}/\{frame.layout_passes}/\{frame.paint_passes}/\{frame.draw_builds}\{timing_text}; damage=\{frame.damage_kind}/\{frame.damage_rect_count}; cache(layout/render)=\{caches.layout_hits_delta}/\{caches.layout_misses_delta},\{caches.render_hits_delta}/\{caches.render_misses_delta}; memo=\{memo_text}; semantics=\{semantics_text}"
}

///|
/// Format the most recent trace samples. Node-level diff detail is limited so
/// terminal and in-app diagnostics stay readable; JSON retains every stored
/// entry within the recorder's configured bounds.
pub fn trace_report_text(
  trace : DevtoolsTrace,
  max_entries~ : Int32 = TRACE_TEXT_ENTRY_LIMIT,
) -> String {
  let entries = trace.entries()
  let requested = max_entries.max(0)
  let start = if entries.length() > requested {
    entries.length() - requested
  } else {
    0
  }
  let lines : Array[String] = [
    "[trace] capacity=\{trace.capacity()}; entries=\{entries.length()}; semantics_limit=\{trace.semantics_diff_limit()}; shown=\{entries.length() - start}",
  ]
  for index in start..<entries.length() {
    let entry = entries[index]
    lines.push(trace_entry_text(entry))
    let mut shown_diff = 0
    for diff in entry.semantics.entries {
      if shown_diff >= TRACE_TEXT_DIFF_LIMIT {
        break
      }
      let line = semantics_diff_entry_text(diff)
      if line != "" {
        lines.push(line)
        shown_diff = shown_diff + 1
      }
    }
  }
  lines.join("\n")
}

///|
pub fn trace_report_json(trace : DevtoolsTrace, indent~ : Int32 = 2) -> String {
  ToJson::to_json(trace.report()).stringify(indent~)
}
