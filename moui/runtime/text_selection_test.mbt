///|
/// A focused text field pre-filled with a rename-style default name: the case
/// the host APIs exist for is a prompt that opens with the current name in the
/// field, where the first keystroke must replace the name instead of prefixing
/// it.
///
/// The field is declarative — its text is the argument, and edits arrive as
/// `on_input` messages — so the assertions below read the message the field
/// reports, which is exactly what an app would put back into its model.
fn text_selection_test_runtime(
  text : String,
  received : Array[String],
) -> @runtime.AppRuntime {
  let root : @core.View[Unit] = @views.text_field(
    text,
    on_input=value => {
      received.push(value)
      ()
    },
    width=200.0,
    height=40.0,
  )
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=200.0, height=40.0),
  )
  ignore(runtime.draw_frame())
  // The field takes focus on click, the same way a real prompt focuses its
  // input; no key or host shortcut is involved.
  let point = @core.Point::new(x=12.0, y=20.0)
  ignore(
    runtime.dispatch_event(
      @core.Pointer(
        @core.PointerEvent::new(position=point, phase=@core.PointerPhase::Down),
      ),
    ),
  )
  ignore(
    runtime.dispatch_event(
      @core.Pointer(
        @core.PointerEvent::new(position=point, phase=@core.PointerPhase::Up),
      ),
    ),
  )
  runtime
}

///|
fn text_selection_test_focused(runtime : @runtime.AppRuntime) -> Bool {
  runtime.focused_text_input().focused
}

///|
fn text_selection_test_type(
  runtime : @runtime.AppRuntime,
  text : String,
) -> Unit {
  ignore(
    runtime.dispatch_event(
      @core.TextInput(@core.TextInputEvent::InsertText(text)),
    ),
  )
}

///|
test "select all replaces the prefilled name on the next keystroke" {
  let received : Array[String] = []
  let runtime = text_selection_test_runtime("untitled.md", received)
  assert_true(text_selection_test_focused(runtime))
  assert_true(runtime.select_focused_text_all())
  let input = runtime.focused_text_input()
  match input.selection {
    Some(selection) => {
      let range = selection.normalized()
      assert_eq(range.start, 0)
      // The whole default name, so the first keystroke replaces all of it.
      assert_eq(range.end.to_int(), input.text.length())
    }
    None => fail("expected select-all to publish a selection")
  }
  text_selection_test_type(runtime, "k")
  if received != ["k"] {
    fail("expected the keystroke to replace the default name")
  }
}

///|
test "placing the caret at the end appends instead of prefixing" {
  let received : Array[String] = []
  let runtime = text_selection_test_runtime("untitled.md", received)
  assert_true(text_selection_test_focused(runtime))
  assert_true(runtime.place_focused_text_caret(11))
  assert_eq(runtime.focused_text_input().caret, 11)
  text_selection_test_type(runtime, "x")
  if received != ["untitled.mdx"] {
    fail("expected the keystroke to append at the caret")
  }
}

///|
test "placing the caret clamps out-of-range offsets" {
  let received : Array[String] = []
  let runtime = text_selection_test_runtime("untitled.md", received)
  assert_true(text_selection_test_focused(runtime))
  assert_true(runtime.place_focused_text_caret(4096))
  assert_eq(
    runtime.focused_text_input().caret.to_int(),
    runtime.focused_text_input().text.length(),
  )
  text_selection_test_type(runtime, "x")
  if received != ["untitled.mdx"] {
    fail("expected an offset past the end to clamp to the end")
  }
  assert_true(runtime.place_focused_text_caret(-3))
  assert_eq(runtime.focused_text_input().caret, 0)
  text_selection_test_type(runtime, "z")
  if received != ["untitled.mdx", "zuntitled.md"] {
    fail("expected a negative offset to clamp to the start")
  }
}

///|
test "an explicit selection is replaced by the next keystroke" {
  let received : Array[String] = []
  let runtime = text_selection_test_runtime("untitled.md", received)
  assert_true(text_selection_test_focused(runtime))
  assert_true(runtime.set_focused_text_selection(2, 6))
  match runtime.focused_text_input().selection {
    Some(selection) => {
      let range = selection.normalized()
      assert_eq(range.start, 2)
      assert_eq(range.end, 6)
    }
    None => fail("expected the explicit selection to be published")
  }
  text_selection_test_type(runtime, "Z")
  if received != ["unZed.md"] {
    fail("expected the keystroke to replace exactly the selected range")
  }
}

///|
test "the text selection APIs report false without a focused text control" {
  let root : @core.View[Unit] = @views.text("no input here")
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=120.0, height=40.0),
  )
  assert_true(!runtime.select_focused_text_all())
  assert_true(!runtime.place_focused_text_caret(0))
  assert_true(!runtime.set_focused_text_selection(0, 0))
}
