///|
test "data and toast state helpers keep app owned workflow state predictable" {
  let sort = DataSortState::new(column="name").toggle("name").toggle("status")
  inspect(sort.column(), content="status")
  inspect(sort.ascending(), content="true")
  let page = PaginationState::new(page=3, page_size=10, total_count=24).clamped()
  inspect(page.page(), content="2")
  inspect(page.start_index(), content="20")
  inspect(page.end_index(), content="24")
  let columns = ColumnVisibilityState::new(visible=["name", "status"], locked=[
    "name",
  ])
  inspect(
    columns.set_visible("status", false).is_visible("status"),
    content="false",
  )
  inspect(columns.set_visible("name", false).is_visible("name"), content="true")
  let table_columns = [
    table_column(id="name", label="Name", width=120.0),
    table_column(id="status", label="Status", width=96.0),
    table_column(id="owner", label="Owner", width=112.0),
  ]
  let widths = ColumnWidthState::new(
      widths=table_columns,
      min_width=80.0,
      max_width=160.0,
    )
    .resize("status", 180.0)
    .resize("new", 40.0)
  inspect(widths.width_for("status", 96.0), content="160")
  inspect(widths.width_for("new", 120.0), content="80")
  let sized = widths.apply(table_columns)
  inspect(sized[1].width, content="160")
  let order = ColumnOrderState::new(order=["name", "status", "owner"])
    .move_before("owner", "name")
    .move_before("status", "name")
  let ordered = order.ordered_columns(table_columns)
  inspect(ordered[0].id, content="owner")
  inspect(ordered[1].id, content="status")
  inspect(ordered[2].id, content="name")
  let selection = SelectionState::new()
    .toggle("row-1")
    .toggle("row-2")
    .toggle("row-1")
  inspect(selection.count(), content="1")
  assert_true(selection.contains("row-2"))
  let queue = ToastQueue::new()
    .push(
      ToastQueueItem::new(
        id="saved",
        message="Saved",
        tone=FeedbackTone::Success,
        dismiss=Some("dismiss-saved"),
        created_at_ms=0.0,
        ttl_ms=100.0,
      ),
    )
    .push(ToastQueueItem::new(id="sticky", message="Sticky", created_at_ms=0.0))
    .expire(150.0)
  let stack_items = queue.to_stack_items()
  inspect(stack_items.length(), content="1")
  inspect(stack_items[0].message, content="Sticky")
}
