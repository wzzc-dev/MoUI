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
