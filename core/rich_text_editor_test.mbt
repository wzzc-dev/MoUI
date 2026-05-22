///|
fn test_rich_text_editor(value : Binding[String]) -> ViewSpec {
  ViewSpec::RichTextEditorSpec({
    key: None,
    value,
    placeholder: "Write",
    size: Size::new(width=320.0, height=220.0),
    format: text => RichTextDocument::plain(text),
    font: FontSpec::new(size=16.0, weight=400),
    foreground: Color::black(),
    placeholder_color: Color::gray(),
    background: Brush::solid(Color::white()),
    border: Some(BorderStyle::new(brush=Brush::solid(Color::gray()), width=1.0)),
    focused_border: Some(
      BorderStyle::new(brush=Brush::solid(Color::blue()), width=2.0),
    ),
    cursor_color: Color::blue(),
    corner_radius: 4.0,
  })
}

///|
fn styled_rich_text_editor(value : Binding[String]) -> ViewSpec {
  ViewSpec::RichTextEditorSpec({
    key: None,
    value,
    placeholder: "Write",
    size: Size::new(width=320.0, height=220.0),
    format: _text => {
      RichTextDocument::new(blocks=[
        RichTextBlock::new(
          runs=[
            RichTextRun::new(
              text="Title",
              font=Some(FontSpec::new(size=22.0, weight=700)),
            ),
          ],
          line_height=Some(34.0),
        ),
        RichTextBlock::new(
          runs=[RichTextRun::new(text="item")],
          prefix="• ",
          line_height=Some(24.0),
        ),
        RichTextBlock::new(
          runs=[
            RichTextRun::new(
              text="code",
              font=Some(
                FontSpec::new(
                  families=FontFamilyStack::monospace(),
                  size=14.0,
                  weight=400,
                ),
              ),
              background=Some(Brush::solid(Color::black().multiply_alpha(0.08))),
            ),
          ],
          background=Some(Brush::solid(Color::gray().multiply_alpha(0.2))),
          inset=Insets::symmetric(horizontal=8.0, vertical=4.0),
          line_height=Some(24.0),
          corner_radius=6.0,
        ),
      ])
    },
    font: FontSpec::new(size=16.0, weight=400),
    foreground: Color::black(),
    placeholder_color: Color::gray(),
    background: Brush::solid(Color::white()),
    border: Some(BorderStyle::new(brush=Brush::solid(Color::gray()), width=1.0)),
    focused_border: Some(
      BorderStyle::new(brush=Brush::solid(Color::blue()), width=2.0),
    ),
    cursor_color: Color::blue(),
    corner_radius: 4.0,
  })
}

///|
test "rich text document plain formatter preserves multiline text" {
  let document = RichTextDocument::plain("a\n\nb")
  inspect(document.blocks.length(), content="3")
  inspect(document.blocks[0].runs[0].text, content="a")
  inspect(document.blocks[1].runs[0].text, content="")
  inspect(document.blocks[2].runs[0].text, content="b")
}

///|
test "rich text editor enter inserts newline and vertical arrows move caret" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_rich_text_editor(state.binding()),
    size=Size::new(width=320.0, height=220.0),
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
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Enter")))
  runtime.dispatch_event(TextInput(InsertText("de")))
  inspect(state.get(), content="abc\nde")
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="ArrowUp")))
  let input = runtime.focused_text_input()
  inspect(input.caret, content="2")
}

///|
test "rich text editor home end and delete edit within multiline text" {
  let state = State::new("abc\ndef")
  let runtime = RuntimeState::new_spec(
    root=test_rich_text_editor(state.binding()),
    size=Size::new(width=320.0, height=220.0),
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
  runtime.dispatch_event(TextInput(InsertText("X")))
  inspect(state.get(), content="abc\nXdef")
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="End")))
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Backspace")))
  inspect(state.get(), content="abc\nXde")
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Home")))
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Delete")))
  inspect(state.get(), content="abc\nde")
}

///|
test "tab traverses rich text editor focus with other controls" {
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
        test_rich_text_editor(first.binding()),
        test_rich_text_editor(second.binding()),
      ],
    }),
    size=Size::new(width=360.0, height=480.0),
  )
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Tab")))
  runtime.dispatch_event(TextInput(InsertText("first")))
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Tab")))
  runtime.dispatch_event(TextInput(InsertText("second")))
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(key="Tab", modifiers=KeyModifiers::new(shift=true)),
    ),
  )
  runtime.dispatch_event(TextInput(InsertText("!")))
  inspect(first.get(), content="first!")
  inspect(second.get(), content="second")
}

///|
test "rich text editor ime composition commits canonical text" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_rich_text_editor(state.binding()),
    size=Size::new(width=320.0, height=220.0),
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
  inspect(state.get(), content="")
  runtime.dispatch_event(TextInput(CompositionEnd("你")))
  inspect(state.get(), content="你")
}

///|
test "rich text editor ime composition replaces selection" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_rich_text_editor(state.binding()),
    size=Size::new(width=320.0, height=220.0),
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
}

///|
test "rich text editor semantics is editable text field" {
  let state = State::new("Title")
  let runtime = RuntimeState::new_spec(
    root=test_rich_text_editor(state.binding()),
    size=Size::new(width=320.0, height=220.0),
  )
  let semantics = runtime.semantics()
  assert_true(semantics.role == SemanticsRole::TextField)
  inspect(semantics.label, content="Write")
  inspect(semantics.value, content="Title")
  assert_true(
    semantics.actions.any(action => action == SemanticsAction::SetText),
  )
  assert_false(
    semantics.actions.any(action => action == SemanticsAction::Submit),
  )
}

///|
test "rich text editor draw commands contain styled runs and block decorations" {
  let state = State::new("styled")
  let commands = RuntimeState::new_spec(
    root=styled_rich_text_editor(state.binding()),
    size=Size::new(width=320.0, height=220.0),
  ).build_draw_commands()
  assert_true(
    commands.any(command => {
      command is DrawText({ text: "Title", font: { weight: 700, .. }, .. })
    }),
  )
  assert_true(
    commands.any(command => command is DrawText({ text: "• ", .. })),
  )
  assert_true(
    commands.any(command => command is DrawText({ text: "code", .. })),
  )
  assert_true(commands.any(command => command is FillRoundedRectBrush(_, _)))
}

///|
test "rich text editor placeholder and focus cursor render from empty state" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_rich_text_editor(state.binding()),
    size=Size::new(width=320.0, height=220.0),
  )
  let initial = runtime.build_draw_commands()
  assert_true(
    initial.any(command => command is DrawText({ text: "Write", .. })),
  )
  assert_false(initial.any(command => command is FillRect(_)))
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
  let focused = runtime.build_draw_commands()
  assert_true(focused.any(command => command is FillRoundedRectBrush(_, _)))
  let input = runtime.focused_text_input()
  inspect(input.focused, content="true")
  assert_true(input.caret_rect.origin.x > input.frame.origin.x)
  assert_true(input.caret_rect.origin.y > input.frame.origin.y)
}
