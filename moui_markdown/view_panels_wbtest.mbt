///|
/// Rendering helpers for the Msg-generic chrome views: build a one-shot
/// program, draw once, and collect text runs / rects.

///|
fn[Msg] markdown_panel_draw_commands(
  view : @moui.View[Msg],
  width : Double,
  height : Double,
) -> Array[@core.DrawCommand] {
  let program : @core.Program[Int32, Msg] = @moui.Program::new_with_environment(
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
  let view : @moui.View[Int32] = markdown_find_bar(
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
  let view : @moui.View[Int32] = markdown_format_palette(
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

  let empty_view : @moui.View[Int32] = markdown_format_palette(
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
  let view : @moui.View[Int32] = markdown_outline_panel(
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

  let empty_view : @moui.View[Int32] = markdown_outline_panel(
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
  let view : @moui.View[Int32] = markdown_outline_panel(
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
  let view : @moui.View[Int32] = markdown_document_info_panel(
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

///|
fn markdown_panel_max_text_right(commands : Array[@core.DrawCommand]) -> Double {
  let mut right = 0.0
  for command in commands {
    match command {
      @core.DrawCommand::DrawText(run) => {
        let edge = run.frame.origin.x + run.frame.size.width
        if edge > right {
          right = edge
        }
      }
      _ => ()
    }
  }
  right
}

///|
fn markdown_panel_find_bar_view(
  theme : @moui.Theme,
  width : Double,
  compact : Bool,
) -> @moui.View[Int32] {
  markdown_find_bar(
    theme~,
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
    width~,
    compact~,
  )
}

///|
test "compact find bar drops the inline captions and keeps every control" {
  let theme = markdown_panel_theme()
  let commands = markdown_panel_draw_commands(
    markdown_panel_find_bar_view(theme, 760.0, true),
    760.0,
    64.0,
  )
  // The captions are gone — their fields keep the placeholders — so the
  // trailing replace/close buttons get the space instead of being clipped.
  assert_false(markdown_panel_has_text(commands, "Find"))
  // "Replace" survives exactly once, as the replace-current button label.
  let replace_runs = markdown_panel_texts(commands)
    .filter(text => text == "Replace")
    .length()
  assert_eq(replace_runs, 1, msg="only the button keeps the Replace label")
  assert_true(markdown_panel_has_text(commands, "Aa"))
  assert_true(markdown_panel_has_text(commands, "W"))
  assert_true(markdown_panel_has_text(commands, ".*"))
  assert_true(markdown_panel_has_text(commands, "1/2"))
  assert_true(markdown_panel_has_text(commands, "All"))
}

///|
test "compact find bar fits the width the full bar overflows" {
  let theme = markdown_panel_theme()
  let full = markdown_panel_draw_commands(
    markdown_panel_find_bar_view(theme, 760.0, false),
    760.0,
    64.0,
  )
  let compact = markdown_panel_draw_commands(
    markdown_panel_find_bar_view(theme, 760.0, true),
    760.0,
    64.0,
  )
  // The full bar keeps its MoMark widths and runs past a 760pt slot …
  assert_true(
    markdown_panel_max_text_right(full) > 760.0,
    msg="full bar overflows a narrow window",
  )
  // … while compact stays inside it.
  assert_true(
    markdown_panel_max_text_right(compact) <= 760.0,
    msg="compact bar fits",
  )
}

///|
test "compact find bar keeps the replace and close actions on screen" {
  let theme = markdown_panel_theme()
  let bar = markdown_panel_find_bar_view(theme, 760.0, true)
  let commands = markdown_panel_draw_commands(bar, 760.0, 64.0)
  // The rightmost controls are still laid out inside a 760pt slot: the close
  // button's glyph run ends around 742 and never runs past the bar.
  assert_true(
    markdown_panel_max_text_right(commands) <= 760.0,
    msg="compact content stays inside the slot",
  )
  assert_true(markdown_panel_has_text(commands, "All"))
  assert_true(markdown_panel_has_text(commands, "Replace"))
}
