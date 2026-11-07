///|
/// Visual event/frame timeline over the data `DevtoolsTrace` already records:
/// one row per traced interaction, with the channels that carried work
/// (messages, effects, frame, caches, semantics) flagged as compact letters
/// and a per-row summary. Pure views over caller-owned data — the trace keeps
/// its own bounded history and the overlay adds none.

///|
/// One timeline row: the traced interaction's sequence number, the channels
/// that carried work as a compact flag string ("m" messages, "e" effects,
/// "f" frame, "c" caches, "s" semantics), and a one-line summary.
pub struct TraceTimelineRow {
  sequence : Int32
  channels : String
  summary : String
}

///|
fn trace_timeline_entry_row(
  entry : @devtools.DevtoolsTraceEntry,
) -> TraceTimelineRow {
  let messages = entry.messages
  let effects = entry.effects
  let frame = entry.frame
  let caches = entry.caches
  let semantics = entry.semantics
  let mut channels = ""
  if messages.dispatched_delta + messages.enqueued_delta > 0 {
    channels = channels + "m"
  }
  if effects.planned_delta +
    effects.run_delta +
    effects.started_delta +
    effects.completed_delta +
    effects.cancelled_delta >
    0 {
    channels = channels + "e"
  }
  if frame.timed {
    channels = channels + "f"
  }
  if caches.layout_hits_delta +
    caches.layout_misses_delta +
    caches.render_hits_delta +
    caches.render_misses_delta >
    0 {
    channels = channels + "c"
  }
  if semantics.added_count + semantics.removed_count + semantics.changed_count >
    0 {
    channels = channels + "s"
  }
  if channels == "" {
    channels = "—"
  }
  // The summary carries the numbers a maintainer scans for, channel by
  // channel, in pipeline order.
  let mut summary = ""
  if messages.dispatched_delta + messages.enqueued_delta > 0 {
    summary = summary +
      " msg+\{messages.dispatched_delta + messages.enqueued_delta}"
  }
  if effects.planned_delta > 0 {
    summary = summary + " fx+\{effects.planned_delta}"
  }
  if effects.completed_delta + effects.cancelled_delta > 0 {
    summary = summary +
      " fx-\{effects.completed_delta + effects.cancelled_delta}"
  }
  if frame.timed {
    summary = summary +
      " frame \{((frame.total_ms * 100.0).round() / 100.0)}ms b\{frame.rebuild_passes}/l\{frame.layout_passes}/p\{frame.paint_passes}"
  }
  if caches.layout_hits_delta +
    caches.layout_misses_delta +
    caches.render_hits_delta +
    caches.render_misses_delta >
    0 {
    summary = summary +
      " cache \{caches.layout_hits_delta + caches.render_hits_delta}/\{caches.layout_misses_delta + caches.render_misses_delta}"
  }
  if semantics.added_count + semantics.removed_count + semantics.changed_count >
    0 {
    summary = summary +
      " sem +\{semantics.added_count}/-\{semantics.removed_count}/~\{semantics.changed_count}"
  }
  if summary == "" {
    summary = " idle"
  }
  { sequence: entry.sequence, channels, summary, }
}

///|
/// How many leading rows the timeline window skips to keep the most recent
/// `max_rows` interactions visible.
pub fn trace_timeline_skip(entry_count~ : Int32, max_rows~ : Int32) -> Int32 {
  if entry_count > max_rows {
    entry_count - max_rows
  } else {
    0
  }
}

///|
/// Flatten a trace's entries into timeline rows, oldest first.
pub fn trace_timeline_rows(
  entries : Array[@devtools.DevtoolsTraceEntry],
) -> Array[TraceTimelineRow] {
  entries.map(entry => trace_timeline_entry_row(entry))
}

///|
/// The timeline view: one row per traced interaction — sequence number,
/// active-channel letters, summary — truncated at `max_rows` rows from the
/// END (the most recent interactions are the ones worth looking at), with an
/// honest "+N earlier" caption when truncating.
pub fn trace_timeline_view(
  entries : Array[@devtools.DevtoolsTraceEntry],
  theme~ : @core.Theme = @views.default_theme(),
  width~ : Double = 744.0,
  row_height~ : Double = 22.0,
  max_rows~ : Int32 = 20,
) -> @core.View[Unit] {
  let rows = trace_timeline_rows(entries)
  let skip = trace_timeline_skip(entry_count=rows.length(), max_rows~)
  let children : Array[@core.View[Unit]] = []
  if skip > 0 {
    children.push(
      @views.text("+\{skip} earlier entries", role=Caption, theme~, width~),
    )
  }
  let mut index = skip
  while index < rows.length() {
    let row = rows[index]
    let label_width = (width - 96.0).max(96.0)
    children.push(
      @views.row(
        [
          @views.text(
            "\{row.sequence}",
            role=Caption,
            theme~,
            width=28.0,
            height=row_height,
          ).foreground(theme.palette.outline),
          @views.text(
            row.channels,
            role=Caption,
            theme~,
            width=56.0,
            height=row_height,
          ).foreground(
            if row.channels == "—" {
              theme.palette.muted
            } else {
              theme.palette.primary
            },
          ),
          @views.text(
            row.summary,
            role=Caption,
            theme~,
            width=label_width,
            height=row_height,
          ).foreground(theme.palette.foreground),
        ],
        spacing=6.0,
        align=Start,
      ),
    )
    index = index + 1
  }
  if children.is_empty() {
    children.push(
      @views.text("no interactions traced", role=Caption, theme~, width~),
    )
  }
  @views.padding(@views.column(children, spacing=2.0), 12.0)
}
