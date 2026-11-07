///|
/// Visual inspector tree over the data `InspectorSnapshot` already records:
/// the view-tree summary as an indented outline (one row per element, depth
/// indented, dirty channels flagged), plus the snapshot's node/control/
/// modified counts in the header. Pure views over caller-owned data — the
/// runtime owns no second tree and the overlay keeps no state.

///|
/// One indented outline row of the inspector tree.
pub struct InspectorTreeRow {
  depth : Int32
  kind : String
  element_id : Int32
  /// The pending-work channels this element carries, as a compact flag
  /// string: "b" build, "l" layout, "p" paint, in pipeline order. Empty when
  /// the element is clean.
  dirty_channels : String
}

///|
/// Flatten a snapshot's view-tree summary into outline rows. The snapshot's
/// node list is already depth-ordered (parents before children).
pub fn inspector_tree_rows(
  snapshot : @runtime.InspectorSnapshot,
) -> Array[InspectorTreeRow] {
  snapshot
  .view_tree()
  .nodes()
  .map(node => {
    let mut channels = ""
    if node.needs_build() {
      channels = channels + "b"
    }
    if node.needs_layout() {
      channels = channels + "l"
    }
    if node.needs_paint() {
      channels = channels + "p"
    }
    {
      depth: node.depth(),
      kind: node.kind(),
      element_id: node.element_id(),
      dirty_channels: channels,
    }
  })
}

///|
fn inspector_tree_dirty_text(row : InspectorTreeRow) -> String {
  if row.dirty_channels == "" {
    "·"
  } else {
    row.dirty_channels
  }
}

///|
/// The inspector tree view: counts header, then the outline (indented by
/// depth), truncated at `max_rows` rows with an honest "+N more" caption.
/// Dirty elements render in the foreground color; clean ones stay muted so
/// pending work is what the eye finds.
pub fn inspector_tree_view(
  snapshot : @runtime.InspectorSnapshot,
  theme~ : @core.Theme = @views.default_theme(),
  width~ : Double = 744.0,
  row_height~ : Double = 22.0,
  max_rows~ : Int32 = 24,
) -> @core.View[Unit] {
  let tree = snapshot.view_tree()
  let rows = inspector_tree_rows(snapshot)
  let visible_count = if rows.length() > max_rows {
    max_rows
  } else {
    rows.length()
  }
  let children : Array[@core.View[Unit]] = [
    @views.text(
      "nodes \{tree.node_count()} · controls \{tree.control_count()} · modified \{tree.modified_count()} · dirty b\{tree.dirty_build_count()}/l\{tree.dirty_layout_count()}/p\{tree.dirty_paint_count()}",
      role=Caption,
      theme~,
      width~,
    ),
  ]
  let mut index = 0
  while index < visible_count {
    let row = rows[index]
    let indent = (row.depth.to_double() * 14.0).max(0.0)
    let label_width = (width - 120.0 - indent).max(48.0)
    let mut indent_text = ""
    let mut level = 0
    while level < row.depth {
      indent_text = indent_text + "   "
      level = level + 1
    }
    children.push(
      @views.row(
        [
          @views.text(
            inspector_tree_dirty_text(row),
            role=Caption,
            theme~,
            width=24.0,
            height=row_height,
          ).foreground(
            if row.dirty_channels == "" {
              theme.palette.outline
            } else {
              theme.palette.error
            },
          ),
          @views.text(
            "\{indent_text}\{row.kind} #\{row.element_id}",
            role=Caption,
            theme~,
            width=label_width,
            height=row_height,
          ).foreground(
            if row.dirty_channels == "" {
              theme.palette.muted
            } else {
              theme.palette.foreground
            },
          ),
        ],
        spacing=4.0,
        align=Start,
      ),
    )
    index = index + 1
  }
  if rows.length() > visible_count {
    children.push(
      @views.text(
        "+\{rows.length() - visible_count} more nodes",
        role=Caption,
        theme~,
        width~,
      ),
    )
  }
  @views.padding(@views.column(children, spacing=2.0), 12.0)
}
