///|
/// White-box coverage for `inline_edit`: the commit path, the Escape path with
/// and without a cancel message, the idle label, and the tap that asks to
/// start editing.

///|
fn inline_edit_test_state() -> @core.ViewStateContext {
  {
    focused: true,
    hovered: false,
    pressed: false,
    selected: false,
    checked: false,
    expanded: false,
    disabled: false,
    slots: @core.ViewStateSlots::empty(),
  }
}

///|
fn inline_edit_test_context(
  event~ : @core.AppEvent,
  state~ : @core.ViewStateContext,
) -> @core.ViewEventContext {
  {
    frame: @core.Rect::new(x=0.0, y=0.0, width=240.0, height=32.0),
    child_frames: [],
    event,
    focused: true,
    state,
    text_control: {
      caret: 0,
      selection: None,
      text_selection_anchor: None,
      goal_column: None,
      reveal: None,
      text_selection_origin: None,
      composition: None,
      composition_cursor: None,
      undo_stack: [],
      redo_stack: [],
    },
    text_system: @core.TextSystem::fallback(),
    environment: @core.Environment::neutral(),
    style: @core.ViewStyle::empty(),
    now_ms: 0.0,
  }
}

///|
fn inline_edit_test_key(key : String) -> @core.AppEvent {
  Keyboard(@core.KeyboardEvent::new(key~, pressed=true))
}

///|
fn inline_edit_test_pointer(
  x~ : Double,
  phase~ : @core.PointerPhase,
) -> @core.AppEvent {
  Pointer(
    @core.PointerEvent::new(position=@core.Point::new(x~, y=16.0), phase~),
  )
}

///|
test "enter commits the draft that is on screen" {
  let received : Array[String] = []
  let state = inline_edit_test_state()
  let view : @core.View[String] = inline_edit(
    key="rename",
    text="draft.md",
    editing=true,
    on_input=input => {
      received.push("input:\{input}")
      "typed"
    },
    on_commit=text => {
      received.push("commit:\{text}")
      "committed"
    },
  )
  let result = view.event(
    inline_edit_test_context(event=inline_edit_test_key("Enter"), state~),
  )
  assert_true(result.activated)
  assert_eq(result.messages, ["committed"])
  // The commit carries the caller's draft, not a stale buffer.
  assert_eq(received, ["commit:draft.md"])
}

///|
test "escape cancels when the caller supplies a message" {
  let state = inline_edit_test_state()
  let view : @core.View[String] = inline_edit(
    key="rename",
    text="draft.md",
    editing=true,
    on_input=_ => "typed",
    on_commit=_ => "committed",
    on_cancel="cancelled",
  )
  let result = view.event(
    inline_edit_test_context(event=inline_edit_test_key("Escape"), state~),
  )
  assert_eq(result.messages, ["cancelled"])
  assert_true(result.activated)
  assert_true(result.captured)
}

///|
test "escape stays inert without a cancel message" {
  let state = inline_edit_test_state()
  let view : @core.View[String] = inline_edit(
    key="rename",
    text="draft.md",
    editing=true,
    on_input=_ => "typed",
    on_commit=_ => "committed",
  )
  let result = view.event(
    inline_edit_test_context(event=inline_edit_test_key("Escape"), state~),
  )
  assert_true(result.messages.is_empty())
  assert_false(result.captured)
}

///|
test "the idle label reads the draft, and the placeholder when empty" {
  let filled : @core.View[String] = inline_edit(
    key="rename",
    text="draft.md",
    editing=false,
    on_input=_ => "typed",
    on_commit=_ => "committed",
  )
  assert_eq(filled.semantics().label, Some("draft.md"))
  let empty : @core.View[String] = inline_edit(
    key="rename",
    text="",
    editing=false,
    on_input=_ => "typed",
    on_commit=_ => "committed",
    placeholder="Untitled",
  )
  assert_eq(empty.semantics().label, Some("Untitled"))
}

///|
test "a tap on the idle label asks to start editing" {
  let state = inline_edit_test_state()
  let view : @core.View[String] = inline_edit(
    key="rename",
    text="draft.md",
    editing=false,
    on_input=_ => "typed",
    on_commit=_ => "committed",
    on_start="start",
  )
  let down = view.event(
    inline_edit_test_context(
      event=inline_edit_test_pointer(x=20.0, phase=Down),
      state~,
    ),
  )
  let press_state = match down.state {
    Some(next) => next
    None => state
  }
  let up = view.event(
    inline_edit_test_context(
      event=inline_edit_test_pointer(x=20.0, phase=Up),
      state=press_state,
    ),
  )
  assert_eq(up.messages, ["start"])
}
