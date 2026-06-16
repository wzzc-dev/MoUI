///|
test "data display components compose tables trees descriptions and avatars" {
  let columns = [
    @views.table_column(id="name", label="Name", width=120.0),
    @views.table_column(id="state", label="State", width=96.0),
  ]
  let tree = [
    @views.tree_item(id="root", label="Root", children=[
      @views.tree_item(id="leaf", label="Leaf"),
    ]),
  ]
  let root : @core.View[Unit] = @views.column([
    @views.description_list([
      @views.description_item("Owner", "Mira"),
      @views.description_item("Status", "Active"),
    ]),
    @views.data_filter_bar(
      query="atlas",
      on_query=_value => (),
      filters=[
        @views.data_filter(
          id="active",
          label="Active",
          selected=true,
          message=(),
        ),
        @views.data_filter(
          id="paused",
          label="Paused",
          selected=false,
          message=(),
          enabled=false,
        ),
      ],
      result_count=2,
      on_clear=Some(()),
      width=420.0,
    ),
    @views.table(
      columns,
      [["Atlas", "Active"], ["Billing", "Review"]],
      selected_row=Some(1),
      sort_column="state",
      sort_ascending=false,
      on_sort=Some(_id => ()),
    ),
    @views.selectable_list(
      [
        @views.SelectableListItem::new(
          id="pipeline",
          title="Pipeline Alpha",
          subtitle="Healthy",
          detail="Owner Mira",
          message=(),
        ),
        @views.SelectableListItem::new(
          id="queue",
          title="Queue Beta",
          subtitle="Review required",
          detail="Owner Noah",
          message=(),
        ),
        @views.SelectableListItem::new(
          id="archive",
          title="Archive Locked",
          subtitle="Read only",
          detail="Owner Iris",
          message=(),
          enabled=false,
        ),
      ],
      selected="queue",
      width=420.0,
      row_height=58.0,
    ),
    @views.selection_toolbar(
      selected_count=2,
      total_count=5,
      actions=[
        @views.MenuItem::new(id="archive", label="Archive", message=()),
        @views.MenuItem::new(id="export", label="Export", message=()),
      ],
      on_clear=Some(()),
      width=420.0,
    ),
    @views.column_visibility_panel(
      columns,
      visible=["name"],
      locked=["name"],
      on_toggle=(_id, _visible) => (),
      width=420.0,
    ),
    @views.pagination(page=1, page_count=3, on_previous=(), on_next=()),
    @views.detail_panel(
      "Selected row",
      [
        @views.description_item("Project", "Billing"),
        @views.description_item("Owner", "Noah"),
      ],
      subtitle="Compact detail panel",
    ),
    @views.selectable_list([], empty=Some(@views.text("No list items"))),
    @views.table(columns, [], empty=Some(@views.text("No data"))),
    @views.tree_view(tree, expanded=["root"], selected="leaf"),
    @views.avatar("Mira", size=32.0),
    @views.avatar_group(["Mira", "Noah", "Iris", "Ava", "Kai"], size=28.0),
  ])
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=720.0, height=680.0),
  )
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Owner"))
  assert_true(has_text(commands, "Mira"))
  assert_true(has_text(commands, "atlas"))
  assert_true(has_text(commands, "2 results"))
  assert_true(has_text(commands, "Active"))
  assert_true(has_text(commands, "Paused"))
  assert_true(has_text(commands, "Clear"))
  assert_true(has_text(commands, "Name"))
  assert_true(has_text(commands, "State v"))
  assert_true(has_text(commands, "Atlas"))
  assert_true(has_text(commands, "Billing"))
  assert_true(has_text(commands, "Pipeline Alpha"))
  assert_true(has_text(commands, "Review required"))
  assert_true(has_text(commands, "Owner Noah"))
  assert_true(has_text(commands, "Archive Locked"))
  assert_true(has_text(commands, "2 of 5 selected"))
  assert_true(has_text(commands, "Archive"))
  assert_true(has_text(commands, "Export"))
  assert_true(has_text(commands, "Column visibility"))
  assert_true(has_text(commands, "1 of 2 columns visible"))
  assert_true(has_text(commands, "Hidden"))
  assert_true(has_text(commands, "Page 2 of 3"))
  assert_true(has_text(commands, "Selected row"))
  assert_true(has_text(commands, "Compact detail panel"))
  assert_true(has_text(commands, "Noah"))
  assert_true(has_text(commands, "No list items"))
  assert_true(has_text(commands, "No data"))
  assert_true(has_text(commands, "Root"))
  assert_true(has_text(commands, "Leaf"))
  assert_true(has_text(commands, "+1"))
  let semantics = runtime.semantics()
  guard find_semantics_label(semantics, "Selectable list") is Some(list) else {
    fail("expected selectable list semantics")
  }
  assert_true(list.role == @core.SemanticsRole::List)
  guard find_semantics_label(
      semantics, "Queue Beta, Review required, Owner Noah",
    )
    is Some(selected_item) else {
    fail("expected selected list item semantics")
  }
  assert_true(selected_item.role == @core.SemanticsRole::ListItem)
  assert_true(selected_item.state.selected)
  guard find_semantics_label(semantics, "Archive Locked, Read only, Owner Iris")
    is Some(disabled_item) else {
    fail("expected disabled list item semantics")
  }
  assert_true(disabled_item.state.disabled)
}
