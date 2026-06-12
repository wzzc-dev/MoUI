///|
fn test_runtime(root : @core.View[Unit]) -> @core.AppRuntime {
  @core.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=640.0, height=480.0),
  )
}

///|
test "typed button dispatches message" {
  let clicks = Ref(0)
  let runtime = @core.AppRuntime::new_view(
    root=@views.button("Click", on_click=1, width=120.0, height=44.0),
    size=@core.Size::new(width=160.0, height=80.0),
    on_message=Some(message => clicks.val = clicks.val + message),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=20.0, y=20.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=20.0, y=20.0),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  inspect(clicks.val, content="1")
}

///|
test "view map lifts child message" {
  let seen = Ref("")
  let view = @views.button("Save", on_click="save").map(message => {
    "child:" + message
  })
  let runtime = @core.AppRuntime::new_view(
    root=view,
    size=@core.Size::new(width=160.0, height=80.0),
    on_message=Some(message => seen.val = message),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=20.0, y=20.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=20.0, y=20.0),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  inspect(seen.val, content="child:save")
}

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
test "controls and modifiers expose semantics" {
  let runtime = test_runtime(
    @views.column([
      @views.toggle_switch("Enabled", true, on_change=_value => ()),
      @views.progress(0.6, width=120.0),
      @views.text("Tip").semantics_role(@core.SemanticsRole::Tooltip),
    ]),
  )
  let semantics = runtime.semantics()
  inspect(semantics.children.length() > 0, content="true")
}

///|
test "web view constructor exposes platform placement and events" {
  let seen = Ref("")
  let runtime = @core.AppRuntime::new_view(
    root=@views.web_view(
      id="docs",
      url="https://wzzc-dev.github.io/MoUI/",
      width=Some(320.0),
      height=Some(180.0),
      title="MoUI docs",
      on_event=Some(event => {
        match event {
          @core.WebViewEvent::NavigationRequested(url) => "nav:" + url
          _ => "other"
        }
      }),
    ),
    size=@core.Size::new(width=480.0, height=320.0),
    on_message=Some(message => seen.val = message),
  )
  let frame = runtime.draw_frame()
  inspect(frame.platform_views.length(), content="1")
  inspect(frame.platform_views[0].id, content="docs")
  inspect(
    frame.platform_views[0].url,
    content="https://wzzc-dev.github.io/MoUI/",
  )
  inspect(frame.commands.length(), content="1")
  guard runtime.semantics().role == @core.SemanticsRole::WebView else {
    fail("expected web view semantics role")
  }
  runtime.dispatch_event(
    @core.AppEvent::WebView(
      "docs",
      @core.WebViewEvent::NavigationRequested("https://example.com/"),
    ),
  )
  inspect(seen.val, content="nav:https://example.com/")
}

test "controlled and binding view facades build together" {
  let enabled = @core.State::new(false)
  let draft = @core.State::new("draft")
  let query = @core.State::new("query")
  let choice = @core.State::new("alpha")
  let selected_date = @core.State::new(
    @core.DateValue::new(year=2026, month=5, day=21),
  )
  let tabs = [
    @views.tab_item(route="alpha", label="Alpha", view=@views.text("Tab Alpha")),
    @views.tab_item(route="beta", label="Beta", view=@views.text("Tab Beta")),
  ]
  let picker_items = [
    @views.picker_item("alpha", "Alpha"),
    @views.picker_item("beta", "Beta"),
  ]
  let runtime = test_runtime(
    @views.column(
      [
        @views.text_field("Draft", on_input=_value => ()),
        @views.text_field_binding(draft.binding()),
        @views.searchbar(query="Query", on_input=_value => ()),
        @views.searchbar_binding(query=query.binding()),
        @views.checkbox("Enabled", checked=enabled.get(), on_change=_value => ()),
        @views.checkbox_binding("Enabled binding", checked=enabled.binding()),
        @views.toggle("Toggle", enabled.get(), on_change=_value => ()),
        @views.toggle_binding("Toggle binding", enabled.binding()),
        @views.toggle_switch_binding("Toggle switch binding", enabled.binding()),
        @views.radio("Radio", enabled.get(), on_change=_value => ()),
        @views.radio_binding("Radio binding", enabled.binding()),
        @views.picker(picker_items, selected=choice.get(), on_select=_value => {
          ()
        }),
        @views.picker_binding(picker_items, selected=choice.binding()),
        @views.datepicker(selected=selected_date.get(), on_select=_value => ()),
        @views.datepicker_binding(selected=selected_date.binding()),
        @views.tab_view("alpha", tabs, on_select=_value => ()),
        @views.tab_view_binding(choice.binding(), tabs, on_select=_value => ()),
        @views.rich_text_editor_binding(
          draft.binding(),
          text => @core.RichTextDocument::plain(text),
          placeholder="Rich",
          width=240.0,
          height=96.0,
        ),
        @views.markdown_editor_binding(
          draft.binding(),
          text => @core.RichTextDocument::plain(text),
          placeholder="Markdown",
          width=240.0,
          height=96.0,
        ),
      ],
      spacing=8.0,
    ),
  )
  inspect(runtime.layout().children.length() > 0, content="true")
}

///|
test "text field submit emits typed message" {
  let submitted = Ref(false)
  let runtime = @core.AppRuntime::new_view(
    root=@views.text_field(
      "hello",
      on_input=_value => false,
      on_submit=Some(true),
    ),
    size=@core.Size::new(width=260.0, height=80.0),
    on_message=Some(message => submitted.val = message),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=10.0, y=10.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=10.0, y=10.0),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Enter")),
  )
  inspect(submitted.val, content="true")
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
