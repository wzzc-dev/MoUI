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
      View::primitive_flex_view(
        children=[
          runtime_test_label("Enabled: \{enabled}"),
          View::primitive_controlled_checkbox_view(
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
  let enabled_runtime = RuntimeKernel::new_program(
    program=enabled_program,
    size=Size::new(width=240.0, height=100.0),
  )
  runtime_wbtest_click(enabled_runtime, x=10.0, y=36.0)
  assert_true(has_draw_text(enabled_runtime.draw_commands(), "Enabled: true"))

  let items = [
    PickerItem::new(id="alpha", label="Alpha"),
    PickerItem::new(id="beta", label="Beta"),
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
      View::primitive_flex_view(
        children=[
          View::primitive_controlled_picker_view(
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
  let picker_runtime = RuntimeKernel::new_program(
    program=picker_program,
    size=Size::new(width=240.0, height=180.0),
  )
  runtime_wbtest_click(picker_runtime, x=10.0, y=10.0)
  runtime_wbtest_click(picker_runtime, x=10.0, y=90.0)
  assert_true(has_draw_text(picker_runtime.draw_commands(), "Beta"))

  let stacked_items = [
    PickerItem::new(id="beta", label="Beta"),
    PickerItem::new(id="alpha", label="Alpha"),
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
      View::primitive_flex_view(
        children=[
          View::primitive_controlled_picker_view(
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
          View::primitive_controlled_datepicker_view(
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
  let stacked_runtime = RuntimeKernel::new_program(
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
      View::primitive_flex_view(
        children=[
          View::primitive_controlled_datepicker_view(
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
  let date_runtime = RuntimeKernel::new_program(
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
      View::primitive_flex_view(
        children=[
          View::primitive_controlled_datepicker_view(
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
  let date_runtime = RuntimeKernel::new_program(
    program=date_program,
    size=Size::new(width=320.0, height=240.0),
  )
  runtime_wbtest_click(date_runtime, x=10.0, y=10.0)
  runtime_wbtest_click_draw_text(date_runtime, "1")
  assert_true(has_draw_text(date_runtime.draw_commands(), "2026-5-21"))
  runtime_wbtest_click_draw_text(date_runtime, "10")
  assert_true(has_draw_text(date_runtime.draw_commands(), "2026-5-10"))
}
