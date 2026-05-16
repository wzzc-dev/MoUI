///|
fn semantics_text_field(
  value : Binding[String],
  placeholder? : String = "Name",
) -> ViewSpec {
  ViewSpec::TextFieldSpec({
    key: None,
    value,
    placeholder,
    size: Size::new(width=120.0, height=40.0),
    font: FontSpec::new(size=16.0, weight=400),
    foreground: Color::black(),
    placeholder_color: Color::gray(),
    background: Brush::solid(Color::white()),
    border: Some(Brush::solid(Color::gray())),
    focused_border: Some(Brush::solid(Color::blue())),
    border_width: 1.0,
    focused_border_width: 2.0,
    cursor_color: Color::blue(),
    corner_radius: 0.0,
    on_submit: None,
  })
}

///|
test "semantics exports button text field labels actions and focus order" {
  let value = State::new("Ada")
  let runtime = RuntimeState::new_spec(
    root=ViewSpec::FlexSpec({
      key: None,
      axis: Axis::Vertical,
      spacing: 4.0,
      main_axis_alignment: MainStart,
      cross_axis_alignment: CrossStretch,
      children: [
        ViewSpec::ButtonSpec({
          key: None,
          text: "Save",
          size: Size::new(width=120.0, height=40.0),
          font: FontSpec::new(size=16.0, weight=600),
          foreground: Color::black(),
          background: Brush::solid(Color::gray()),
          hovered_background: Brush::solid(Color::gray()),
          pressed_background: Brush::solid(Color::blue()),
          border: None,
          border_width: 0.0,
          shadow: None,
          corner_radius: 0.0,
          on_click: None,
        }),
        semantics_text_field(value.binding(), placeholder="Name"),
      ],
    }),
    size=Size::new(width=160.0, height=100.0),
  )
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=48.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  let tree = runtime.semantics()
  assert_true(tree.role == SemanticsRole::Group)
  guard tree.children[0]
    is {
      role: SemanticsRole::Button,
      label: "Save",
      focus_order: Some(0),
      actions,
      ..
    } else {
    fail("expected button semantics")
  }
  assert_true(actions.any(action => action == SemanticsAction::Activate))
  guard tree.children[1]
    is {
      role: SemanticsRole::TextField,
      label: "Name",
      value: "Ada",
      focus_order: Some(1),
      state: { focused: true, .. },
      ..
    } else {
    fail("expected focused text field semantics")
  }
}

///|
test "semantics marks list and list item roles" {
  let runtime = RuntimeState::new_spec(
    root=ViewSpec::ListSpec({
      key: None,
      spacing: 2.0,
      children: [
        ViewSpec::TextSpec({
          key: None,
          text: "One",
          size: Size::new(width=40.0, height=20.0),
          font: FontSpec::new(),
          color: Color::black(),
        }),
        ViewSpec::TextSpec({
          key: None,
          text: "Two",
          size: Size::new(width=40.0, height=20.0),
          font: FontSpec::new(),
          color: Color::black(),
        }),
      ],
    }),
    size=Size::new(width=120.0, height=60.0),
  )
  let tree = runtime.semantics()
  assert_true(tree.role == SemanticsRole::List)
  assert_true(tree.children[0].role == SemanticsRole::ListItem)
  inspect(tree.children[0].label, content="One")
  inspect(tree.children[1].frame.origin.y, content="22")
}
