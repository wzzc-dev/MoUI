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
      FillRect(_, color) =>
        if color.a == 0.18 {
          return Some(color)
        }
      _ => ()
    }
  }
  None
}

///|
fn test_text_field_caret_rect(commands : Array[DrawCommand]) -> Rect? {
  for command in commands {
    match command {
      FillRect(rect, _) =>
        if rect.size.width == 1.5 {
          return Some(rect)
        }
      _ => ()
    }
  }
  None
}

///|
fn test_draw_text_frame(
  commands : Array[DrawCommand],
  text : String,
) -> Rect? {
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

///|
test "tap recognizer activates only pressed pointer up inside" {
  let down = recognize_button_tap(Normal, true, Down)
  assert_true(down.next_state == Pressed)
  inspect(down.activated, content="false")
  let move_inside = recognize_button_tap(Pressed, true, Move)
  assert_true(move_inside.next_state == Pressed)
  inspect(move_inside.activated, content="false")
  let up = recognize_button_tap(Pressed, true, Up)
  assert_true(up.next_state == Hovered)
  inspect(up.activated, content="true")
  let cancel = recognize_button_tap(Pressed, false, Cancel)
  assert_true(cancel.next_state == Normal)
  inspect(cancel.activated, content="false")
}

///|
test "runtime dynamic button activates after press-preserving move inside" {
  let clicks = Ref(0)
  let runtime = RuntimeState::new_component(
    root=Component::new(_ctx => {
      ViewSpec::ButtonSpec({
        key: None,
        text: "Tap \{clicks.val}",
        size: Size::new(width=100.0, height=40.0),
        font: FontSpec::new(size=16.0, weight=600),
        foreground: Color::black(),
        background: Brush::solid(Color::gray()),
        hovered_background: Brush::solid(Color::rgba(r=0.72, g=0.78, b=0.92)),
        pressed_background: Brush::solid(Color::blue()),
        border: None,
        shadow: None,
        corner_radius: 0.0,
        on_click: Some(() => clicks.val = clicks.val + 1),
      })
    }),
    size=Size::new(width=100.0, height=40.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Move,
      ),
    ),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Up,
      ),
    ),
  )
  inspect(clicks.val, content="1")
}

///|
test "active pointer capture handles no-op move without falling through siblings" {
  let spec = ViewSpec::FlexSpec({
    key: None,
    axis: Axis::Vertical,
    spacing: 4.0,
    main_axis_alignment: MainStart,
    cross_axis_alignment: CrossStart,
    children: [
      ViewSpec::ButtonSpec({
        key: None,
        text: "Bottom",
        size: Size::new(width=100.0, height=40.0),
        font: FontSpec::new(size=16.0, weight=600),
        foreground: Color::black(),
        background: Brush::solid(Color::gray()),
        hovered_background: Brush::solid(Color::rgba(r=0.72, g=0.78, b=0.92)),
        pressed_background: Brush::solid(Color::blue()),
        border: None,
        shadow: None,
        corner_radius: 0.0,
        on_click: None,
      }),
      ViewSpec::ButtonSpec({
        key: None,
        text: "Top",
        size: Size::new(width=100.0, height=40.0),
        font: FontSpec::new(size=16.0, weight=600),
        foreground: Color::black(),
        background: Brush::solid(Color::gray()),
        hovered_background: Brush::solid(Color::rgba(r=0.72, g=0.78, b=0.92)),
        pressed_background: Brush::solid(Color::blue()),
        border: None,
        shadow: None,
        corner_radius: 0.0,
        on_click: None,
      }),
    ],
  })
  let element = mount_view_spec(spec)
  let render = element.render(Rect::new(x=0.0, y=0.0, width=100.0, height=84.0))
  element.children[0].control.button_state = Pressed
  element.children[1].control.button_state = Pressed
  let result = element.dispatch_pointer(
    PointerEvent::new(position=Point::new(x=10.0, y=50.0), phase=Move),
    render,
  )
  inspect(result.changed, content="false")
  assert_true(element.children[1].control.button_state == Pressed)
  assert_true(element.children[0].control.button_state == Pressed)
}

///|
test "runtime caches active pointer capture between down and up" {
  let spec = ViewSpec::FlexSpec({
    key: None,
    axis: Axis::Vertical,
    spacing: 4.0,
    main_axis_alignment: MainStart,
    cross_axis_alignment: CrossStart,
    children: [
      ViewSpec::ButtonSpec({
        key: None,
        text: "Bottom",
        size: Size::new(width=100.0, height=40.0),
        font: FontSpec::new(size=16.0, weight=600),
        foreground: Color::black(),
        background: Brush::solid(Color::gray()),
        hovered_background: Brush::solid(Color::rgba(r=0.72, g=0.78, b=0.92)),
        pressed_background: Brush::solid(Color::blue()),
        border: None,
        shadow: None,
        corner_radius: 0.0,
        on_click: None,
      }),
      ViewSpec::ButtonSpec({
        key: None,
        text: "Top",
        size: Size::new(width=100.0, height=40.0),
        font: FontSpec::new(size=16.0, weight=600),
        foreground: Color::black(),
        background: Brush::solid(Color::gray()),
        hovered_background: Brush::solid(Color::rgba(r=0.72, g=0.78, b=0.92)),
        pressed_background: Brush::solid(Color::blue()),
        border: None,
        shadow: None,
        corner_radius: 0.0,
        on_click: None,
      }),
    ],
  })
  let runtime = RuntimeState::new_spec(
    root=spec,
    size=Size::new(width=100.0, height=84.0),
  )
  let top_id = runtime.element_tree.root.children[1].id
  runtime.dispatch_event(
    Pointer(PointerEvent::new(position=Point::new(x=10.0, y=50.0), phase=Down)),
  )
  assert_true(runtime.active_pointer_capture == Some(top_id))
  runtime.dispatch_event(
    Pointer(PointerEvent::new(position=Point::new(x=10.0, y=50.0), phase=Move)),
  )
  assert_true(runtime.active_pointer_capture == Some(top_id))
  runtime.dispatch_event(
    Pointer(PointerEvent::new(position=Point::new(x=10.0, y=50.0), phase=Up)),
  )
  assert_true(runtime.active_pointer_capture is None)
}

///|
test "runtime pointer move without cached capture does not scan stale siblings" {
  let spec = ViewSpec::FlexSpec({
    key: None,
    axis: Axis::Vertical,
    spacing: 4.0,
    main_axis_alignment: MainStart,
    cross_axis_alignment: CrossStart,
    children: [
      ViewSpec::ButtonSpec({
        key: None,
        text: "Bottom",
        size: Size::new(width=100.0, height=40.0),
        font: FontSpec::new(size=16.0, weight=600),
        foreground: Color::black(),
        background: Brush::solid(Color::gray()),
        hovered_background: Brush::solid(Color::rgba(r=0.72, g=0.78, b=0.92)),
        pressed_background: Brush::solid(Color::blue()),
        border: None,
        shadow: None,
        corner_radius: 0.0,
        on_click: None,
      }),
      ViewSpec::ButtonSpec({
        key: None,
        text: "Top",
        size: Size::new(width=100.0, height=40.0),
        font: FontSpec::new(size=16.0, weight=600),
        foreground: Color::black(),
        background: Brush::solid(Color::gray()),
        hovered_background: Brush::solid(Color::rgba(r=0.72, g=0.78, b=0.92)),
        pressed_background: Brush::solid(Color::blue()),
        border: None,
        shadow: None,
        corner_radius: 0.0,
        on_click: None,
      }),
    ],
  })
  let runtime = RuntimeState::new_spec(
    root=spec,
    size=Size::new(width=100.0, height=84.0),
  )
  runtime.element_tree.root.children[0].control.button_state = Pressed
  runtime.dispatch_event(
    Pointer(PointerEvent::new(position=Point::new(x=10.0, y=50.0), phase=Move)),
  )
  assert_true(
    runtime.element_tree.root.children[0].control.button_state == Pressed,
  )
}

///|
test "button pressed paint keeps configured foreground" {
  let runtime = RuntimeState::new_spec(
    root=ViewSpec::ButtonSpec({
      key: None,
      text: "Ghost",
      size: Size::new(width=100.0, height=40.0),
      font: FontSpec::new(size=16.0, weight=600),
      foreground: Color::black(),
      background: Brush::solid(Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0)),
      hovered_background: Brush::solid(Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0)),
      pressed_background: Brush::solid(Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0)),
      border: None,
      shadow: None,
      corner_radius: 0.0,
      on_click: None,
    }),
    size=Size::new(width=100.0, height=40.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  guard runtime.build_draw_commands()
    is [_, _, DrawText({ text: "Ghost", color, .. })] else {
    fail("expected pressed button text")
  }
  assert_true(color == Color::black())
}

///|
test "runtime dynamic builder rebuilds on draw frame flush after activated pointer" {
  let clicks = Ref(0)
  let runtime = RuntimeState::new_component(
    root=Component::new(_ctx => {
      ViewSpec::ButtonSpec({
        key: None,
        text: "Tap \{clicks.val}",
        size: Size::new(width=100.0, height=40.0),
        font: FontSpec::new(size=16.0, weight=600),
        foreground: Color::black(),
        background: Brush::solid(Color::gray()),
        hovered_background: Brush::solid(Color::rgba(r=0.72, g=0.78, b=0.92)),
        pressed_background: Brush::solid(Color::blue()),
        border: None,
        shadow: None,
        corner_radius: 0.0,
        on_click: Some(() => clicks.val = clicks.val + 1),
      })
    }),
    size=Size::new(width=100.0, height=40.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Up,
      ),
    ),
  )
  inspect(clicks.val, content="1")
  inspect(runtime.needs_rebuild, content="true")
  guard runtime.build_draw_commands() is [_, _, DrawText({ text: "Tap 1", .. })] else {
    fail("expected rebuilt button label")
  }
  inspect(runtime.needs_rebuild, content="false")
}

///|
test "hit test path records root to topmost leaf" {
  let root = ViewSpec::StackSpec({
    key: None,
    children: [test_label("Bottom", key="bottom"), test_label("Top", key="top")],
  })
  let element = mount_view_spec(root)
  let render = element.render(Rect::new(x=0.0, y=0.0, width=100.0, height=40.0))
  let path = element.hit_test_path(Point::new(x=10.0, y=10.0), render).path
  inspect(path.length(), content="2")
  assert_true(path[0].element_id == element.id)
  assert_true(path[1].element_id == element.children[1].id)
  inspect(path[1].local_position.x, content="10")
}

///|
test "runtime focuses text field and keyboard edits binding" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_text_field(state.binding()),
    size=Size::new(width=160.0, height=60.0),
  )
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="a", text=Some("a"))))
  inspect(state.get(), content="")
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="a", text=Some("a"))))
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="b", text=Some("b"))))
  inspect(state.get(), content="ab")
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Backspace")))
  inspect(state.get(), content="a")
}

///|
test "text field submit is triggered by enter" {
  let state = State::new("Task")
  let submits = Ref(0)
  let runtime = RuntimeState::new_spec(
    root=test_text_field(
      state.binding(),
      on_submit=Some(() => submits.val = submits.val + 1),
    ),
    size=Size::new(width=160.0, height=60.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Enter")))
  inspect(submits.val, content="1")
  inspect(state.get(), content="Task")
}

///|
test "clicking outside text field clears focus" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=ViewSpec::FlexSpec({
      key: None,
      axis: Axis::Vertical,
      spacing: 8.0,
      main_axis_alignment: MainStart,
      cross_axis_alignment: CrossStretch,
      children: [
        test_text_field(state.binding()),
        ViewSpec::ButtonSpec({
          key: None,
          text: "Outside",
          size: Size::new(width=120.0, height=40.0),
          font: FontSpec::new(size=16.0, weight=600),
          foreground: Color::black(),
          background: Brush::solid(Color::gray()),
          hovered_background: Brush::solid(Color::rgba(r=0.72, g=0.78, b=0.92)),
          pressed_background: Brush::solid(Color::blue()),
          border: None,
          shadow: None,
          corner_radius: 0.0,
          on_click: None,
        }),
      ],
    }),
    size=Size::new(width=160.0, height=120.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="a", text=Some("a"))))
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=58.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="b", text=Some("b"))))
  inspect(state.get(), content="a")
}

///|
test "pointer dispatch chooses topmost overlapping child" {
  let bottom_clicks = Ref(0)
  let top_clicks = Ref(0)
  let runtime = RuntimeState::new_spec(
    root=ViewSpec::FlexSpec({
      key: None,
      axis: Axis::Vertical,
      spacing: -40.0,
      main_axis_alignment: MainStart,
      cross_axis_alignment: CrossStart,
      children: [
        ViewSpec::ButtonSpec({
          key: None,
          text: "Bottom",
          size: Size::new(width=120.0, height=60.0),
          font: FontSpec::new(size=16.0, weight=600),
          foreground: Color::black(),
          background: Brush::solid(Color::gray()),
          hovered_background: Brush::solid(Color::gray()),
          pressed_background: Brush::solid(Color::blue()),
          border: None,
          shadow: None,
          corner_radius: 0.0,
          on_click: Some(() => bottom_clicks.val = bottom_clicks.val + 1),
        }),
        ViewSpec::ButtonSpec({
          key: None,
          text: "Top",
          size: Size::new(width=120.0, height=60.0),
          font: FontSpec::new(size=16.0, weight=600),
          foreground: Color::black(),
          background: Brush::solid(Color::gray()),
          hovered_background: Brush::solid(Color::gray()),
          pressed_background: Brush::solid(Color::blue()),
          border: None,
          shadow: None,
          corner_radius: 0.0,
          on_click: Some(() => top_clicks.val = top_clicks.val + 1),
        }),
      ],
    }),
    size=Size::new(width=160.0, height=120.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=30.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=30.0),
        phase=PointerPhase::Up,
      ),
    ),
  )
  inspect(bottom_clicks.val, content="0")
  inspect(top_clicks.val, content="1")
}

///|
test "tab traverses text field focus forward and backward" {
  let first = State::new("")
  let second = State::new("")
  let runtime = RuntimeState::new_spec(
    root=ViewSpec::FlexSpec({
      key: None,
      axis: Axis::Vertical,
      spacing: 8.0,
      main_axis_alignment: MainStart,
      cross_axis_alignment: CrossStretch,
      children: [
        test_text_field(first.binding()),
        test_text_field(second.binding()),
      ],
    }),
    size=Size::new(width=160.0, height=120.0),
  )
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Tab")))
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="a", text=Some("a"))))
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Tab")))
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="b", text=Some("b"))))
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(key="Tab", modifiers=KeyModifiers::new(shift=true)),
    ),
  )
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="c", text=Some("c"))))
  inspect(first.get(), content="ac")
  inspect(second.get(), content="b")
}

///|
test "focus trap constrains tab traversal to trapped subtree" {
  let outside = State::new("")
  let first = State::new("")
  let second = State::new("")
  let after = State::new("")
  let trap = ViewSpec::FlexSpec({
    key: None,
    axis: Axis::Vertical,
    spacing: 8.0,
    main_axis_alignment: MainStart,
    cross_axis_alignment: CrossStretch,
    children: [
      test_text_field(first.binding()),
      test_text_field(second.binding()),
    ],
  }).focus_trap()
  let runtime = RuntimeState::new_spec(
    root=ViewSpec::FlexSpec({
      key: None,
      axis: Axis::Vertical,
      spacing: 8.0,
      main_axis_alignment: MainStart,
      cross_axis_alignment: CrossStretch,
      children: [
        test_text_field(outside.binding()),
        trap,
        test_text_field(after.binding()),
      ],
    }),
    size=Size::new(width=160.0, height=220.0),
  )
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Tab")))
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="a", text=Some("a"))))
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Tab")))
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="b", text=Some("b"))))
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Tab")))
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="c", text=Some("c"))))
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(key="Tab", modifiers=KeyModifiers::new(shift=true)),
    ),
  )
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="d", text=Some("d"))))
  inspect(outside.get(), content="")
  inspect(first.get(), content="ac")
  inspect(second.get(), content="bd")
  inspect(after.get(), content="")
}

///|
test "focus key targets keyed focusable elements" {
  let first = State::new("")
  let second = State::new("")
  let runtime = AppRuntime::new_spec(
    root=ViewSpec::FlexSpec({
      key: None,
      axis: Axis::Vertical,
      spacing: 8.0,
      main_axis_alignment: MainStart,
      cross_axis_alignment: CrossStretch,
      children: [
        test_text_field(first.binding()).key("first"),
        test_text_field(second.binding()).key("second"),
      ],
    }),
    size=Size::new(width=160.0, height=120.0),
  )
  assert_true(runtime.focus_key("second"))
  runtime.dispatch_event(AppEvent::TextInput(TextInputEvent::InsertText("b")))
  assert_true(runtime.focus_key("first"))
  runtime.dispatch_event(AppEvent::TextInput(TextInputEvent::InsertText("a")))
  inspect(first.get(), content="a")
  inspect(second.get(), content="b")
}

///|
test "focus key respects active focus trap" {
  let outside = State::new("")
  let trapped = State::new("")
  let runtime = AppRuntime::new_spec(
    root=ViewSpec::FlexSpec({
      key: None,
      axis: Axis::Vertical,
      spacing: 8.0,
      main_axis_alignment: MainStart,
      cross_axis_alignment: CrossStretch,
      children: [
        test_text_field(outside.binding()).key("outside"),
        ViewSpec::FlexSpec({
          key: None,
          axis: Axis::Vertical,
          spacing: 8.0,
          main_axis_alignment: MainStart,
          cross_axis_alignment: CrossStretch,
          children: [test_text_field(trapped.binding()).key("trapped")],
        }).focus_trap(),
      ],
    }),
    size=Size::new(width=160.0, height=120.0),
  )
  assert_true(runtime.focus_key("trapped"))
  assert_false(runtime.focus_key("outside"))
  runtime.dispatch_event(AppEvent::TextInput(TextInputEvent::InsertText("x")))
  inspect(outside.get(), content="")
  inspect(trapped.get(), content="x")
}

///|
test "focus trap overrides tab accepting focus outside trapped subtree" {
  let outside = State::new("")
  let trapped = State::new("")
  let root_without_trap = ViewSpec::FlexSpec({
    key: None,
    axis: Axis::Vertical,
    spacing: 8.0,
    main_axis_alignment: MainStart,
    cross_axis_alignment: CrossStretch,
    children: [
      test_tab_accepting_rich_text_editor(outside.binding()),
      test_text_field(trapped.binding()),
    ],
  })
  let root_with_trap = ViewSpec::FlexSpec({
    key: None,
    axis: Axis::Vertical,
    spacing: 8.0,
    main_axis_alignment: MainStart,
    cross_axis_alignment: CrossStretch,
    children: [
      test_tab_accepting_rich_text_editor(outside.binding()),
      test_text_field(trapped.binding()).focus_trap(),
    ],
  })
  let runtime = RuntimeState::new_spec(
    root=root_without_trap,
    size=Size::new(width=180.0, height=140.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(TextInput(TextInputEvent::InsertText("x")))
  runtime.set_root_spec(root_with_trap)
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Tab")))
  runtime.dispatch_event(TextInput(TextInputEvent::InsertText("a")))
  inspect(outside.get(), content="x")
  inspect(trapped.get(), content="a")
}

///|
test "focus trap constrains pointer focus to trapped subtree" {
  let outside = State::new("")
  let first = State::new("")
  let second = State::new("")
  let after = State::new("")
  let trap = ViewSpec::FlexSpec({
    key: None,
    axis: Axis::Vertical,
    spacing: 8.0,
    main_axis_alignment: MainStart,
    cross_axis_alignment: CrossStretch,
    children: [
      test_text_field(first.binding()),
      test_text_field(second.binding()),
    ],
  }).focus_trap()
  let runtime = RuntimeState::new_spec(
    root=ViewSpec::FlexSpec({
      key: None,
      axis: Axis::Vertical,
      spacing: 8.0,
      main_axis_alignment: MainStart,
      cross_axis_alignment: CrossStretch,
      children: [
        test_text_field(outside.binding()),
        trap,
        test_text_field(after.binding()),
      ],
    }),
    size=Size::new(width=160.0, height=220.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=160.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(TextInput(TextInputEvent::InsertText("a")))
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(TextInput(TextInputEvent::InsertText("b")))
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=104.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(TextInput(TextInputEvent::InsertText("c")))
  inspect(outside.get(), content="")
  inspect(first.get(), content="ab")
  inspect(second.get(), content="c")
  inspect(after.get(), content="")
}

///|
test "text input events edit at caret and support delete ranges" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_text_field(state.binding()),
    size=Size::new(width=160.0, height=60.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(TextInput(InsertText("abc")))
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="ArrowLeft")))
  runtime.dispatch_event(TextInput(InsertText("Z")))
  inspect(state.get(), content="abZc")
  runtime.dispatch_event(TextInput(DeleteRange(TextRange::new(start=1, end=2))))
  inspect(state.get(), content="aZc")
}

///|
test "text field keyboard selection replaces and deletes ranges" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_text_field(state.binding()),
    size=Size::new(width=160.0, height=60.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(TextInput(InsertText("abcd")))
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(
        key="ArrowLeft",
        modifiers=KeyModifiers::new(shift=true),
      ),
    ),
  )
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(
        key="ArrowLeft",
        modifiers=KeyModifiers::new(shift=true),
      ),
    ),
  )
  let input = runtime.focused_text_input()
  inspect(input.caret, content="2")
  match input.selection {
    Some(selection) => {
      inspect(selection.normalized().start, content="2")
      inspect(selection.normalized().end, content="4")
    }
    None => fail("expected selection")
  }
  runtime.dispatch_event(TextInput(InsertText("X")))
  inspect(state.get(), content="abX")
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Home")))
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(key="End", modifiers=KeyModifiers::new(shift=true)),
    ),
  )
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Backspace")))
  inspect(state.get(), content="")
}

///|
test "text field select all shortcut replaces unicode text" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_text_field(state.binding()),
    size=Size::new(width=160.0, height=60.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(TextInput(InsertText("你好abc")))
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(key="a", modifiers=KeyModifiers::new(meta=true)),
    ),
  )
  let input = runtime.focused_text_input()
  inspect(input.caret, content="5")
  match input.selection {
    Some(selection) => {
      inspect(selection.normalized().start, content="0")
      inspect(selection.normalized().end, content="5")
    }
    None => fail("expected select all range")
  }
  runtime.dispatch_event(TextInput(InsertText("done")))
  inspect(state.get(), content="done")
}

///|
test "text field command undo and redo restore edit history" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_text_field(state.binding()),
    size=Size::new(width=160.0, height=60.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(TextInput(InsertText("a")))
  runtime.dispatch_event(TextInput(InsertText("b")))
  inspect(state.get(), content="ab")
  let undo = runtime.dispatch_focused_text_command(Undo)
  assert_true(undo.handled)
  assert_true(undo.changed)
  inspect(state.get(), content="a")
  let redo = runtime.dispatch_focused_text_command(Redo)
  assert_true(redo.handled)
  assert_true(redo.changed)
  inspect(state.get(), content="ab")
}

///|
test "text field undo and redo restore edit caret" {
  let state = State::new("abcd")
  let runtime = RuntimeState::new_spec(
    root=test_text_field(state.binding()),
    size=Size::new(width=160.0, height=60.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Home")))
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="ArrowRight")))
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="ArrowRight")))
  inspect(runtime.focused_text_input().caret, content="2")
  runtime.dispatch_event(TextInput(InsertText("X")))
  inspect(state.get(), content="abXcd")
  inspect(runtime.focused_text_input().caret, content="3")
  let undo = runtime.dispatch_focused_text_command(Undo)
  assert_true(undo.handled)
  assert_true(undo.changed)
  inspect(state.get(), content="abcd")
  inspect(runtime.focused_text_input().caret, content="2")
  let redo = runtime.dispatch_focused_text_command(Redo)
  assert_true(redo.handled)
  assert_true(redo.changed)
  inspect(state.get(), content="abXcd")
  inspect(runtime.focused_text_input().caret, content="3")
}

///|
test "text field can undo multiple edits without replaying restored states" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_text_field(state.binding()),
    size=Size::new(width=160.0, height=60.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(TextInput(InsertText("a")))
  runtime.dispatch_event(TextInput(InsertText("b")))
  runtime.dispatch_event(TextInput(InsertText("c")))
  inspect(state.get(), content="abc")
  ignore(runtime.dispatch_focused_text_command(Undo))
  inspect(state.get(), content="ab")
  ignore(runtime.dispatch_focused_text_command(Undo))
  inspect(state.get(), content="a")
  ignore(runtime.dispatch_focused_text_command(Undo))
  inspect(state.get(), content="")
  ignore(runtime.dispatch_focused_text_command(Redo))
  inspect(state.get(), content="a")
  ignore(runtime.dispatch_focused_text_command(Redo))
  inspect(state.get(), content="ab")
  ignore(runtime.dispatch_focused_text_command(Redo))
  inspect(state.get(), content="abc")
}

///|
test "text field undo restores previous selection" {
  let state = State::new("abcd")
  let runtime = RuntimeState::new_spec(
    root=test_text_field(state.binding()),
    size=Size::new(width=160.0, height=60.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(key="a", modifiers=KeyModifiers::new(meta=true)),
    ),
  )
  runtime.dispatch_event(TextInput(InsertText("done")))
  inspect(state.get(), content="done")
  let undo = runtime.dispatch_focused_text_command(Undo)
  assert_true(undo.handled)
  inspect(state.get(), content="abcd")
  let input = runtime.focused_text_input()
  inspect(input.caret, content="4")
  guard input.selection is Some(selection) else {
    fail("expected restored selection")
  }
  inspect(selection.normalized().start, content="0")
  inspect(selection.normalized().end, content="4")
}

///|
test "text field keyboard undo and redo use edit history" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_text_field(state.binding()),
    size=Size::new(width=160.0, height=60.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(TextInput(InsertText("ab")))
  runtime.dispatch_event(TextInput(InsertText("c")))
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(key="z", modifiers=KeyModifiers::new(meta=true)),
    ),
  )
  inspect(state.get(), content="ab")
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(
        key="z",
        modifiers=KeyModifiers::new(shift=true, meta=true),
      ),
    ),
  )
  inspect(state.get(), content="abc")
}

///|
test "text field selection draws highlight before text" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_text_field(state.binding()),
    size=Size::new(width=160.0, height=60.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(TextInput(InsertText("abc")))
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(
        key="ArrowLeft",
        modifiers=KeyModifiers::new(shift=true),
      ),
    ),
  )
  let commands = runtime.build_draw_commands()
  guard test_selection_highlight_color(commands) is Some(color) else {
    fail("expected selection highlight")
  }
  inspect(color.a, content="0.18")
  assert_true(test_draw_text_frame(commands, "abc") is Some(_))
}

///|
test "ime composition updates paint preview and commit into text field" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_text_field(state.binding()),
    size=Size::new(width=180.0, height=60.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(TextInput(CompositionStart))
  runtime.dispatch_event(
    TextInput(CompositionUpdate(CompositionUpdate::new(text="ni", cursor=None))),
  )
  let preview = runtime.build_draw_commands()
  guard preview[3] is DrawText({ text: "ni", align: TextAlign::TextStart, .. }) else {
    fail("expected composition preview")
  }
  inspect(state.get(), content="")
  runtime.dispatch_event(TextInput(CompositionEnd("你")))
  inspect(state.get(), content="你")
  let committed = runtime.build_draw_commands()
  guard committed[3]
    is DrawText({ text: "你", align: TextAlign::TextStart, .. }) else {
    fail("expected committed text")
  }
}

///|
test "ime composition replaces selected text and undo restores selection edit" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_text_field(state.binding()),
    size=Size::new(width=180.0, height=60.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(TextInput(InsertText("abcd")))
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(
        key="ArrowLeft",
        modifiers=KeyModifiers::new(shift=true),
      ),
    ),
  )
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(
        key="ArrowLeft",
        modifiers=KeyModifiers::new(shift=true),
      ),
    ),
  )
  runtime.dispatch_event(TextInput(CompositionStart))
  runtime.dispatch_event(
    TextInput(
      CompositionUpdate(CompositionUpdate::new(text="你", cursor=None)),
    ),
  )
  inspect(state.get(), content="abcd")
  runtime.dispatch_event(TextInput(CompositionEnd("你")))
  inspect(state.get(), content="ab你")
  let undo = runtime.dispatch_focused_text_command(Undo)
  assert_true(undo.handled)
  inspect(state.get(), content="abcd")
  let redo = runtime.dispatch_focused_text_command(Redo)
  assert_true(redo.handled)
  inspect(state.get(), content="ab你")
}

///|
test "text field aligns rendered text with caret origin" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_text_field(state.binding()),
    size=Size::new(width=160.0, height=60.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(TextInput(InsertText("abc")))
  let commands = runtime.build_draw_commands()
  guard test_draw_text_frame(commands, "abc") is Some(text_frame) else {
    fail("expected left-aligned text field text")
  }
  guard test_text_field_caret_rect(commands) is Some(cursor) else {
    fail("expected focused text field cursor")
  }
  let layout = TextSystem::fallback().measure_text(
    TextLayoutInput::new(
      text="abc",
      font=FontSpec::new(size=16.0, weight=400),
      max_width=text_frame.size.width,
    ),
  )
  assert_true(text_frame.origin.x == 10.0)
  assert_true(
    cursor.origin.x == text_frame.origin.x + layout.caret_positions[3],
  )
}

///|
test "text field caret follows ime composition cursor" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_text_field(state.binding()),
    size=Size::new(width=160.0, height=60.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(TextInput(CompositionStart))
  runtime.dispatch_event(
    TextInput(
      CompositionUpdate(
        CompositionUpdate::new(
          text="ni",
          cursor=Some(TextRange::new(start=1, end=1)),
        ),
      ),
    ),
  )
  let commands = runtime.build_draw_commands()
  guard test_text_field_caret_rect(commands) is Some(cursor) else {
    fail("expected focused text field cursor")
  }
  let layout = TextSystem::fallback().measure_text(
    TextLayoutInput::new(
      text="ni",
      font=FontSpec::new(size=16.0, weight=400),
      max_width=140.0,
    ),
  )
  inspect(cursor.origin.x, content="18")
  assert_true(cursor.origin.x == 10.0 + layout.caret_positions[1])
}

///|
test "runtime exposes focused text input state for hosts" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_text_field(state.binding()),
    size=Size::new(width=160.0, height=60.0),
  )
  inspect(runtime.focused_text_input().focused, content="false")
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(TextInput(InsertText("abc")))
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="ArrowLeft")))
  let input = runtime.focused_text_input()
  inspect(input.focused, content="true")
  inspect(input.text, content="abc")
  inspect(input.caret, content="2")
  assert_true(input.frame == Rect::new(x=0.0, y=0.0, width=160.0, height=60.0))
  assert_true(input.caret_rect.origin.x > input.frame.origin.x)
  assert_true(input.caret_rect.origin.y > input.frame.origin.y)
}

///|
test "runtime exposes focused searchbar text input state for hosts" {
  let query = State::new("abc")
  let runtime = RuntimeState::new_spec(
    root=ViewSpec::SearchBarSpec({
      key: None,
      query: query.binding(),
      placeholder: "Search",
      font: FontSpec::new(size=14.0, weight=400),
      foreground: Color::black(),
      placeholder_color: Color::gray(),
      background: Brush::solid(Color::white()),
      border: None,
      focused_border: None,
      cursor_color: Color::blue(),
      corner_radius: 8.0,
      on_submit: None,
      on_clear: None,
    }),
    size=Size::new(width=240.0, height=44.0),
  )
  inspect(runtime.focused_text_input().focused, content="false")
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=40.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  let input = runtime.focused_text_input()
  inspect(input.focused, content="true")
  inspect(input.text, content="abc")
  inspect(input.caret, content="3")
  assert_true(input.frame == Rect::new(x=0.0, y=0.0, width=240.0, height=44.0))
  assert_true(input.caret_rect.origin.x > input.frame.origin.x + 32.0)
  assert_true(input.caret_rect.origin.y > input.frame.origin.y)
}

///|
test "focused text input caret rect follows ime composition cursor" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_text_field(state.binding()),
    size=Size::new(width=160.0, height=60.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(TextInput(CompositionStart))
  runtime.dispatch_event(
    TextInput(
      CompositionUpdate(
        CompositionUpdate::new(
          text="你",
          cursor=Some(TextRange::new(start=1, end=1)),
        ),
      ),
    ),
  )
  let input = runtime.focused_text_input()
  inspect(input.caret, content="0")
  match input.composition_cursor {
    Some(cursor) => inspect(cursor.end, content="1")
    None => fail("expected composition cursor")
  }
  inspect(input.caret_rect.origin.x, content="18")
}

///|
test "buttons participate in focus traversal and keyboard activation" {
  let clicks = Ref(0)
  let value = State::new("")
  let runtime = RuntimeState::new_spec(
    root=ViewSpec::FlexSpec({
      key: None,
      axis: Axis::Vertical,
      spacing: 8.0,
      main_axis_alignment: MainStart,
      cross_axis_alignment: CrossStretch,
      children: [
        ViewSpec::ButtonSpec({
          key: None,
          text: "Run",
          size: Size::new(width=120.0, height=40.0),
          font: FontSpec::new(size=16.0, weight=600),
          foreground: Color::black(),
          background: Brush::solid(Color::gray()),
          hovered_background: Brush::solid(Color::gray()),
          pressed_background: Brush::solid(Color::blue()),
          border: None,
          shadow: None,
          corner_radius: 0.0,
          on_click: Some(() => clicks.val = clicks.val + 1),
        }),
        test_text_field(value.binding()),
      ],
    }),
    size=Size::new(width=160.0, height=120.0),
  )
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Tab")))
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Enter")))
  inspect(clicks.val, content="1")
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Tab")))
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="x", text=Some("x"))))
  inspect(value.get(), content="x")
}

///|
test "ime delete surrounding removes text around caret" {
  let state = State::new("abc")
  let runtime = RuntimeState::new_spec(
    root=test_text_field(state.binding()),
    size=Size::new(width=160.0, height=60.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="ArrowLeft")))
  runtime.dispatch_event(TextInput(DeleteSurrounding(1, 1)))
  inspect(state.get(), content="a")
}
