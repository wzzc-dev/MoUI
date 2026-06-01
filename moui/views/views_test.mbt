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
test "shortcut button renders hint and dispatches keyboard shortcut" {
  let selected = Ref("")
  let shortcut = @core.KeyboardShortcut::new(
    key="s",
    modifiers=@core.KeyModifiers::new(meta=true),
  )
  let runtime = @core.AppRuntime::new_view(
    root=@views.shortcut_button("Save", on_click="save", shortcut~, width=220.0),
    size=@core.Size::new(width=260.0, height=90.0),
    on_message=Some(message => selected.val = message),
  )
  let draw = runtime.draw_commands()
  assert_true(has_text(draw, "Save"))
  assert_true(has_text(draw, "Meta+s"))
  guard find_semantics_label(runtime.semantics(), "Save, shortcut Meta+s")
    is Some(node) else {
    fail("expected shortcut button semantics")
  }
  inspect(node.description, content="Shortcut Meta+s")
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="s",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  inspect(selected.val, content="save")
}

///|
test "focus ring exposes app owned focus state" {
  let runtime = test_runtime(
    @views.column([
      @views.focus_ring(
        @views.text("Name field", width=96.0, height=24.0),
        focused=true,
        label="Focus target: name",
        width=140.0,
        height=42.0,
      ),
      @views.focus_ring(
        @views.text("Email field", width=96.0, height=24.0),
        focused=false,
        label="Focus target: email",
        width=140.0,
        height=42.0,
      ),
    ]),
  )
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Name field"))
  assert_true(has_text(commands, "Email field"))
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::StrokeRoundedRectBrush(_, _, 2.0)
    }),
  )
  let semantics = runtime.semantics()
  guard find_semantics_label(semantics, "Focus target: name") is Some(name) else {
    fail("expected focused ring semantics")
  }
  assert_true(name.state.selected)
  inspect(name.description, content="Focused")
  assert_true(
    name.actions.any(action => action == @core.SemanticsAction::Focus),
  )
  guard find_semantics_label(semantics, "Focus target: email") is Some(email) else {
    fail("expected unfocused ring semantics")
  }
  assert_false(email.state.selected)
  inspect(email.description, content="Not focused")
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
          @views.form_validation_summary(
            summary=@core.FormValidationSummary::from_errors([
              { name: "email", message: "Email is required" },
              { name: "token", message: "Token is expired" },
            ]),
            action=Some(
              @views.StateViewAction::new(label="Focus first", message=()),
            ),
          ),
          @views.form_field(
            label="Token",
            child=@views.text_field("readonly", on_input=_value => ()),
            status=@views.FormFieldStatus::ReadOnly,
            layout=@views.FormFieldLayout::Horizontal,
          ),
          @views.form_actions(
            primary=@views.StateViewAction::new(
              label="Save changes",
              message=(),
            ),
            secondary=Some(
              @views.StateViewAction::new(label="Cancel", message=()),
            ),
            status="Submit disabled until Email is valid",
            primary_enabled=false,
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
  assert_true(has_text(commands, "Review required"))
  assert_true(has_text(commands, "First invalid: email"))
  assert_true(has_text(commands, "token: Token is expired"))
  assert_true(has_text(commands, "Focus first"))
  assert_true(has_text(commands, "Submit disabled until Email is valid"))
  assert_true(has_text(commands, "Save changes"))
  assert_true(has_text(commands, "Cancel"))
  assert_true(runtime.semantics().children.length() > 0)
  guard find_semantics_label(runtime.semantics(), "Validation summary")
    is Some(summary) else {
    fail("expected validation summary semantics")
  }
  assert_true(summary.state.invalid)
  guard find_semantics_label(runtime.semantics(), "Save changes") is Some(save) else {
    fail("expected save action semantics")
  }
  assert_true(save.state.disabled)
}

///|
test "form workflow bar links validation focus and keyboard action status" {
  let focus_scope = @core.FocusScope::new(
    items=[
      @core.FocusScopeItem::new(id="name"),
      @core.FocusScopeItem::new(id="email"),
      @core.FocusScopeItem::new(id="archived", enabled=false),
      @core.FocusScopeItem::new(id="submit", focusable=false),
    ],
    current=Some("name"),
    default_action="submit",
    dismiss_action="cancel",
  )
  let invalid_summary = @core.FormValidationSummary::from_errors([
    { name: "email", message: "Email is required" },
  ])
  let invalid_runtime = @core.AppRuntime::new_view(
    root=@views.form_workflow_bar(
      summary=invalid_summary,
      primary=@views.StateViewAction::new(label="Save", message=()),
      secondary=Some(@views.StateViewAction::new(label="Cancel", message=())),
      focus_scope=Some(focus_scope),
      focus_invalid=Some(
        @views.StateViewAction::new(label="Focus first", message=()),
      ),
      width=420.0,
    ),
    size=@core.Size::new(width=480.0, height=240.0),
  )
  let invalid_draw = invalid_runtime.draw_commands()
  assert_true(has_text(invalid_draw, "Review required"))
  assert_true(has_text(invalid_draw, "First invalid: email"))
  assert_true(has_text(invalid_draw, "Focus first"))
  assert_true(has_text(invalid_draw, "Fix email before submit"))
  guard find_semantics_label(invalid_runtime.semantics(), "Form workflow")
    is Some(workflow) else {
    fail("expected form workflow semantics")
  }
  assert_true(workflow.state.invalid)
  guard find_semantics_label(invalid_runtime.semantics(), "Save") is Some(save) else {
    fail("expected disabled primary action")
  }
  assert_true(save.state.disabled)
  let valid_runtime = @core.AppRuntime::new_view(
    root=@views.form_workflow_bar(
      summary=@core.FormValidationSummary::from_errors([]),
      primary=@views.StateViewAction::new(label="Save", message=()),
      secondary=Some(@views.StateViewAction::new(label="Cancel", message=())),
      focus_scope=Some(focus_scope),
      valid_message="All required fields pass",
      width=420.0,
    ),
    size=@core.Size::new(width=480.0, height=220.0),
  )
  let valid_draw = valid_runtime.draw_commands()
  assert_true(has_text(valid_draw, "All required fields pass"))
  assert_true(has_text(valid_draw, "Enter: submit / Escape: cancel"))
  guard find_semantics_label(valid_runtime.semantics(), "Save")
    is Some(valid_save) else {
    fail("expected enabled primary action")
  }
  assert_false(valid_save.state.disabled)
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
  let field = @core.FormFieldState::new(name="email", label="Email", rules=[
    @core.FormValidationRule::required(message="Email required"),
  ])
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
  let root : @core.View[Unit] = @views.form([
    @views.input_group(
      child=@views.text_field("Grouped", on_input=_value => ()),
      prefix=Some(@views.text("$", width=20.0, height=24.0)),
      suffix=Some(@views.text("USD", width=44.0, height=24.0)),
    ),
    @views.clearable_text_field("Search", on_input=_value => (), on_clear=()),
    @views.password_field(
      "secret",
      on_input=_value => (),
      revealed=false,
      on_toggle_reveal=(),
    ),
    @views.number_field("42", on_input=_value => (), on_step=Some(_delta => ())),
    @views.stepper(on_decrement=(), on_increment=(), label="Page"),
    @views.multiline_text_area_shell("Line one", on_input=_value => ()),
  ])
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
  let root : @core.View[Unit] = @views.column([
    @views.radio_group(choices, selected="native", on_select=_id => ()),
    @views.checkbox_group(choices, selected=["native", "test"], on_change=(
      _id,
      _checked,
    ) => ()),
    @views.segmented_control(choices, selected="web", on_select=_id => ()),
    @views.row([
      @views.chip("Stable", selected=true),
      @views.tag("Tag"),
      @views.filter_chip("Filter", selected=false, on_change=_value => ()),
      @views.choice_chip("Choice", selected=true, on_select=()),
    ]),
  ])
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
test "component semantics expose selection validation and expanded states" {
  let choices = [
    @views.choice_item("native", "Native"),
    @views.choice_item("web", "Web"),
  ]
  let tree_items = [
    @views.tree_item(id="root", label="Root", children=[
      @views.tree_item(id="leaf", label="Leaf"),
    ]),
  ]
  let commands = [
    @views.MenuItem::new(id="save", label="Save", message=()),
    @views.MenuItem::new(id="open", label="Open", message=()),
  ]
  let root : @core.View[Unit] = @views.column([
    @views.form_field(
      label="Email",
      child=@views.text_field("", on_input=_value => ()),
      error="Email required",
      required=true,
    ),
    @views.segmented_control(choices, selected="web", on_select=_id => ()),
    @views.tree_view(tree_items, expanded=["root"], selected="leaf"),
    @views.button_group(commands, selected="save"),
    @views.button("Pressed action").semantics_pressed(),
    @views.button("Disabled action").disabled(),
    @views.inline_error("Sync failed"),
  ])
  let semantics = @core.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=760.0, height=520.0),
  ).semantics()
  guard find_semantics_label(semantics, "Email, invalid, Email required")
    is Some(email) else {
    fail("expected email form field semantics")
  }
  assert_true(email.role == @core.SemanticsRole::FormField)
  assert_true(email.state.invalid)
  assert_true(email.state.required)
  inspect(email.description, content="Email required")
  guard find_semantics_label(semantics, "Web") is Some(web) else {
    fail("expected selected segment semantics")
  }
  assert_true(web.role == @core.SemanticsRole::Tab)
  assert_true(web.state.selected)
  guard find_semantics_label(semantics, "Root") is Some(root_item) else {
    fail("expected root tree item semantics")
  }
  assert_true(root_item.role == @core.SemanticsRole::TreeItem)
  assert_true(root_item.state.expanded)
  guard find_semantics_label(semantics, "Leaf") is Some(leaf_item) else {
    fail("expected leaf tree item semantics")
  }
  assert_true(leaf_item.state.selected)
  guard find_semantics_label(semantics, "Save") is Some(save) else {
    fail("expected button group selected item")
  }
  assert_true(save.state.selected)
  guard find_semantics_label(semantics, "Pressed action") is Some(pressed) else {
    fail("expected pressed semantics")
  }
  assert_true(pressed.state.pressed)
  guard find_semantics_label(semantics, "Disabled action") is Some(disabled) else {
    fail("expected disabled semantics")
  }
  assert_true(disabled.state.disabled)
  guard find_semantics_label(semantics, "Error: Sync failed")
    is Some(inline_error) else {
    fail("expected inline error semantics")
  }
  assert_true(inline_error.role == @core.SemanticsRole::Group)
  assert_true(inline_error.state.invalid)
}

///|
test "feedback and state components compose visible status surfaces" {
  let action = @views.StateViewAction::new(label="Retry", message=())
  let root : @core.View[Unit] = @views.column([
    @views.toast("Saved", tone=@views.FeedbackTone::Success),
    @views.toast_stack(
      [
        @views.ToastStackItem::new(
          id="sync",
          message="Sync complete",
          tone=@views.FeedbackTone::Success,
          dismiss=Some(()),
        ),
        @views.ToastStackItem::new(
          id="offline",
          message="Offline retry queued",
          tone=@views.FeedbackTone::Warning,
          action=Some(action),
        ),
      ],
      width=380.0,
    ),
    @views.snackbar("Offline", action=Some(action)),
    @views.banner(
      "Heads up",
      "Sync is delayed",
      tone=@views.FeedbackTone::Warning,
    ),
    @views.callout("Tip", "Use filters to narrow results"),
    @views.empty_state("No items", "Create a first item", action=Some(action)),
    @views.loading_state(),
    @views.error_state("Failed", "Try again", action=Some(action)),
    @views.inline_error("Email is already used", action=Some(action)),
    @views.progress_status(
      "Export report",
      value=0.64,
      message="Preparing CSV rows",
      status="Running",
      action=Some(action),
      width=380.0,
    ),
    @views.row([
      @views.badge("Beta", tone=@views.BadgeTone::Accent),
      @views.status_badge(
        "Ready",
        tone=@views.BadgeTone::Success,
        detail="Sync pipeline ready",
      ),
      @views.stat_card("Views", "128", caption="Today"),
    ]),
  ])
  let runtime = @core.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=680.0, height=880.0),
  )
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Saved"))
  assert_true(has_text(commands, "Sync complete"))
  assert_true(has_text(commands, "Offline retry queued"))
  assert_true(has_text(commands, "Dismiss"))
  assert_true(has_text(commands, "Offline"))
  assert_true(has_text(commands, "Retry"))
  assert_true(has_text(commands, "Heads up"))
  assert_true(has_text(commands, "No items"))
  assert_true(has_text(commands, "Loading"))
  assert_true(has_text(commands, "Failed"))
  assert_true(has_text(commands, "Email is already used"))
  assert_true(has_text(commands, "Export report"))
  assert_true(has_text(commands, "Preparing CSV rows"))
  assert_true(has_text(commands, "Running"))
  assert_true(has_text(commands, "Beta"))
  assert_true(has_text(commands, "Ready"))
  assert_true(has_text(commands, "128"))
  guard find_semantics_label(runtime.semantics(), "Dismiss") is Some(dismiss) else {
    fail("expected toast dismiss semantics")
  }
  assert_true(
    dismiss.actions.any(action => action == @core.SemanticsAction::Dismiss),
  )
  guard find_semantics_label(runtime.semantics(), "Progress: Export report")
    is Some(progress_status) else {
    fail("expected progress status semantics")
  }
  assert_true(progress_status.role == @core.SemanticsRole::Group)
  guard find_semantics_label(runtime.semantics(), "Progress")
    is Some(progress_node) else {
    fail("expected nested progress semantics")
  }
  assert_true(progress_node.role == @core.SemanticsRole::Progress)
  guard find_semantics_label(runtime.semantics(), "Status: Ready")
    is Some(status_badge) else {
    fail("expected status badge semantics")
  }
  assert_true(status_badge.role == @core.SemanticsRole::Text)
  inspect(status_badge.description, content="Sync pipeline ready")
}

///|
test "progress status optional action dispatches typed message" {
  let selected = Ref("")
  let runtime = @core.AppRuntime::new_view(
    root=@views.progress_status(
      "Upload bundle",
      value=0.25,
      status="Uploading",
      action=Some(@views.StateViewAction::new(label="Cancel", message="cancel")),
      width=360.0,
    ),
    size=@core.Size::new(width=420.0, height=180.0),
    on_message=Some(message => selected.val = message),
  )
  guard text_frame(runtime.draw_commands(), "Cancel") is Some(cancel_frame) else {
    fail("expected progress action")
  }
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(
          x=cancel_frame.origin.x + 4.0,
          y=cancel_frame.origin.y + 4.0,
        ),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(
          x=cancel_frame.origin.x + 4.0,
          y=cancel_frame.origin.y + 4.0,
        ),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  inspect(selected.val, content="cancel")
}

///|
test "popover dropdown combobox and autocomplete compose menu surfaces" {
  let items = [
    @views.MenuItem::new(id="one", label="One", message=()),
    @views.MenuItem::new(id="two", label="Two", message=(), enabled=false),
  ]
  let dropdown_state = @views.DropdownState::new(expanded=true, selected="one")
  let root : @core.View[Unit] = @views.column([
    @views.popover(
      anchor=@views.button("Anchor", on_click=()),
      content=@views.text("Popover content", width=160.0),
      expanded=true,
    ),
    @views.dropdown("Mode", items, state=dropdown_state, on_toggle=()),
    @views.combobox(
      "O",
      on_input=_value => (),
      items,
      expanded=true,
      on_toggle=(),
    ),
    @views.autocomplete("T", on_input=_value => (), items, expanded=true),
  ])
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
  let semantics = runtime.semantics()
  guard find_semantics_label(semantics, "Mode: One") is Some(dropdown) else {
    fail("expected dropdown anchor semantics")
  }
  assert_true(dropdown.role == @core.SemanticsRole::Menu)
  assert_true(dropdown.state.expanded)
  assert_true(
    dropdown.actions.any(action => action == @core.SemanticsAction::Collapse),
  )
  guard find_semantics_label(semantics, "Mode options") is Some(options) else {
    fail("expected dropdown menu semantics")
  }
  assert_true(options.role == @core.SemanticsRole::Menu)
  guard find_semantics_label(semantics, "One") is Some(one) else {
    fail("expected selected dropdown option")
  }
  assert_true(one.state.selected)
  guard find_semantics_label(semantics, "Two") is Some(two) else {
    fail("expected disabled dropdown option")
  }
  assert_true(two.state.disabled)
}

///|
test "alert composes dialog content and actions" {
  let primary = @views.StateViewAction::new(label="Confirm", message=())
  let secondary = @views.StateViewAction::new(label="Cancel", message=())
  let runtime = test_runtime(
    @views.alert(
      "Delete project",
      "This action cannot be undone.",
      primary_action=primary,
      secondary_action=Some(secondary),
      tone=@views.FeedbackTone::Danger,
    ),
  )
  let draw = runtime.draw_commands()
  assert_true(has_text(draw, "Delete project"))
  assert_true(has_text(draw, "This action cannot be undone."))
  assert_true(has_text(draw, "Confirm"))
  assert_true(has_text(draw, "Cancel"))
  guard find_semantics_label(runtime.semantics(), "Delete project")
    is Some(alert) else {
    fail("expected alert dialog semantics")
  }
  assert_true(alert.role == @core.SemanticsRole::Dialog)
}

///|
test "dialog composes custom content dismiss and action messages" {
  let selected = Ref("")
  let runtime = @core.AppRuntime::new_view(
    root=@views.dialog(
      "Edit project",
      content=@views.description_list([
        @views.description_item("Owner", "Mira"),
        @views.description_item("Status", "Active"),
      ]),
      subtitle="Custom dialog content",
      primary_action=Some(
        @views.StateViewAction::new(label="Save", message="save"),
      ),
      secondary_action=Some(
        @views.StateViewAction::new(label="Cancel", message="cancel"),
      ),
      dismiss_action=Some(
        @views.StateViewAction::new(label="Close", message="close"),
      ),
      width=420.0,
      height=260.0,
    ),
    size=@core.Size::new(width=480.0, height=320.0),
    on_message=Some(message => selected.val = message),
  )
  let draw = runtime.draw_commands()
  assert_true(has_text(draw, "Edit project"))
  assert_true(has_text(draw, "Custom dialog content"))
  assert_true(has_text(draw, "Owner"))
  assert_true(has_text(draw, "Mira"))
  assert_true(has_text(draw, "Save"))
  assert_true(has_text(draw, "Cancel"))
  guard find_semantics_label(runtime.semantics(), "Edit project")
    is Some(dialog) else {
    fail("expected custom dialog semantics")
  }
  assert_true(dialog.role == @core.SemanticsRole::Dialog)
  guard find_semantics_label(runtime.semantics(), "Close") is Some(close) else {
    fail("expected dismiss action semantics")
  }
  assert_true(
    close.actions.any(action => action == @core.SemanticsAction::Dismiss),
  )
  guard text_frame(draw, "Save") is Some(save_frame) else {
    fail("expected primary action")
  }
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(
          x=save_frame.origin.x + 4.0,
          y=save_frame.origin.y + 4.0,
        ),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(
          x=save_frame.origin.x + 4.0,
          y=save_frame.origin.y + 4.0,
        ),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  inspect(selected.val, content="save")
}

///|
test "navigation shell components compose sidebar breadcrumb split and wizard" {
  let nav_items = [
    @views.SidebarItem::new(id="home", label="Home", message=()),
    @views.SidebarItem::new(id="settings", label="Settings", message=()),
  ]
  let section_items = [
    @views.SectionNavItem::new(
      id="builder",
      label="Builder",
      summary="App setup",
      message=(),
    ),
    @views.SectionNavItem::new(
      id="runtime",
      label="Runtime",
      summary="Renderer and host state",
      message=(),
    ),
    @views.SectionNavItem::new(
      id="billing",
      label="Billing",
      summary="Disabled section",
      message=(),
      enabled=false,
    ),
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
  let root : @core.View[Unit] = @views.column([
    @views.route_header("Settings", subtitle="Manage workspace preferences", actions=[
      @views.MenuItem::new(id="save", label="Save", message=()),
      @views.MenuItem::new(
        id="export",
        label="Export",
        message=(),
        enabled=false,
      ),
    ]),
    @views.breadcrumb(crumbs),
    @views.section_nav(
      "Product Areas",
      section_items,
      selected="runtime",
      orientation=@core.Axis::Vertical,
      width=220.0,
    ),
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
  ])
  let runtime = @core.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=760.0, height=620.0),
  )
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Settings"))
  assert_true(has_text(commands, "Manage workspace preferences"))
  assert_true(has_text(commands, "Save"))
  assert_true(has_text(commands, "Export"))
  assert_true(has_text(commands, "Root"))
  assert_true(has_text(commands, "Current"))
  assert_true(has_text(commands, "Product Areas"))
  assert_true(has_text(commands, "Builder"))
  assert_true(has_text(commands, "Renderer and host state"))
  assert_true(has_text(commands, "Disabled section"))
  assert_true(has_text(commands, "Sections"))
  assert_true(has_text(commands, "Home"))
  assert_true(has_text(commands, "Settings"))
  assert_true(has_text(commands, "Master"))
  assert_true(has_text(commands, "Detail"))
  assert_true(has_text(commands, "First"))
  assert_true(has_text(commands, "Second"))
  assert_true(has_text(commands, "First content"))
  guard find_semantics_label(
      runtime.semantics(),
      "Runtime, Renderer and host state",
    )
    is Some(runtime_section) else {
    fail("expected selected section navigation item semantics")
  }
  assert_true(runtime_section.role == @core.SemanticsRole::ListItem)
  assert_true(runtime_section.state.selected)
  guard find_semantics_label(runtime.semantics(), "Billing, Disabled section")
    is Some(disabled_section) else {
    fail("expected disabled section navigation item semantics")
  }
  assert_true(disabled_section.state.disabled)
}

///|
test "section nav dispatches selected item messages" {
  let selected = Ref("")
  let runtime = @core.AppRuntime::new_view(
    root=@views.section_nav(
      "Areas",
      [
        @views.SectionNavItem::new(
          id="builder",
          label="Builder",
          summary="App setup",
          message="builder",
        ),
        @views.SectionNavItem::new(
          id="runtime",
          label="Runtime",
          summary="Renderer host",
          message="runtime",
        ),
        @views.SectionNavItem::new(
          id="billing",
          label="Billing",
          summary="Disabled",
          message="billing",
          enabled=false,
        ),
      ],
      selected="builder",
      width=480.0,
    ),
    size=@core.Size::new(width=520.0, height=140.0),
    on_message=Some(message => selected.val = message),
  )
  guard text_frame(runtime.draw_commands(), "Runtime") is Some(runtime_frame) else {
    fail("expected runtime section item")
  }
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(
          x=runtime_frame.origin.x + 4.0,
          y=runtime_frame.origin.y + 4.0,
        ),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(
          x=runtime_frame.origin.x + 4.0,
          y=runtime_frame.origin.y + 4.0,
        ),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  inspect(selected.val, content="runtime")
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
  let runtime = @core.AppRuntime::new_view(
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

///|
test "column visibility panel dispatches controlled column toggles" {
  let toggled = Ref("")
  let columns = [
    @views.table_column(id="name", label="Name", width=120.0),
    @views.table_column(id="status", label="Status", width=96.0),
    @views.table_column(id="owner", label="Owner", width=112.0),
  ]
  let runtime = @core.AppRuntime::new_view(
    root=@views.column_visibility_panel(
      columns,
      visible=["name", "owner"],
      locked=["name"],
      on_toggle=(id, next_visible) => {
        let state = if next_visible { "shown" } else { "hidden" }
        id + ":" + state
      },
      width=360.0,
    ),
    size=@core.Size::new(width=400.0, height=220.0),
    on_message=Some(message => toggled.val = message),
  )
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Column visibility"))
  assert_true(has_text(commands, "2 of 3 columns visible"))
  assert_true(has_text(commands, "Name"))
  assert_true(has_text(commands, "Status"))
  assert_true(has_text(commands, "Owner"))
  assert_true(has_text(commands, "Shown"))
  assert_true(has_text(commands, "Hidden"))
  let semantics = runtime.semantics()
  guard find_semantics_label(semantics, "Column visibility") is Some(panel) else {
    fail("expected column visibility panel semantics")
  }
  assert_true(panel.role == @core.SemanticsRole::Group)
  inspect(panel.description, content="2 of 3 columns visible")
  guard find_semantics_label(semantics, "Name, Shown") is Some(name) else {
    fail("expected locked visible column semantics")
  }
  assert_true(name.state.selected)
  assert_true(name.state.disabled)
  guard find_semantics_label(semantics, "Status, Hidden") is Some(status) else {
    fail("expected hidden column semantics")
  }
  assert_false(status.state.selected)
  guard text_frame(commands, "Status") is Some(status_frame) else {
    fail("expected status column row")
  }
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=20.0, y=status_frame.origin.y + 4.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=20.0, y=status_frame.origin.y + 4.0),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  inspect(toggled.val, content="status:shown")
}

///|
test "selectable list dispatches item messages" {
  let selected = Ref("")
  let runtime = @core.AppRuntime::new_view(
    root=@views.selectable_list(
      [
        @views.SelectableListItem::new(
          id="alpha",
          title="Pipeline Alpha",
          subtitle="Healthy",
          message="alpha",
        ),
        @views.SelectableListItem::new(
          id="beta",
          title="Queue Beta",
          subtitle="Review required",
          message="beta",
        ),
      ],
      selected="alpha",
      width=360.0,
    ),
    size=@core.Size::new(width=400.0, height=180.0),
    on_message=Some(message => selected.val = message),
  )
  guard text_frame(runtime.draw_commands(), "Queue Beta") is Some(beta_frame) else {
    fail("expected selectable list item")
  }
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(
          x=beta_frame.origin.x + 4.0,
          y=beta_frame.origin.y + 4.0,
        ),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(
          x=beta_frame.origin.x + 4.0,
          y=beta_frame.origin.y + 4.0,
        ),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  inspect(selected.val, content="beta")
}

///|
test "table row selection dispatches row index" {
  let selected = Ref(-1)
  let columns = [
    @views.table_column(id="name", label="Name", width=120.0),
    @views.table_column(id="state", label="State", width=96.0),
  ]
  let runtime = @core.AppRuntime::new_view(
    root=@views.table(
      columns,
      [["Atlas", "Active"], ["Billing", "Review"]],
      on_row_select=Some(index => index),
    ),
    size=@core.Size::new(width=260.0, height=140.0),
    on_message=Some(index => selected.val = index),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=10.0, y=88.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=10.0, y=88.0),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  inspect(selected.val, content="1")
}

///|
test "selection toolbar dispatches enabled bulk action and disables empty selection" {
  let selected = Ref("")
  let runtime = @core.AppRuntime::new_view(
    root=@views.selection_toolbar(
      selected_count=2,
      total_count=4,
      actions=[
        @views.MenuItem::new(id="archive", label="Archive", message="archive"),
        @views.MenuItem::new(
          id="delete",
          label="Delete",
          message="delete",
          enabled=false,
        ),
      ],
      on_clear=Some("clear"),
      width=420.0,
    ),
    size=@core.Size::new(width=460.0, height=120.0),
    on_message=Some(message => selected.val = message),
  )
  assert_true(has_text(runtime.draw_commands(), "2 of 4 selected"))
  guard text_frame(runtime.draw_commands(), "Archive") is Some(archive_frame) else {
    fail("expected enabled bulk action")
  }
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(
          x=archive_frame.origin.x + 4.0,
          y=archive_frame.origin.y + 4.0,
        ),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(
          x=archive_frame.origin.x + 4.0,
          y=archive_frame.origin.y + 4.0,
        ),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  inspect(selected.val, content="archive")
  selected.val = ""
  let empty_runtime = @core.AppRuntime::new_view(
    root=@views.selection_toolbar(
      selected_count=0,
      actions=[
        @views.MenuItem::new(id="archive", label="Archive", message="archive"),
      ],
      on_clear=Some("clear"),
      width=420.0,
    ),
    size=@core.Size::new(width=460.0, height=120.0),
    on_message=Some(message => selected.val = message),
  )
  assert_true(has_text(empty_runtime.draw_commands(), "No rows selected"))
  guard find_semantics_label(empty_runtime.semantics(), "Selection toolbar")
    is Some(toolbar) else {
    fail("expected selection toolbar semantics")
  }
  assert_false(toolbar.state.selected)
  guard find_semantics_label(empty_runtime.semantics(), "Archive")
    is Some(empty_archive) else {
    fail("expected disabled empty selection action")
  }
  assert_true(empty_archive.state.disabled)
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
  let root : @core.View[Unit] = @views.column([
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
    @views.resizable_panel(
      content=@views.text("Resizable", width=160.0),
      size=180.0,
    ),
  ])
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
test "resizable panel drag handle emits controlled size" {
  let last_size = Ref(0.0)
  let runtime = @core.AppRuntime::new_view(
    root=@views.resizable_panel(
      content=@views.text("Drag resize", width=120.0),
      size=180.0,
      height=80.0,
      min_size=120.0,
      max_size=240.0,
      on_drag=Some(size => size),
    ),
    size=@core.Size::new(width=300.0, height=120.0),
    on_message=Some(size => last_size.val = size),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=190.0, y=12.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=210.0, y=12.0),
        phase=@core.PointerPhase::Move,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=232.0, y=12.0),
        phase=@core.PointerPhase::Move,
      ),
    ),
  )
  inspect(last_size.val, content="222")
}

///|
test "public view gesture wrappers can be composed from views" {
  let log = Ref("")
  let root = @views.surface(
      @views.text("Gesture", width=120.0),
      width=160.0,
      height=80.0,
    )
    .on_double_tap("double")
    .on_long_press("long")
    .on_drag(event => event.phase.label())
  let runtime = @core.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=200.0, height=120.0),
    on_message=Some(message => log.val = log.val + message + ";"),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=10.0, y=10.0),
        phase=@core.PointerPhase::Down,
        time_ms=0.0,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=10.0, y=10.0),
        phase=@core.PointerPhase::Up,
        time_ms=20.0,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=11.0, y=10.0),
        phase=@core.PointerPhase::Down,
        time_ms=160.0,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=11.0, y=10.0),
        phase=@core.PointerPhase::Up,
        time_ms=180.0,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=20.0, y=20.0),
        phase=@core.PointerPhase::Down,
        time_ms=400.0,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=20.0, y=20.0),
        phase=@core.PointerPhase::Move,
        time_ms=920.0,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=20.0, y=20.0),
        phase=@core.PointerPhase::Up,
        time_ms=940.0,
      ),
    ),
  )
  inspect(log.val, content="double;long;")
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
test "drop zone maps dropped files to app message" {
  let seen = Ref("")
  let root : @core.View[Array[String]] = @views.drop_zone(
    title="Drop files here",
    on_drop=paths => paths,
    width=240.0,
    height=80.0,
  )
  let runtime = @core.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=320.0, height=160.0),
    on_message=Some(paths => if paths.length() > 0 { seen.val = paths[0] }),
  )
  runtime.dispatch_event(
    @core.AppEvent::DragDrop(
      @core.DragDropEvent::new(
        phase=@core.DragDropPhase::Dropped,
        paths=["/tmp/import.csv"],
        position=Some(@core.Point::new(x=12.0, y=12.0)),
      ),
    ),
  )
  inspect(seen.val, content="/tmp/import.csv")
}

///|
test "file import panel renders empty and unavailable states" {
  let empty = @core.AppRuntime::new_view(
    root=@views.file_import_panel(
      selection=@views.FileSelection::empty(),
      on_drop=_paths => (),
      on_browse=Some(()),
      empty_message="No file chosen",
      width=320.0,
    ),
    size=@core.Size::new(width=360.0, height=280.0),
  ).draw_commands()
  assert_true(has_text(empty, "No file chosen"))
  assert_true(has_text(empty, "Browse"))

  let unavailable = @core.AppRuntime::new_view(
    root=@views.file_import_panel(
      selection=@views.FileSelection::new(paths=["/tmp/a.txt"]),
      on_drop=_paths => (),
      availability=@views.FileImportAvailability::Unavailable(
        "File dialog unavailable",
      ),
      width=320.0,
    ),
    size=@core.Size::new(width=360.0, height=280.0),
  ).draw_commands()
  assert_true(has_text(unavailable, "File dialog unavailable"))
  assert_true(has_text(unavailable, "/tmp/a.txt"))
}

///|
test "menu bar and command menu render enabled disabled items" {
  let sections = [
    @views.CommandMenuSection::new(title="File", commands=[
      @core.ActionCommand::new(intent=@core.CommandIntent::Submit, label="Save"),
      @core.ActionCommand::new(
        intent=@core.CommandIntent::Cancel,
        label="Close",
        enabled=false,
      ),
    ]),
  ]
  let runtime = test_runtime(
    @views.column([
      @views.menu_bar(
        [
          @views.MenuItem::new(id="file", label="File", message=()),
          @views.MenuItem::new(
            id="edit",
            label="Edit",
            message=(),
            enabled=false,
          ),
        ],
        active="file",
      ),
      @views.command_menu(sections, on_select=_intent => (), width=280.0),
    ]),
  )
  let draw = runtime.draw_commands()
  assert_true(has_text(draw, "File"))
  assert_true(has_text(draw, "Edit"))
  assert_true(has_text(draw, "Save"))
  assert_true(has_text(draw, "Close"))
  let semantics = runtime.semantics()
  guard find_semantics_label(semantics, "Menu bar") is Some(menu_bar) else {
    fail("expected menu bar semantics")
  }
  assert_true(menu_bar.role == @core.SemanticsRole::Menu)
  guard find_semantics_label(semantics, "File") is Some(file) else {
    fail("expected selected menu item")
  }
  assert_true(file.state.selected)
  guard find_semantics_label(semantics, "Edit") is Some(edit) else {
    fail("expected disabled menu item")
  }
  assert_true(edit.state.disabled)
  guard find_semantics_label(semantics, "Command menu") is Some(command_menu) else {
    fail("expected command menu semantics")
  }
  assert_true(command_menu.role == @core.SemanticsRole::Menu)
}

///|
test "command menu dispatches enabled command and ignores disabled command" {
  let selected = Ref("")
  let sections = [
    @views.CommandMenuSection::new(title="", commands=[
      @core.ActionCommand::new(intent=@core.CommandIntent::Submit, label="Save"),
      @core.ActionCommand::new(
        intent=@core.CommandIntent::Cancel,
        label="Cancel",
        enabled=false,
      ),
    ]),
  ]
  let runtime = @core.AppRuntime::new_view(
    root=@views.command_menu(sections, on_select=intent => intent, width=280.0),
    size=@core.Size::new(width=320.0, height=220.0),
    on_message=Some(intent => selected.val = intent.display_label()),
  )
  guard text_frame(runtime.draw_commands(), "Save") is Some(save_frame) else {
    fail("expected enabled command row")
  }
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(
          x=save_frame.origin.x + 4.0,
          y=save_frame.origin.y + 4.0,
        ),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(
          x=save_frame.origin.x + 4.0,
          y=save_frame.origin.y + 4.0,
        ),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  inspect(selected.val, content="Submit")
  selected.val = ""
  guard text_frame(runtime.draw_commands(), "Cancel") is Some(cancel_frame) else {
    fail("expected disabled command row")
  }
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(
          x=cancel_frame.origin.x + 4.0,
          y=cancel_frame.origin.y + 4.0,
        ),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(
          x=cancel_frame.origin.x + 4.0,
          y=cancel_frame.origin.y + 4.0,
        ),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  inspect(selected.val, content="")
}

///|
test "context menu region can render fallback view menu" {
  let runtime = test_runtime(
    @views.context_menu_region(
      child=@views.text("Region"),
      menu=@views.command_menu(
        [
          @views.CommandMenuSection::new(title="Actions", commands=[
            @core.ActionCommand::new(
              intent=@core.CommandIntent::Copy,
              label="Copy Item",
            ),
          ]),
        ],
        on_select=_intent => (),
        width=240.0,
      ),
      visible=true,
    ),
  )
  let draw = runtime.draw_commands()
  assert_true(has_text(draw, "Region"))
  assert_true(has_text(draw, "Copy Item"))
  let semantics = runtime.semantics()
  guard find_semantics_label(semantics, "Context menu region") is Some(node) else {
    fail("expected context menu region semantics")
  }
  assert_true(node.state.expanded)
  assert_true(
    node.actions.any(action => action == @core.SemanticsAction::Collapse),
  )
  let hidden_runtime = test_runtime(
    @views.context_menu_region(
      child=@views.text("Region"),
      menu=@views.command_menu(
        [
          @views.CommandMenuSection::new(title="Actions", commands=[
            @core.ActionCommand::new(
              intent=@core.CommandIntent::Copy,
              label="Copy Item",
            ),
          ]),
        ],
        on_select=_intent => (),
        width=240.0,
      ),
      visible=false,
    ),
  )
  guard find_semantics_label(hidden_runtime.semantics(), "Context menu region")
    is Some(hidden_node) else {
    fail("expected hidden context menu region semantics")
  }
  assert_false(hidden_node.state.expanded)
  assert_true(
    hidden_node.actions.any(action => action == @core.SemanticsAction::Expand),
  )
}

///|
fn has_text(commands : Array[@core.DrawCommand], text : String) -> Bool {
  commands.any(command => {
    command is @core.DrawCommand::DrawText({ text: value, .. }) && value == text
  })
}

///|
fn text_frame(
  commands : Array[@core.DrawCommand],
  text : String,
) -> @core.Rect? {
  for command in commands {
    match command {
      @core.DrawCommand::DrawText({ text: value, frame, .. }) =>
        if value == text {
          return Some(frame)
        }
      _ => ()
    }
  }
  None
}

///|
fn find_semantics_label(
  node : @core.SemanticsNode,
  label : String,
) -> @core.SemanticsNode? {
  if node.label == label {
    Some(node)
  } else {
    for child in node.children {
      match find_semantics_label(child, label) {
        Some(found) => return Some(found)
        None => ()
      }
    }
    None
  }
}
