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
