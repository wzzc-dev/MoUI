///|
fn test_label(text : String, key? : String) -> ViewSpec {
  let spec = ViewSpec::TextSpec({
    key: None,
    text,
    size: Size::new(width=80.0, height=20.0),
    font: FontSpec::new(size=16.0, weight=500),
    color: Color::black(),
  })
  match key {
    Some(key) => spec.key(key)
    None => spec
  }
}

///|
fn test_text_field(
  value : Binding[String],
  on_submit? : (() -> Unit)? = None,
) -> ViewSpec {
  ViewSpec::TextFieldSpec({
    key: None,
    value,
    placeholder: "Type",
    size: Size::new(width=120.0, height=40.0),
    font: FontSpec::new(size=16.0, weight=400),
    foreground: Color::black(),
    placeholder_color: Color::gray(),
    background: Brush::solid(Color::white()),
    border: Some(BorderStyle::new(brush=Brush::solid(Color::gray()), width=1.0)),
    focused_border: Some(
      BorderStyle::new(brush=Brush::solid(Color::blue()), width=2.0),
    ),
    cursor_color: Color::blue(),
    corner_radius: 0.0,
    on_submit,
  })
}

///|
fn test_tab_accepting_rich_text_editor(value : Binding[String]) -> ViewSpec {
  ViewSpec::RichTextEditorSpec({
    key: None,
    value,
    placeholder: "Write",
    size: Size::new(width=160.0, height=80.0),
    format: value => RichTextDocument::plain(value),
    font: FontSpec::new(size=16.0, weight=400),
    foreground: Color::black(),
    placeholder_color: Color::gray(),
    background: Brush::solid(Color::white()),
    border: None,
    focused_border: None,
    cursor_color: Color::blue(),
    corner_radius: 0.0,
    on_selection_change: None,
    on_prefix_click: None,
    input_transform: None,
    accepts_tab_input: true,
  })
}

///|
fn test_selection_highlight_color(commands : Array[DrawCommand]) -> Color? {
  for command in commands {
    match command {
      FillRect(_, color) => if color.a == 0.18 { return Some(color) }
      _ => ()
    }
  }
  None
}

///|
fn test_text_field_caret_rect(commands : Array[DrawCommand]) -> Rect? {
  for command in commands {
    match command {
      FillRect(rect, _) => if rect.size.width == 1.5 { return Some(rect) }
      _ => ()
    }
  }
  None
}

///|
fn test_draw_text_frame(commands : Array[DrawCommand], text : String) -> Rect? {
  for command in commands {
    match command {
      DrawText({ text: value, frame, .. }) =>
        if value == text {
          return Some(frame)
        }
      _ => ()
    }
  }
  None
}

///|
test "engine mounts view spec into element and render trees" {
  let spec = ViewSpec::FlexSpec({
    key: None,
    axis: Axis::Vertical,
    spacing: 4.0,
    main_axis_alignment: MainStart,
    cross_axis_alignment: CrossStretch,
    children: [test_label("A"), test_label("B")],
  })
  let element = mount_view_spec(spec)
  inspect(element.children.length(), content="2")
  let render = element.render(Rect::new(x=0.0, y=0.0, width=100.0, height=80.0))
  inspect(render.children.length(), content="2")
  inspect(render.children[1].frame.origin.y, content="24")
}

///|
test "custom layout participates in focus hit testing" {
  let text = State::new("abc")
  let editor = ViewSpec::RichTextEditorSpec({
    key: None,
    value: text.binding(),
    placeholder: "Write",
    size: Size::new(width=160.0, height=80.0),
    format: value => RichTextDocument::plain(value),
    font: FontSpec::new(size=16.0, weight=400),
    foreground: Color::black(),
    placeholder_color: Color::gray(),
    background: Brush::solid(Color::white()),
    border: None,
    focused_border: None,
    cursor_color: Color::blue(),
    corner_radius: 0.0,
    on_selection_change: None,
    on_prefix_click: None,
    input_transform: None,
    accepts_tab_input: false,
  })
  let overlay = test_label("tools")
  let spec = ViewSpec::custom_layout(
    children=[editor, overlay],
    measure=_ => Size::new(width=160.0, height=80.0),
    place=ctx => {
      [
        Rect::new(
          x=ctx.frame.origin.x,
          y=ctx.frame.origin.y,
          width=160.0,
          height=80.0,
        ),
        Rect::new(
          x=ctx.frame.origin.x,
          y=ctx.frame.origin.y + 56.0,
          width=80.0,
          height=20.0,
        ),
      ]
    },
  )
  let element = mount_view_spec(spec)
  let render = element.render(Rect::new(x=0.0, y=0.0, width=160.0, height=80.0))
  assert_true(
    element.find_focusable_at(Point::new(x=10.0, y=10.0), render) is Some(_),
  )
}

///|
test "custom overlay miss falls through to active editor" {
  let text = State::new("abc")
  let editor = ViewSpec::RichTextEditorSpec({
    key: None,
    value: text.binding(),
    placeholder: "Write",
    size: Size::new(width=160.0, height=80.0),
    format: value => RichTextDocument::plain(value),
    font: FontSpec::new(size=16.0, weight=400),
    foreground: Color::black(),
    placeholder_color: Color::gray(),
    background: Brush::solid(Color::white()),
    border: None,
    focused_border: None,
    cursor_color: Color::blue(),
    corner_radius: 0.0,
    on_selection_change: None,
    on_prefix_click: None,
    input_transform: None,
    accepts_tab_input: false,
  })
  let overlay = test_label("tools")
  let spec = ViewSpec::custom_layout(
    children=[editor, overlay],
    measure=_ => Size::new(width=160.0, height=80.0),
    place=ctx => {
      [
        Rect::new(
          x=ctx.frame.origin.x,
          y=ctx.frame.origin.y,
          width=160.0,
          height=80.0,
        ),
        Rect::new(
          x=ctx.frame.origin.x,
          y=ctx.frame.origin.y,
          width=160.0,
          height=80.0,
        ),
      ]
    },
  )
  let element = mount_view_spec(spec)
  let render = element.render(Rect::new(x=0.0, y=0.0, width=160.0, height=80.0))
  let result = element.dispatch_pointer(
    PointerEvent::new(
      position=Point::new(x=10.0, y=10.0),
      phase=PointerPhase::Down,
    ),
    render,
  )
  assert_true(result.focused is Some(_))
}

///|
test "engine applies flex main and cross axis alignment" {
  let spec = ViewSpec::FlexSpec({
    key: None,
    axis: Axis::Vertical,
    spacing: 0.0,
    main_axis_alignment: MainCenter,
    cross_axis_alignment: CrossEnd,
    children: [test_label("A")],
  })
  let render = mount_view_spec(spec).render(
    Rect::new(x=0.0, y=0.0, width=100.0, height=100.0),
  )
  inspect(render.children[0].frame.origin.x, content="20")
  inspect(render.children[0].frame.origin.y, content="40")
  inspect(render.children[0].frame.size.width, content="80")
  inspect(render.children[0].frame.size.height, content="20")
}

///|
test "engine allocates remaining flex space to spacers" {
  let spec = ViewSpec::FlexSpec({
    key: None,
    axis: Axis::Horizontal,
    spacing: 0.0,
    main_axis_alignment: MainStart,
    cross_axis_alignment: CrossStretch,
    children: [
      test_label("A"),
      ViewSpec::SpacerSpec({ key: None, min_length: 0.0, weight: 1.0 }),
      test_label("B"),
    ],
  })
  let render = mount_view_spec(spec).render(
    Rect::new(x=0.0, y=0.0, width=240.0, height=40.0),
  )
  inspect(render.children[1].frame.size.width, content="80")
  inspect(render.children[2].frame.origin.x, content="160")
}

///|
test "engine allocates flex spacer space by weight" {
  let spec = ViewSpec::FlexSpec({
    key: None,
    axis: Axis::Horizontal,
    spacing: 0.0,
    main_axis_alignment: MainStart,
    cross_axis_alignment: CrossStretch,
    children: [
      ViewSpec::SpacerSpec({ key: None, min_length: 0.0, weight: 1.0 }),
      ViewSpec::SpacerSpec({ key: None, min_length: 0.0, weight: 3.0 }),
    ],
  })
  let render = mount_view_spec(spec).render(
    Rect::new(x=0.0, y=0.0, width=200.0, height=20.0),
  )
  inspect(render.children[0].frame.size.width, content="50")
  inspect(render.children[1].frame.origin.x, content="50")
  inspect(render.children[1].frame.size.width, content="150")
}

///|
test "frame spec constrains child layout" {
  let spec = test_label("A").frame(width=90.0, height=30.0)
  let layout = layout_spec(
    spec,
    Rect::new(x=0.0, y=0.0, width=200.0, height=100.0),
  )
  inspect(layout.children[0].frame.size.width, content="90")
  inspect(layout.children[0].frame.size.height, content="30")
}

///|
test "engine reconciles keyed children by identity" {
  let old = mount_view_spec(
    ViewSpec::FlexSpec({
      key: None,
      axis: Axis::Vertical,
      spacing: 0.0,
      main_axis_alignment: MainStart,
      cross_axis_alignment: CrossStretch,
      children: [test_label("A", key="a"), test_label("B", key="b")],
    }),
  )
  let old_a = old.children[0].id
  let old_b = old.children[1].id
  let next = reconcile_element(
    old,
    ViewSpec::FlexSpec({
      key: None,
      axis: Axis::Vertical,
      spacing: 0.0,
      main_axis_alignment: MainStart,
      cross_axis_alignment: CrossStretch,
      children: [test_label("B", key="b"), test_label("A", key="a")],
    }),
  )
  assert_true(next.children[0].id == old_b)
  assert_true(next.children[1].id == old_a)
}

///|
test "runtime exposes mount rebuild layout and paint passes" {
  let runtime = RuntimeState::new_spec(
    root=test_label("A"),
    size=Size::new(width=100.0, height=40.0),
  )
  runtime.mount(test_label("B"))
  guard runtime.paint_pass() is [_, DrawText({ text: "B", .. })] else {
    fail("expected mounted label")
  }
  runtime.root_spec = test_label("C")
  runtime.needs_rebuild = true
  runtime.rebuild()
  guard runtime.paint_pass() is [_, DrawText({ text: "C", .. })] else {
    fail("expected rebuilt label")
  }
  runtime.dispatch_event(Resize(Size::new(width=120.0, height=60.0)))
  inspect(runtime.needs_layout, content="true")
  runtime.layout_pass()
  inspect(runtime.needs_layout, content="false")
}

///|
test "state slot version increments on set and update" {
  let slot = StateSlot::new(1)
  inspect(slot.version, content="0")
  slot.set(2)
  inspect(slot.get(), content="2")
  inspect(slot.version, content="1")
  slot.update(value => value + 1)
  inspect(slot.get(), content="3")
  inspect(slot.version, content="2")
}

///|
test "state and binding share updates" {
  let state = State::new(1)
  let binding = state.binding()
  binding.set(2)
  inspect(state.get(), content="2")
  binding.update(value => value + 3)
  inspect(state.get(), content="5")
  inspect(state.version(), content="2")
}

///|
test "custom binding delegates get and set" {
  let value = Ref(false)
  let binding = Binding::new(get=() => value.val, set=next => value.val = next)
  inspect(binding.get(), content="false")
  binding.set(true)
  inspect(value.val, content="true")
  binding.update(current => !current)
  inspect(value.val, content="false")
}

///|
test "image spec emits draw image command" {
  let runtime = RuntimeState::new_spec(
    root=ViewSpec::ImageSpec({
      key: None,
      source: "logo.png",
      size: Some(Size::new(width=48.0, height=32.0)),
      opacity: 0.75,
      corner_radius: 0.0,
      fit: ImageFit::Contain,
    }),
    size=Size::new(width=100.0, height=80.0),
  )
  guard runtime.build_draw_commands()
    is [
      _,
      DrawImage(
        {
          source: "logo.png",
          opacity: 0.75,
          fit: ImageFit::Contain,
          frame: { size: { width: 48.0, height: 32.0 }, .. },
        }
      ),
    ] else {
    fail("expected image draw command")
  }
}

///|
test "custom spec measures paints and exposes semantics" {
  let spec = ViewSpec::custom(
    measure=constraints => {
      constraints.constrain(Size::new(width=32.0, height=20.0))
    },
    paint=frame => {
      [
        DrawCommand::FillRoundedRectBrush(
          RoundedRect::new(rect=frame, radius=3.0),
          Brush::solid(Color::blue()),
        ),
      ]
    },
    semantics_role=SemanticsRole::Group,
    semantics_label="Custom swatch",
  ).key("custom")
  let runtime = RuntimeState::new_spec(
    root=spec,
    size=Size::new(width=80.0, height=60.0),
  )
  let measured = runtime.element_tree.measure(
    Constraints::loose(Size::new(width=40.0, height=30.0)),
  )
  inspect(measured.size.width, content="32")
  assert_true(
    runtime
    .build_draw_commands()
    .any(command => {
      command is DrawCommand::FillRoundedRectBrush(_, Brush::Solid(_))
    }),
  )
  let semantics = runtime.semantics()
  inspect(semantics.label, content="Custom swatch")
  assert_true(
    runtime.element_tree.find_keyed("custom") == Some(runtime.element_tree.id()),
  )
}

///|
test "text layout measures size baseline and caret positions" {
  let layout = TextSystem::fallback().measure_text(
    TextLayoutInput::new(
      text="abcd",
      font=FontSpec::new(size=20.0),
      max_width=30.0,
    ),
  )
  inspect(layout.size.width, content="30")
  inspect(layout.size.height, content="25")
  inspect(layout.baseline, content="16")
  inspect(layout.caret_positions.length(), content="5")
  inspect(layout.caret_positions[4], content="30")
}

///|
test "fallback text system uses deterministic fixed advances for caret positions" {
  let ascii = TextSystem::fallback().measure_text(
    TextLayoutInput::new(text="a", font=FontSpec::new(size=20.0)),
  )
  let digit = TextSystem::fallback().measure_text(
    TextLayoutInput::new(text="1234", font=FontSpec::new(size=20.0)),
  )
  let cjk = TextSystem::fallback().measure_text(
    TextLayoutInput::new(text="你", font=FontSpec::new(size=20.0)),
  )
  inspect(ascii.caret_positions[1], content="10")
  inspect(digit.caret_positions[4], content="40")
  inspect(cjk.caret_positions[1], content="10")
}

///|
test "checkbox toggles binding and exposes semantics" {
  let checked = State::new(false)
  let runtime = RuntimeState::new_spec(
    root=ViewSpec::CheckboxSpec({
      key: None,
      label: "Buy milk",
      checked: checked.binding(),
      font: FontSpec::new(size=16.0, weight=400),
      foreground: Color::black(),
      check_color: Color::blue(),
      size: Size::new(width=20.0, height=32.0),
    }),
    size=Size::new(width=180.0, height=48.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Up,
      ),
    ),
  )
  inspect(checked.get(), content="true")
  let semantics = runtime.semantics()
  assert_true(semantics.role == SemanticsRole::Checkbox)
  inspect(semantics.state.checked, content="true")
}

///|
test "dirty queue records and clears runtime work" {
  let runtime = RuntimeState::new_spec(
    root=test_label("A"),
    size=Size::new(width=100.0, height=40.0),
  )
  inspect(runtime.dirty_count(), content="0")
  runtime.mark_dirty(runtime.element_tree.id())
  runtime.mark_dirty(runtime.element_tree.id())
  inspect(runtime.dirty_count(), content="1")
  ignore(runtime.build_draw_commands())
  inspect(runtime.dirty_count(), content="0")
}

///|
test "layout pass refreshes layout tree without repainting" {
  let runtime = RuntimeState::new_spec(
    root=test_label("A"),
    size=Size::new(width=100.0, height=40.0),
  )
  runtime.dispatch_event(Resize(Size::new(width=160.0, height=50.0)))
  inspect(runtime.needs_layout, content="true")
  inspect(runtime.needs_paint, content="true")
  runtime.layout_pass()
  inspect(runtime.needs_layout, content="false")
  inspect(runtime.needs_paint, content="true")
  inspect(runtime.layout_tree.root.frame.size.width, content="160")
  inspect(runtime.layout().frame.size.width, content="160")
}

///|
test "paint only dirty reuses custom layout placement" {
  let place_count = Ref(0)
  let spec = ViewSpec::custom_layout(
    children=[
      ViewSpec::custom(measure=_ => Size::new(width=30.0, height=20.0), paint=frame => {
        [
          FillRoundedRectBrush(
            RoundedRect::new(rect=frame),
            Brush::solid(Color::blue()),
          ),
        ]
      }),
    ],
    measure=ctx => ctx.child_sizes[0],
    place=ctx => {
      place_count.val = place_count.val + 1
      [
        Rect::new(
          x=ctx.frame.origin.x + 7.0,
          y=ctx.frame.origin.y + 5.0,
          width=ctx.child_sizes[0].width,
          height=ctx.child_sizes[0].height,
        ),
      ]
    },
  )
  let runtime = RuntimeState::new_spec(
    root=spec,
    size=Size::new(width=100.0, height=60.0),
  )
  inspect(place_count.val, content="1")
  let layout = runtime.layout()
  inspect(layout.children[0].frame.origin.x, content="7")
  runtime.mark_dirty(runtime.element_tree.id())
  let commands = runtime.build_draw_commands()
  inspect(place_count.val, content="1")
  guard commands is [_, FillRoundedRectBrush({ rect: frame, .. }, _)] else {
    fail("expected child paint command")
  }
  assert_true(frame == layout.children[0].frame)
}
