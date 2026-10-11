///|
/// Rendering helpers for the Msg-generic chrome views: build a one-shot
/// program, draw once, and collect text runs / rects.

///|
fn[Msg] markdown_panel_draw_commands(
  view : @moui.View[Msg],
  width : Double,
  height : Double,
) -> Array[@core.DrawCommand] {
  let program : @core.Program[Int, Msg] = @moui.Program::new_with_environment(
    init=() => (0, @moui.Effect::none()),
    update=(current, _) => (current, @moui.Effect::none()),
    view=(_, _) => view,
  )
  @runtime.new_program_with_dimensions(program~, width~, height~).draw_commands()
}

///|
fn markdown_panel_texts(commands : Array[@core.DrawCommand]) -> Array[String] {
  let texts : Array[String] = []
  for command in commands {
    match command {
      @core.DrawCommand::DrawText(run) => texts.push(run.text)
      _ => ()
    }
  }
  texts
}

///|
fn markdown_panel_has_text(
  commands : Array[@core.DrawCommand],
  needle : String,
) -> Bool {
  markdown_panel_texts(commands).any(text => text.contains(needle))
}

///|
fn markdown_panel_theme() -> @moui.Theme {
  @views.theme()
}

///|
test "markdown find bar renders all controls and status" {
  let view : @moui.View[Int] = markdown_find_bar(
    theme=markdown_panel_theme(),
    query="needle",
    replace_text="thread",
    options=MarkdownFindOptions::default(),
    status_label="1/2",
    on_query_input=_ => 0,
    on_replace_input=_ => 0,
    on_submit_query=1,
    on_submit_replace=2,
    on_toggle_case_sensitive=3,
    on_toggle_whole_word=4,
    on_toggle_regex=5,
    on_previous=6,
    on_next=7,
    on_replace_current=8,
    on_replace_all=9,
    on_close=10,
    width=1120.0,
  )
  let commands = markdown_panel_draw_commands(view, 1120.0, 64.0)
  assert_true(markdown_panel_has_text(commands, "Find"), msg="Find label")
  assert_true(markdown_panel_has_text(commands, "Replace"), msg="Replace label")
  assert_true(markdown_panel_has_text(commands, "Aa"), msg="case toggle")
  assert_true(markdown_panel_has_text(commands, "W"), msg="whole word toggle")
  assert_true(markdown_panel_has_text(commands, ".*"), msg="regex toggle")
  assert_true(markdown_panel_has_text(commands, "1/2"), msg="status label")
}

///|
test "markdown format palette filters rows and reports empty state" {
  let options = markdown_format_palette_filtered_items("bold")
  let view : @moui.View[Int] = markdown_format_palette(
    theme=markdown_panel_theme(),
    query="bold",
    items=options,
    on_query_input=_ => 0,
    on_submit=1,
    on_action=_ => 2,
    on_done=3,
    width=1120.0,
  )
  let commands = markdown_panel_draw_commands(view, 1120.0, 240.0)
  assert_true(markdown_panel_has_text(commands, "Bold"), msg="Bold row")
  assert_true(
    markdown_panel_has_text(commands, "Meta+B / Ctrl+B"),
    msg="shortcut column",
  )
  assert_true(markdown_panel_has_text(commands, "Quick Format"))
  assert_false(markdown_panel_has_text(commands, "Paragraph"))

  let empty_view : @moui.View[Int] = markdown_format_palette(
    theme=markdown_panel_theme(),
    query="zzz",
    items=markdown_format_palette_filtered_items("zzz"),
    on_query_input=_ => 0,
    on_submit=1,
    on_action=_ => 2,
    on_done=3,
    width=1120.0,
  )
  let empty_commands = markdown_panel_draw_commands(empty_view, 1120.0, 240.0)
  assert_true(markdown_panel_has_text(empty_commands, "No commands"))
}

///|
test "markdown outline panel shows headings and empty state" {
  let source = "# First\n\n## Second\n\n### Third"
  let snapshot = @richtext.MarkdownEditorSnapshot::parse(source)
  let view : @moui.View[Int] = markdown_outline_panel(
    theme=markdown_panel_theme(),
    outline=snapshot.outline,
    folded_starts=[],
    caret=0,
    on_jump=_ => 0,
    on_toggle_fold=_ => 0,
    height=480.0,
  )
  let commands = markdown_panel_draw_commands(view, 240.0, 480.0)
  assert_true(markdown_panel_has_text(commands, "Outline"))
  assert_true(markdown_panel_has_text(commands, "H1 First"))
  assert_true(markdown_panel_has_text(commands, "H2 Second"))
  assert_true(markdown_panel_has_text(commands, "H3 Third"))

  let empty_view : @moui.View[Int] = markdown_outline_panel(
    theme=markdown_panel_theme(),
    outline=[],
    folded_starts=[],
    caret=0,
    on_jump=_ => 0,
    on_toggle_fold=_ => 0,
    height=480.0,
  )
  let empty_commands = markdown_panel_draw_commands(empty_view, 240.0, 480.0)
  assert_true(markdown_panel_has_text(empty_commands, "No headings"))
}

///|
test "markdown outline panel hides folded children" {
  let snapshot = @richtext.MarkdownEditorSnapshot::parse(
    "# First\n\n## Second\n\n### Third",
  )
  let second_start = snapshot.outline[1].source_start
  let view : @moui.View[Int] = markdown_outline_panel(
    theme=markdown_panel_theme(),
    outline=snapshot.outline,
    folded_starts=[second_start],
    caret=0,
    on_jump=_ => 0,
    on_toggle_fold=_ => 0,
    height=480.0,
  )
  let commands = markdown_panel_draw_commands(view, 240.0, 480.0)
  assert_true(markdown_panel_has_text(commands, "H2 Second"))
  assert_true(markdown_panel_has_text(commands, "▸ H2 Second"))
  assert_false(markdown_panel_has_text(commands, "H3 Third"))
}

///|
test "markdown document info panel renders metric groups" {
  let source = "# Draft\n\nBody with [link](https://example.com)"
  let snapshot = @richtext.MarkdownEditorSnapshot::parse(source)
  let info = markdown_document_info_from_snapshot(snapshot)
  let view : @moui.View[Int] = markdown_document_info_panel(
    theme=markdown_panel_theme(),
    info~,
    word_count=snapshot.word_count,
    line_count=snapshot.line_count,
    reading_time_label="<1 min",
    height=480.0,
  )
  let commands = markdown_panel_draw_commands(view, 240.0, 480.0)
  assert_true(markdown_panel_has_text(commands, "Info"))
  assert_true(markdown_panel_has_text(commands, "Words"))
  assert_true(markdown_panel_has_text(commands, "Characters"))
  assert_true(markdown_panel_has_text(commands, "Footnotes"))
  assert_true(markdown_panel_has_text(commands, "1"))
}
