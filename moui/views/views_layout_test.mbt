///|
test "layout constructors produce layout through public runtime" {
  let runtime = test_runtime(
    @views.surface(
      @views.column(
        [
          @views.text("Title").key("title"),
          @views.row(
            [
              @views.text("A"),
              @views.spacer(min_length=12.0, weight=0.0),
              @views.text("B"),
            ],
            spacing=4.0,
          ),
        ],
        spacing=8.0,
      ),
      width=300.0,
      height=160.0,
      padding=12.0,
    ),
  )
  let layout = runtime.layout()
  inspect(layout.frame.size.width, content="640")
  inspect(layout.children.length() > 0, content="true")
}

///|
test "lazy list and grid build public views" {
  let items = [1, 2, 3, 4, 5, 6]
  let state = @core.ScrollState::new()
  let intent = @views.scroll_to_index(
    state,
    index=3,
    item_height=20.0,
    spacing=2.0,
  )
  let runtime = test_runtime(
    @views.column([
      @views.lazy_list(
        items,
        item => "item-\{item}",
        item => @views.text("Row \{item}"),
        viewport_height=80.0,
      ),
      @views.lazy_grid(
        items,
        item => "cell-\{item}",
        item => @views.text("Cell \{item}"),
        columns=2,
        viewport_height=120.0,
      ),
      @views.virtual_list(
        items,
        item => "virtual-\{item}",
        item => @views.text("Virtual \{item}"),
        state~,
        item_height=20.0,
        viewport_height=44.0,
        spacing=2.0,
        overscan=0,
      ),
    ]),
  )
  inspect(runtime.layout().children.length() > 0, content="true")
  inspect(intent.offset.y, content="66")
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Virtual 4"))
  assert_true(has_text(commands, "Virtual 5"))
  assert_true(has_text(commands, "Virtual 6"))
  assert_false(has_text(commands, "Virtual 1"))
}

///|
test "sectioned list renders headers rows and empty state" {
  let sections = [
    @views.SectionListSection::new(id="a", title="Group A", items=[
      "Ada", "Alan",
    ]),
    @views.SectionListSection::new(id="b", title="Group B", items=["Grace"]),
  ]
  let runtime = test_runtime(
    @views.sectioned_list(
      sections,
      item => "person-" + item,
      item => @views.text(item),
      header=section => @views.text(section.title),
      item_height=20.0,
      header_height=20.0,
      viewport_height=96.0,
    ),
  )
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Group A"))
  assert_true(has_text(commands, "Ada"))
  assert_true(has_text(commands, "Group B"))
  let empty_runtime = test_runtime(
    @views.sectioned_list(
      [],
      item => item,
      item => @views.text(item),
      empty=Some(@views.text("No sections")),
    ),
  )
  assert_true(has_text(empty_runtime.draw_commands(), "No sections"))
}

///|
test "custom layout facade participates in layout" {
  let runtime = test_runtime(
    @views.custom_layout(
      measure=constraints => {
        constraints.constrain(@core.Size::new(width=80.0, height=32.0))
      },
      paint=_frame => [],
      semantics_label="custom",
    ),
  )
  inspect(runtime.layout().frame.size.width, content="640")
}

///|
test "flow responsive grid and baseline rows place children" {
  let runtime = test_runtime(
    @views.column([
      @views.wrap(
        [
          @views.text("Chip A", width=72.0, height=20.0),
          @views.text("Chip B", width=72.0, height=20.0),
          @views.text("Chip C", width=72.0, height=20.0),
        ],
        width=160.0,
        spacing=4.0,
        row_spacing=6.0,
      ),
      @views.responsive_grid(
        [
          @views.text("Grid A", width=72.0, height=20.0),
          @views.text("Grid B", width=72.0, height=20.0),
          @views.text("Grid C", width=72.0, height=20.0),
        ],
        width=260.0,
        min_column_width=100.0,
        column_spacing=8.0,
      ),
      @views.baseline_form_rows(
        [
          @views.BaselineFormRow::new(
            label=@views.text("Label", width=80.0, height=24.0),
            control=@views.text_field(
              "Value",
              on_input=_value => (),
              width=140.0,
            ),
          ),
        ],
        width=260.0,
        label_width=90.0,
      ),
    ]),
  )
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Chip A"))
  assert_true(has_text(commands, "Chip C"))
  assert_true(has_text(commands, "Grid B"))
  assert_true(has_text(commands, "Label"))
  assert_true(has_text(commands, "Value"))
  guard text_frame(commands, "Grid A") is Some(grid_a) else {
    fail("expected Grid A text")
  }
  guard text_frame(commands, "Grid B") is Some(grid_b) else {
    fail("expected Grid B text")
  }
  guard text_frame(commands, "Grid C") is Some(grid_c) else {
    fail("expected Grid C text")
  }
  guard text_frame(commands, "Label") is Some(label) else {
    fail("expected Label text")
  }
  assert_true(grid_b.origin.x > grid_a.origin.x)
  assert_true(grid_c.origin.x < grid_b.origin.x)
  assert_true(grid_c.origin.y > grid_a.origin.y)
  assert_true(label.origin.y > grid_c.origin.y + grid_c.size.height)
}
