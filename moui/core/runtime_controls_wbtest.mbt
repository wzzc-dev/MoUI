///|
struct ControlledTextModel {
  draft : String
  query : String
  cleared : Bool
}

///|
enum ControlledTextMsg {
  ControlledDraftChanged(String)
  ControlledQueryChanged(String)
  ControlledSearchCleared
}

///|
fn ControlledTextModel::update(
  self : ControlledTextModel,
  message : ControlledTextMsg,
) -> ControlledTextModel {
  match message {
    ControlledDraftChanged(value) => { ..self, draft: value }
    ControlledQueryChanged(value) => { ..self, query: value }
    ControlledSearchCleared => { ..self, cleared: true }
  }
}

///|
fn ControlledTextModel::view(
  self : ControlledTextModel,
) -> View[ControlledTextMsg] {
  View::flex(
    children=[
      runtime_test_label("Draft: \{self.draft}"),
      View::controlled_text_field(
        value=self.draft,
        on_input=value => ControlledDraftChanged(value),
        placeholder="Draft",
        size=Size::new(width=240.0, height=32.0),
        font=FontSpec::new(size=14.0),
        foreground=Color::black(),
        placeholder_color=Color::gray(),
        background=Brush::solid(Color::white()),
        border=None,
        focused_border=None,
        cursor_color=Color::blue(),
      ),
      runtime_test_label("Query: \{self.query} cleared \{self.cleared}"),
      View::controlled_search_bar(
        query=self.query,
        on_input=value => ControlledQueryChanged(value),
        placeholder="Search",
        font=FontSpec::new(size=14.0),
        foreground=Color::black(),
        placeholder_color=Color::gray(),
        background=Brush::solid(Color::white()),
        border=None,
        focused_border=None,
        cursor_color=Color::blue(),
        corner_radius=8.0,
        on_clear=Some(ControlledSearchCleared),
      ),
    ],
    axis=Axis::Vertical,
    spacing=4.0,
    cross_axis_alignment=CrossStart,
  )
}

///|
test "program controlled text field and searchbar update model" {
  let program = Program::simple(
    init={ draft: "", query: "abc", cleared: false },
    update=(model, message) => model.update(message),
    view=model => model.view(),
  )
  let runtime = AppRuntime::new_program(
    program~,
    size=Size::new(width=320.0, height=180.0),
  )
  runtime_wbtest_click(runtime, x=10.0, y=34.0)
  runtime.dispatch_event(AppEvent::TextInput(TextInputEvent::InsertText("Hi")))
  assert_true(has_draw_text(runtime.draw_commands(), "Draft: Hi"))
  runtime_wbtest_click(runtime, x=10.0, y=100.0)
  runtime.dispatch_event(AppEvent::TextInput(TextInputEvent::InsertText("z")))
  assert_true(
    has_draw_text(runtime.draw_commands(), "Query: abcz cleared false"),
  )
  runtime_wbtest_click(runtime, x=222.0, y=110.0)
  assert_true(has_draw_text(runtime.draw_commands(), "Query:  cleared true"))
}

///|
test "program controlled text field stays current across consecutive input events" {
  let program = Program::simple(
    init={ draft: "", query: "", cleared: false },
    update=(model, message) => model.update(message),
    view=model => model.view(),
  )
  let runtime = AppRuntime::new_program(
    program~,
    size=Size::new(width=320.0, height=180.0),
  )
  runtime_wbtest_click(runtime, x=10.0, y=34.0)
  runtime.dispatch_event(AppEvent::TextInput(TextInputEvent::InsertText("A")))
  runtime.dispatch_event(AppEvent::TextInput(TextInputEvent::InsertText("B")))
  assert_true(has_draw_text(runtime.draw_commands(), "Draft: AB"))
}

///|
test "program controlled text field rebuilds after focused text commands" {
  let program = Program::simple(
    init={ draft: "Hello", query: "abc", cleared: false },
    update=(model, message) => model.update(message),
    view=model => model.view(),
  )
  let runtime = AppRuntime::new_program(
    program~,
    size=Size::new(width=320.0, height=180.0),
  )
  runtime_wbtest_click(runtime, x=10.0, y=34.0)
  let pasted = runtime.dispatch_focused_text_command(
    Paste,
    paste_text=Some("!"),
  )
  assert_true(pasted.handled)
  assert_true(pasted.changed)
  assert_true(has_draw_text(runtime.draw_commands(), "Draft: Hello!"))
  let undo = runtime.dispatch_focused_text_command(Undo)
  assert_true(undo.handled)
  assert_true(undo.changed)
  assert_true(has_draw_text(runtime.draw_commands(), "Draft: Hello"))
  let redo = runtime.dispatch_focused_text_command(Redo)
  assert_true(redo.handled)
  assert_true(redo.changed)
  assert_true(has_draw_text(runtime.draw_commands(), "Draft: Hello!"))
}

///|
enum ControlledChoiceMsg {
  ControlledChecked(Bool)
  ControlledPicked(String)
  ControlledDated(DateValue)
}

///|
test "controlled checkbox picker and datepicker emit new value messages" {
  let enabled_program = Program::simple(
    init=false,
    update=(_model, message) => {
      match message {
        ControlledChecked(value) => value
        _ => false
      }
    },
    view=enabled => {
      View::flex(
        children=[
          runtime_test_label("Enabled: \{enabled}"),
          View::controlled_checkbox(
            label="Enabled",
            checked=enabled,
            on_change=value => ControlledChecked(value),
            font=FontSpec::new(size=14.0),
            foreground=Color::black(),
            check_color=Color::blue(),
            size=Size::new(width=20.0, height=32.0),
          ),
        ],
        axis=Axis::Vertical,
        spacing=4.0,
        cross_axis_alignment=CrossStart,
      )
    },
  )
  let enabled_runtime = AppRuntime::new_program(
    program=enabled_program,
    size=Size::new(width=240.0, height=100.0),
  )
  runtime_wbtest_click(enabled_runtime, x=10.0, y=36.0)
  assert_true(has_draw_text(enabled_runtime.draw_commands(), "Enabled: true"))

  let items = [
    PickerItem::{ id: "alpha", label: "Alpha" },
    PickerItem::{ id: "beta", label: "Beta" },
  ]
  let picker_program = Program::simple(
    init="alpha",
    update=(model, message) => {
      match message {
        ControlledPicked(value) => value
        _ => model
      }
    },
    view=selected => {
      View::flex(
        children=[
          View::controlled_picker(
            items~,
            selected~,
            on_select=value => ControlledPicked(value),
            placeholder="Select",
            font=FontSpec::new(size=14.0),
            foreground=Color::black(),
            background=Brush::solid(Color::white()),
            corner_radius=6.0,
            max_height=120.0,
          ),
        ],
        axis=Axis::Vertical,
      )
    },
  )
  let picker_runtime = AppRuntime::new_program(
    program=picker_program,
    size=Size::new(width=240.0, height=180.0),
  )
  runtime_wbtest_click(picker_runtime, x=10.0, y=10.0)
  runtime_wbtest_click(picker_runtime, x=10.0, y=90.0)
  assert_true(has_draw_text(picker_runtime.draw_commands(), "Beta"))

  let stacked_items = [
    PickerItem::{ id: "beta", label: "Beta" },
    PickerItem::{ id: "alpha", label: "Alpha" },
  ]
  let stacked_popup_program = Program::simple(
    init="alpha",
    update=(model, message) => {
      match message {
        ControlledPicked(value) => value
        _ => model
      }
    },
    view=selected => {
      View::flex(
        children=[
          View::controlled_picker(
            items=stacked_items,
            selected~,
            on_select=value => ControlledPicked(value),
            placeholder="Select",
            font=FontSpec::new(size=14.0),
            foreground=Color::black(),
            background=Brush::solid(Color::white()),
            corner_radius=6.0,
            max_height=120.0,
          ),
          View::controlled_datepicker(
            selected=DateValue::new(year=2026, month=5, day=21),
            on_select=value => ControlledDated(value),
            mode=DatePickerMode::Date,
            placeholder="Date",
            font=FontSpec::new(size=14.0),
            foreground=Color::black(),
            background=Brush::solid(Color::white()),
            corner_radius=6.0,
          ),
        ],
        axis=Axis::Vertical,
        spacing=0.0,
      )
    },
  )
  let stacked_runtime = AppRuntime::new_program(
    program=stacked_popup_program,
    size=Size::new(width=320.0, height=220.0),
  )
  runtime_wbtest_click(stacked_runtime, x=10.0, y=10.0)
  let stacked_open = stacked_runtime.draw_commands()
  assert_true(
    draw_text_index(stacked_open, "Beta") >
    draw_text_index(stacked_open, "2026-5-21"),
  )
  runtime_wbtest_click_draw_text(stacked_runtime, "Beta")
  let stacked_selected = stacked_runtime.draw_commands()
  assert_true(has_draw_text(stacked_selected, "Beta"))
  assert_false(has_draw_text(stacked_selected, "2026年5月"))

  let date_program = Program::simple(
    init=DateValue::new(year=2026, month=5, day=21),
    update=(model, message) => {
      match message {
        ControlledDated(value) => value
        _ => model
      }
    },
    view=selected => {
      View::flex(
        children=[
          View::controlled_datepicker(
            selected~,
            on_select=value => ControlledDated(value),
            mode=DatePickerMode::Date,
            placeholder="Date",
            font=FontSpec::new(size=14.0),
            foreground=Color::black(),
            background=Brush::solid(Color::white()),
            corner_radius=6.0,
          ),
        ],
        axis=Axis::Vertical,
      )
    },
  )
  let date_runtime = AppRuntime::new_program(
    program=date_program,
    size=Size::new(width=320.0, height=240.0),
  )
  runtime_wbtest_click(date_runtime, x=10.0, y=10.0)
  let open_date_commands = date_runtime.draw_commands()
  assert_true(has_draw_text(open_date_commands, "2026年5月"))
  assert_false(
    has_draw_text(open_date_commands, "{view_date.year}年{view_date.month}月"),
  )
  assert_false(has_draw_text(open_date_commands, "{day}"))
  guard draw_text_frame(open_date_commands, "五") is Some(friday_frame) else {
    fail("expected Friday header frame")
  }
  guard draw_text_frame(open_date_commands, "1") is Some(day_one_frame) else {
    fail("expected first day frame")
  }
  let day_one_center_x = day_one_frame.origin.x + day_one_frame.size.width / 2.0
  assert_true(day_one_center_x >= friday_frame.origin.x)
  assert_true(
    day_one_center_x <= friday_frame.origin.x + friday_frame.size.width,
  )
  runtime_wbtest_click_draw_text(date_runtime, "1")
  assert_true(has_draw_text(date_runtime.draw_commands(), "2026-5-1"))
}

///|
test "controlled datepicker ignores dates outside min max range" {
  let date_program = Program::simple(
    init=DateValue::new(year=2026, month=5, day=21),
    update=(model, message) => {
      match message {
        ControlledDated(value) => value
        _ => model
      }
    },
    view=selected => {
      View::flex(
        children=[
          View::controlled_datepicker(
            selected~,
            on_select=value => ControlledDated(value),
            mode=DatePickerMode::Date,
            placeholder="Date",
            font=FontSpec::new(size=14.0),
            foreground=Color::black(),
            background=Brush::solid(Color::white()),
            corner_radius=6.0,
            min_date=Some(DateValue::new(year=2026, month=5, day=10)),
            max_date=Some(DateValue::new(year=2026, month=5, day=31)),
          ),
        ],
        axis=Axis::Vertical,
      )
    },
  )
  let date_runtime = AppRuntime::new_program(
    program=date_program,
    size=Size::new(width=320.0, height=240.0),
  )
  runtime_wbtest_click(date_runtime, x=10.0, y=10.0)
  runtime_wbtest_click_draw_text(date_runtime, "1")
  assert_true(has_draw_text(date_runtime.draw_commands(), "2026-5-21"))
  runtime_wbtest_click_draw_text(date_runtime, "10")
  assert_true(has_draw_text(date_runtime.draw_commands(), "2026-5-10"))
}
