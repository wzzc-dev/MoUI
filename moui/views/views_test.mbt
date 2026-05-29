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
    @views.SectionListSection::new(id="a", title="Group A", items=["Ada", "Alan"]),
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
            control=@views.text_field("Value", on_input=_value => (), width=140.0),
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
}

///|
test "center card and title render simple content" {
  let root : @core.View[Unit] = @views.center(
    @views.card(@views.text("Centered").title()),
    width=400.0,
    height=300.0,
  )
  let runtime = @core.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=400.0, height=300.0),
  )
  assert_true(has_text(runtime.draw_commands(), "Centered"))
}

///|
test "form field primitives build labels helper and errors" {
  let root : @core.View[Unit] = @views.form(
    [
      @views.form_section(
        [
          @views.form_field(
            label="Name",
            child=@views.text_field("Ada", on_input=_value => ()),
            helper="Shown on normal fields",
            required=true,
          ),
          @views.form_field(
            label="Email",
            child=@views.text_field("", on_input=_value => ()),
            error="Email is required",
            status=@views.FormFieldStatus::Invalid,
          ),
          @views.form_field(
            label="Token",
            child=@views.text_field("readonly", on_input=_value => ()),
            status=@views.FormFieldStatus::ReadOnly,
            layout=@views.FormFieldLayout::Horizontal,
          ),
        ],
        title="Profile",
        summary="Grouped fields",
        width=420.0,
      ),
    ],
    width=440.0,
  )
  let runtime = @core.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=520.0, height=320.0),
  )
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Profile"))
  assert_true(has_text(commands, "Name *"))
  assert_true(has_text(commands, "Shown on normal fields"))
  assert_true(has_text(commands, "Email is required"))
  assert_true(runtime.semantics().children.length() > 0)
}

///|
test "form validation display can hide support text" {
  let root : @core.View[Unit] = @views.form_field(
    label="Hidden",
    child=@views.text_field("", on_input=_value => ()),
    error="Should not draw",
    validation_display=@views.FormValidationDisplay::Hidden,
  )
  let runtime = @core.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=360.0, height=120.0),
  )
  assert_false(has_text(runtime.draw_commands(), "Should not draw"))
}

///|
test "form field state uses core validation errors" {
  let field = @core.FormFieldState::new(
    name="email",
    label="Email",
    rules=[@core.FormValidationRule::required(message="Email required")],
  )
  let root : @core.View[Unit] = @views.form_field_state(
    field~,
    child=@views.text_field(field.value.get(), on_input=_value => ()),
    required=true,
  )
  let runtime = @core.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=420.0, height=140.0),
  )
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Email *"))
  assert_true(has_text(commands, "Email required"))
}

///|
test "enhanced input wrappers compose public controls" {
  let root : @core.View[Unit] = @views.form(
    [
      @views.input_group(
        child=@views.text_field("Grouped", on_input=_value => ()),
        prefix=Some(@views.text("$", width=20.0, height=24.0)),
        suffix=Some(@views.text("USD", width=44.0, height=24.0)),
      ),
      @views.clearable_text_field(
        "Search",
        on_input=_value => (),
        on_clear=(),
      ),
      @views.password_field(
        "secret",
        on_input=_value => (),
        revealed=false,
        on_toggle_reveal=(),
      ),
      @views.number_field(
        "42",
        on_input=_value => (),
        on_step=Some(_delta => ()),
      ),
      @views.stepper(on_decrement=(), on_increment=(), label="Page"),
      @views.multiline_text_area_shell("Line one", on_input=_value => ()),
    ],
  )
  let runtime = @core.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=520.0, height=380.0),
  )
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Grouped"))
  assert_true(has_text(commands, "USD"))
  assert_true(has_text(commands, "Clear"))
  assert_true(has_text(commands, "Show"))
  assert_false(has_text(commands, "secret"))
  assert_true(has_text(commands, "******"))
  assert_true(has_text(commands, "42"))
  assert_true(has_text(commands, "Page"))
  assert_true(has_text(commands, "Line one"))
}

///|
test "grouped choice controls compose selections and chips" {
  let choices = [
    @views.choice_item("native", "Native"),
    @views.choice_item("web", "Web"),
    @views.choice_item("test", "Test"),
  ]
  let root : @core.View[Unit] = @views.column(
    [
      @views.radio_group(choices, selected="native", on_select=_id => ()),
      @views.checkbox_group(
        choices,
        selected=["native", "test"],
        on_change=(_id, _checked) => (),
      ),
      @views.segmented_control(choices, selected="web", on_select=_id => ()),
      @views.row(
        [
          @views.chip("Stable", selected=true),
          @views.tag("Tag"),
          @views.filter_chip("Filter", selected=false, on_change=_value => ()),
          @views.choice_chip("Choice", selected=true, on_select=()),
        ],
      ),
    ],
  )
  let runtime = @core.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=560.0, height=360.0),
  )
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Native"))
  assert_true(has_text(commands, "Web"))
  assert_true(has_text(commands, "Test"))
  assert_true(has_text(commands, "Stable"))
  assert_true(has_text(commands, "Tag"))
  assert_true(has_text(commands, "Filter"))
  assert_true(has_text(commands, "Choice"))
}

///|
test "feedback and state components compose visible status surfaces" {
  let action = @views.StateViewAction::new(label="Retry", message=())
  let root : @core.View[Unit] = @views.column(
    [
      @views.toast("Saved", tone=@views.FeedbackTone::Success),
      @views.snackbar("Offline", action=Some(action)),
      @views.banner("Heads up", "Sync is delayed", tone=@views.FeedbackTone::Warning),
      @views.callout("Tip", "Use filters to narrow results"),
      @views.empty_state("No items", "Create a first item", action=Some(action)),
      @views.loading_state(),
      @views.error_state("Failed", "Try again", action=Some(action)),
      @views.row(
        [
          @views.badge("Beta", tone=@views.BadgeTone::Accent),
          @views.stat_card("Views", "128", caption="Today"),
        ],
      ),
    ],
  )
  let runtime = @core.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=680.0, height=760.0),
  )
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Saved"))
  assert_true(has_text(commands, "Offline"))
  assert_true(has_text(commands, "Retry"))
  assert_true(has_text(commands, "Heads up"))
  assert_true(has_text(commands, "No items"))
  assert_true(has_text(commands, "Loading"))
  assert_true(has_text(commands, "Failed"))
  assert_true(has_text(commands, "Beta"))
  assert_true(has_text(commands, "128"))
}

///|
test "popover dropdown combobox and autocomplete compose menu surfaces" {
  let items = [
    @views.MenuItem::new(id="one", label="One", message=()),
    @views.MenuItem::new(id="two", label="Two", message=(), enabled=false),
  ]
  let dropdown_state = @views.DropdownState::new(expanded=true, selected="one")
  let root : @core.View[Unit] = @views.column(
    [
      @views.popover(
        anchor=@views.button("Anchor", on_click=()),
        content=@views.text("Popover content", width=160.0),
        expanded=true,
      ),
      @views.dropdown("Mode", items, state=dropdown_state, on_toggle=()),
      @views.combobox("O", on_input=_value => (), items, expanded=true, on_toggle=()),
      @views.autocomplete("T", on_input=_value => (), items, expanded=true),
    ],
  )
  let runtime = @core.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=640.0, height=520.0),
  )
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Anchor"))
  assert_true(has_text(commands, "Popover content"))
  assert_true(has_text(commands, "Mode: One"))
  assert_true(has_text(commands, "One"))
  assert_true(has_text(commands, "Two"))
  assert_true(has_text(commands, "Open"))
}

///|
test "navigation shell components compose sidebar breadcrumb split and wizard" {
  let nav_items = [
    @views.SidebarItem::new(id="home", label="Home", message=()),
    @views.SidebarItem::new(id="settings", label="Settings", message=()),
  ]
  let crumbs = [
    @views.BreadcrumbItem::new(id="root", label="Root", message=Some(())),
    @views.BreadcrumbItem::new(id="current", label="Current"),
  ]
  let steps = [
    @views.WizardStep::new(
      id="first",
      title="First",
      content=@views.text("First content", width=180.0),
    ),
    @views.WizardStep::new(
      id="second",
      title="Second",
      content=@views.text("Second content", width=180.0),
      enabled=false,
    ),
  ]
  let root : @core.View[Unit] = @views.column(
    [
      @views.breadcrumb(crumbs),
      @views.split_view(
        primary=@views.sidebar("Sections", nav_items, selected="settings"),
        detail=@views.master_detail(
          master=@views.text("Master", width=120.0),
          detail=@views.text("Detail", width=160.0),
          master_width=120.0,
          detail_width=160.0,
          height=80.0,
        ),
        primary_width=220.0,
        detail_width=300.0,
        height=180.0,
      ),
      @views.wizard(steps, current="first", on_select=_route => ()),
    ],
  )
  let runtime = @core.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=760.0, height=620.0),
  )
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Root"))
  assert_true(has_text(commands, "Current"))
  assert_true(has_text(commands, "Sections"))
  assert_true(has_text(commands, "Home"))
  assert_true(has_text(commands, "Settings"))
  assert_true(has_text(commands, "Master"))
  assert_true(has_text(commands, "Detail"))
  assert_true(has_text(commands, "First"))
  assert_true(has_text(commands, "Second"))
  assert_true(has_text(commands, "First content"))
}

///|
test "router stack selects route location path and preserves query params" {
  let router = @core.RouterState::new(
    initial=@core.RouteLocation::parse("/detail?id=42"),
  )
  let root : @core.View[Unit] = @views.router_stack(
    router,
    [
      @views.navigation_destination(
        route="/home",
        view=@views.text("Home route", width=120.0),
      ),
      @views.navigation_destination(
        route="/detail",
        view=@views.text("Detail route", width=120.0),
      ),
    ],
    fallback=@views.text("Missing route", width=120.0),
  )
  let runtime = @core.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=320.0, height=120.0),
  )
  assert_true(has_text(runtime.draw_commands(), "Detail route"))
  inspect(router.current().param_value("id").unwrap_or(""), content="42")
}

///|
test "data display components compose tables trees descriptions and avatars" {
  let columns = [
    @views.table_column(id="name", label="Name", width=120.0),
    @views.table_column(id="state", label="State", width=96.0),
  ]
  let tree = [
    @views.tree_item(
      id="root",
      label="Root",
      children=[@views.tree_item(id="leaf", label="Leaf")],
    ),
  ]
  let root : @core.View[Unit] = @views.column(
    [
      @views.description_list([
        @views.description_item("Owner", "Mira"),
        @views.description_item("Status", "Active"),
      ]),
      @views.table(
        columns,
        [["Atlas", "Active"], ["Billing", "Review"]],
        selected_row=Some(1),
      ),
      @views.table(columns, [], empty=Some(@views.text("No data"))),
      @views.tree_view(tree, expanded=["root"], selected="leaf"),
      @views.avatar("Mira", size=32.0),
      @views.avatar_group(["Mira", "Noah", "Iris", "Ava", "Kai"], size=28.0),
    ],
  )
  let runtime = @core.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=720.0, height=680.0),
  )
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Owner"))
  assert_true(has_text(commands, "Mira"))
  assert_true(has_text(commands, "Name"))
  assert_true(has_text(commands, "Atlas"))
  assert_true(has_text(commands, "Billing"))
  assert_true(has_text(commands, "No data"))
  assert_true(has_text(commands, "Root"))
  assert_true(has_text(commands, "Leaf"))
  assert_true(has_text(commands, "+1"))
}

///|
test "toolbar and disclosure containers compose command surfaces" {
  let commands = [
    @views.MenuItem::new(id="save", label="Save", message=()),
    @views.MenuItem::new(id="delete", label="Delete", message=(), enabled=false),
  ]
  let sections = [
    @views.WizardStep::new(
      id="one",
      title="Section One",
      content=@views.text("One content", width=180.0),
    ),
    @views.WizardStep::new(
      id="two",
      title="Section Two",
      content=@views.text("Two content", width=180.0),
    ),
  ]
  let root : @core.View[Unit] = @views.column(
    [
      @views.toolbar([
        @views.button_group(commands, selected="save"),
        @views.command_bar(commands, width=220.0),
      ]),
      @views.status_bar(["Ready", "2 commands"]),
      @views.accordion(sections, expanded=["one"], on_toggle=_id => ()),
      @views.disclosure(
        "Inline Disclosure",
        content=@views.text("Inline content", width=180.0),
        expanded=true,
        on_toggle=(),
      ),
      @views.collapsible_panel(
        "Panel",
        content=@views.text("Panel content", width=180.0),
        expanded=true,
        on_toggle=(),
      ),
      @views.resizable_panel(content=@views.text("Resizable", width=160.0), size=180.0),
    ],
  )
  let runtime = @core.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=760.0, height=760.0),
  )
  let draw = runtime.draw_commands()
  assert_true(has_text(draw, "Save"))
  assert_true(has_text(draw, "Delete"))
  assert_true(has_text(draw, "Ready"))
  assert_true(has_text(draw, "Section One"))
  assert_true(has_text(draw, "One content"))
  assert_false(has_text(draw, "Two content"))
  assert_true(has_text(draw, "Inline Disclosure"))
  assert_true(has_text(draw, "Inline content"))
  assert_true(has_text(draw, "Panel content"))
  assert_true(has_text(draw, "Resizable"))
}

///|
test "command palette renders command metadata and filters rows" {
  let commands = [
    @core.ActionCommand::new(
      intent=@core.CommandIntent::Submit,
      label="Save Document",
      shortcut=Some(
        @core.KeyboardShortcut::new(
          key="s",
          modifiers=@core.KeyModifiers::new(meta=true),
        ),
      ),
      group="File",
      description="Persist the current document.",
    ),
    @core.ActionCommand::new(
      intent=@core.CommandIntent::Cancel,
      label="Close Panel",
      enabled=false,
      group="Window",
      description="Dismiss the active panel.",
    ),
  ]
  let root : @core.View[@core.CommandIntent] = @views.command_palette(
    commands,
    query="file",
    on_select=intent => intent,
  )
  let runtime = @core.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=520.0, height=320.0),
  )
  let draw = runtime.draw_commands()
  assert_true(has_text(draw, "Save Document"))
  assert_true(has_text(draw, "Meta+s"))
  assert_true(has_text(draw, "File - Persist the current document."))
  assert_false(has_text(draw, "Close Panel"))
}

///|
test "card supports independent optional dimensions" {
  let root : @core.View[Unit] = @views.card(@views.text("Wide"), width=240.0)
  let runtime = @core.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=400.0, height=120.0),
  )
  let layout = runtime.layout()
  inspect(layout.children[0].frame.size.width, content="240")
}

///|
fn has_text(commands : Array[@core.DrawCommand], text : String) -> Bool {
  commands.any(command => {
    command is @core.DrawCommand::DrawText({ text: value, .. }) && value == text
  })
}
