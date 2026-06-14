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
