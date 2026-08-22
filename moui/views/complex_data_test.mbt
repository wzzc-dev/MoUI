///|
struct ComplexDataRow {
  id : String
  value : String
} derive(Eq, Debug)

///|
fn complex_data_height(item : String) -> Double {
  match item {
    "a" => 20.0
    "b" => 40.0
    "c" => 30.0
    "d" => 50.0
    _ => 15.0
  }
}

///|
test "variable list metrics window and stable anchor" {
  let metrics = @views.variable_list_metrics(
    ["a", "b", "c"],
    item => item,
    complex_data_height,
    spacing=2.0,
  )
  inspect(metrics.total_extent(), content="94")
  guard metrics.visible_range(offset_y=22.0, viewport_height=20.0, overscan=0)
    is Some(range) else {
    fail("expected a variable-height range")
  }
  inspect(range.first_index(), content="1")
  inspect(range.last_index(), content="1")
  inspect(range.before_extent(), content="20")
  inspect(range.after_extent(), content="30")
  guard metrics.anchor_for_offset(32.0) is Some(anchor) else {
    fail("expected an anchor")
  }
  inspect(anchor.key(), content="b")
  inspect(anchor.inset(), content="10")
  let with_prefix = @views.variable_list_metrics(
    ["x", "a", "b", "c"],
    item => item,
    complex_data_height,
    spacing=2.0,
  )
  inspect(with_prefix.offset_for_anchor(anchor), content="49")
  inspect(
    with_prefix.with_height("a", 60.0).offset_for_anchor(anchor),
    content="89",
  )
}

///|
test "variable virtual list keeps only keyed visible rows" {
  let items = ["a", "b", "c", "d"]
  let metrics = @views.variable_list_metrics(
    items,
    item => item,
    complex_data_height,
    spacing=2.0,
  )
  let view : @core.View[Unit] = @views.variable_virtual_list(
    items,
    metrics~,
    item => item,
    item => @views.text(item),
    viewport_height=20.0,
    overscan=0,
    offset=@core.Point::new(x=0.0, y=22.0),
    on_scroll=_ => (),
  )
  let rows = view.children()[0].children()
  inspect(rows.length(), content="3")
  inspect(rows[0].identity().kind, content="Spacer")
  inspect(rows[1].identity().kind, content="Frame")
  inspect(rows[2].identity().kind, content="Spacer")
  assert_true(rows[1].identity().key is Some(_))
  guard @views.scroll_to_key(request_id=7, metrics~, key="c", inset=3.0)
    is Some(request) else {
    fail("expected key scroll request")
  }
  inspect(request.offset.y, content="67")
}

///|
test "data grid viewport includes frozen panes without duplicate cells" {
  let viewport = @views.data_grid_viewport(
    first_row=10,
    last_row=12,
    first_column=5,
    last_column=6,
    row_count=100,
    column_count=20,
    overscan_rows=1,
    overscan_columns=1,
    freeze=@views.data_grid_freeze_panes(rows=1, columns=2),
  )
  let cells = viewport.cells()
  inspect(cells.length(), content="36")
  assert_true(viewport.contains(@views.data_grid_cell(row=0, column=5)))
  assert_true(viewport.contains(@views.data_grid_cell(row=10, column=0)))
  assert_false(viewport.contains(@views.data_grid_cell(row=2, column=2)))
  inspect(
    @views.data_grid_cell_key("row:1", "column:2"),
    content="r5:row:1c8:column:2",
  )
}

///|
test "data grid keyboard selection extends from a stable anchor" {
  let shifted = @views.DataGridSelectionState::new(row=2, column=2)
    .handle_key(
      @core.KeyboardEvent::new(
        key="ArrowRight",
        modifiers=@core.KeyModifiers::new(shift=true),
      ),
      row_count=10,
      column_count=5,
    )
    .handle_key(
      @core.KeyboardEvent::new(
        key="ArrowDown",
        modifiers=@core.KeyModifiers::new(shift=true),
      ),
      row_count=10,
      column_count=5,
    )
  inspect(shifted.range().cell_count(), content="4")
  inspect(shifted.anchor().row(), content="2")
  inspect(shifted.focus().row(), content="3")
  inspect(shifted.focus().column(), content="3")
  let end = shifted.handle_key(
    @core.KeyboardEvent::new(
      key="End",
      modifiers=@core.KeyModifiers::new(control=true),
    ),
    row_count=10,
    column_count=5,
  )
  inspect(end.focus().row(), content="9")
  inspect(end.focus().column(), content="4")
  inspect(end.range().cell_count(), content="1")
}

///|
test "data grid edit state commits a controlled draft" {
  let cell = @views.data_grid_cell(row=4, column=2)
  let editing = @views.DataGridEditState::idle()
    .begin(cell, "before")
    .update("after")
  assert_true(editing.is_dirty())
  guard editing.commit() is Some(commit) else { fail("expected edit commit") }
  assert_eq(commit.cell(), cell)
  inspect(commit.value(), content="after")
  assert_true(editing.cancel().active_cell() is None)
}

///|
test "incremental data preserves keyed row order" {
  let first = ComplexDataRow::{ id: "a", value: "one" }
  let second = ComplexDataRow::{ id: "b", value: "two" }
  let updated = ComplexDataRow::{ id: "b", value: "updated" }
  let third = ComplexDataRow::{ id: "c", value: "three" }
  let data = @views.IncrementalData::new(items=[first, second]).apply(
    [
      @views.IncrementalDataChange::Upsert(updated),
      @views.IncrementalDataChange::Append(third),
      @views.IncrementalDataChange::Remove("a"),
    ],
    row => row.id,
  )
  let rows = data.items()
  inspect(rows.length(), content="2")
  inspect(rows[0].id, content="b")
  inspect(rows[0].value, content="updated")
  inspect(rows[1].id, content="c")
  inspect(data.revision(), content="1")
}
