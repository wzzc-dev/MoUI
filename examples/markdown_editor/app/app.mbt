///|
pub struct MarkdownEditorApp {
  document : @core.State[String]
}

///|
pub fn MarkdownEditorApp::new() -> MarkdownEditorApp {
  { document: @core.State::new(sample_markdown()) }
}

///|
pub fn MarkdownEditorApp::document(self : MarkdownEditorApp) -> String {
  self.document.get()
}

///|
pub fn MarkdownEditorApp::set_document(
  self : MarkdownEditorApp,
  text : String,
) -> Unit {
  self.document.set(text)
}

///|
pub fn MarkdownEditorApp::clear(self : MarkdownEditorApp) -> Unit {
  self.document.set("")
}

///|
pub fn MarkdownEditorApp::apply_action(
  self : MarkdownEditorApp,
  action : String,
) -> Unit {
  self.document.update(text => markdown_apply_action(text, action))
}

///|
pub fn MarkdownEditorApp::root(
  self : MarkdownEditorApp,
  ctx : @core.BuildContext,
) -> @core.ViewSpec {
  let theme = @core.Theme::light()
  let document = ctx.watch(self.document)
  let binding = ctx.binding(self.document)
  let editor_style = @core.TextFieldStyle::outline(theme~)
  let source_style = @core.SurfaceStyle::default(theme~)
  @views.surface(
    @views.column(
      [
        self.header(theme),
        self.toolbar(theme),
        @views.row(
          [
            @views.markdown_editor(
              binding,
              markdown_to_rich_text,
              placeholder="Start writing Markdown",
              style=editor_style,
              width=560.0,
              height=400.0,
            ).key("markdown-editor"),
            @views.surface(
              @views.column(
                [
                  @views.text("Markdown source", width=260.0, height=28.0)
                  .font(theme.typography.control)
                  .foreground(theme.palette.foreground),
                  source_preview(document, theme),
                ],
                spacing=theme.spacing_scale.sm,
                cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
              ),
              style=source_style,
            ).frame(width=300.0, height=400.0),
          ],
          spacing=theme.spacing_scale.lg,
          cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
        ),
        @views.text(
          "\{markdown_word_count(document)} words · \{markdown_line_count(document)} lines",
          width=320.0,
          height=28.0,
        )
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
      ],
      spacing=theme.spacing_scale.md,
      cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
    ),
    style=@core.SurfaceStyle::default(theme~),
  )
}

///|
fn MarkdownEditorApp::header(
  _self : MarkdownEditorApp,
  theme : @core.Theme,
) -> @core.ViewSpec {
  @views.column(
    [
      @views.text("MoUI Markdown", width=360.0, height=36.0)
      .font(theme.typography.title)
      .foreground(theme.palette.foreground),
      @views.text(
        "Edit Markdown as formatted content while the source stays canonical.",
        width=560.0,
        height=26.0,
      )
      .font(theme.typography.caption)
      .foreground(theme.palette.muted),
    ],
    spacing=theme.spacing_scale.xs,
    cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
  )
}

///|
fn MarkdownEditorApp::toolbar(
  self : MarkdownEditorApp,
  theme : @core.Theme,
) -> @core.ViewSpec {
  let style = flat_toolbar_button_style(theme)
  @views.row(
    [
      toolbar_button("B", () => self.apply_action("bold"), style),
      toolbar_button("I", () => self.apply_action("italic"), style),
      toolbar_button("Code", () => self.apply_action("code"), style),
      toolbar_button("H1", () => self.apply_action("h1"), style),
      toolbar_button("H2", () => self.apply_action("h2"), style),
      toolbar_button("List", () => self.apply_action("ul"), style),
      toolbar_button("1.", () => self.apply_action("ol"), style),
      toolbar_button("Quote", () => self.apply_action("quote"), style),
      toolbar_button("Block", () => self.apply_action("codeblock"), style),
      @views.button(
        "Clear",
        on_click=() => self.clear(),
        style=@core.ButtonStyle::outline(theme~),
        width=72.0,
      ),
    ],
    spacing=theme.spacing_scale.xs,
    cross_axis_alignment=@core.CrossAxisAlignment::CrossCenter,
  )
}

///|
fn toolbar_button(
  label : String,
  action : () -> Unit,
  style : @core.ButtonStyle,
) -> @core.ViewSpec {
  @views.button(label, on_click=action, style~, width=64.0, height=34.0)
}

///|
fn flat_toolbar_button_style(theme : @core.Theme) -> @core.ButtonStyle {
  let style = @core.ButtonStyle::tonal(theme~)
  {
    normal: { ..style.normal, shadow: None },
    hovered: { ..style.hovered, shadow: None },
    pressed: { ..style.pressed, shadow: None },
    disabled: { ..style.disabled, shadow: None },
  }
}

///|
fn source_preview(text : String, theme : @core.Theme) -> @core.ViewSpec {
  @views.scroll_view(
    @views.text(markdown_preview_text(text), width=260.0, height=340.0)
    .font(
      @core.FontSpec::new(
        family="ui-monospace, monospace",
        size=12.0,
        weight=400,
      ),
    )
    .foreground(theme.palette.foreground),
    width=260.0,
    height=340.0,
  )
}

///|
pub fn MarkdownEditorApp::runtime(
  self : MarkdownEditorApp,
  width? : Double = 980.0,
  height? : Double = 640.0,
) -> @core.AppRuntime {
  @core.AppRuntime::new_component(
    root=@core.Component::new(ctx => self.root(ctx)),
    size=@core.Size::new(width~, height~),
  )
}

///|
fn sample_markdown() -> String {
  "# Editor notes\n\nThis **WYSIWYG** surface keeps `Markdown` as the saved value.\n\n## Today\n- Type into the formatted page\n- Use toolbar buttons to add markers\n- Verify source on the right\n\n> Unsupported syntax stays editable as plain text.\n\n```\nlet saved = markdown\n```\n\n---"
}

///|
pub fn markdown_apply_action(text : String, action : String) -> String {
  if text == "" {
    markdown_action_seed(action)
  } else if action == "bold" {
    text + "\n\n**bold text**"
  } else if action == "italic" {
    text + "\n\n*italic text*"
  } else if action == "code" {
    text + "\n\n`code`"
  } else if action == "h1" {
    text + "\n\n# Heading"
  } else if action == "h2" {
    text + "\n\n## Section"
  } else if action == "ul" {
    text + "\n\n- List item"
  } else if action == "ol" {
    text + "\n\n1. List item"
  } else if action == "quote" {
    text + "\n\n> Quote"
  } else if action == "codeblock" {
    text + "\n\n```\ncode block\n```"
  } else {
    text
  }
}

///|
fn markdown_action_seed(action : String) -> String {
  if action == "bold" {
    "**bold text**"
  } else if action == "italic" {
    "*italic text*"
  } else if action == "code" {
    "`code`"
  } else if action == "h1" {
    "# Heading"
  } else if action == "h2" {
    "## Section"
  } else if action == "ul" {
    "- List item"
  } else if action == "ol" {
    "1. List item"
  } else if action == "quote" {
    "> Quote"
  } else if action == "codeblock" {
    "```\ncode block\n```"
  } else {
    ""
  }
}

///|
fn markdown_preview_text(text : String) -> String {
  if text == "" {
    "(empty)"
  } else if text_length_for_example(text) > 700 {
    text_substring_for_example(text, 0, 700) + "\n..."
  } else {
    text
  }
}

///|
fn markdown_line_count(text : String) -> Int {
  if text == "" {
    0
  } else {
    let mut count = 1
    for ch in text {
      if ch == '\n' {
        count = count + 1
      }
    }
    count
  }
}

///|
fn markdown_word_count(text : String) -> Int {
  let mut count = 0
  let mut in_word = false
  for ch in text {
    if ch.is_ascii_whitespace() {
      if in_word {
        count = count + 1
      }
      in_word = false
    } else {
      in_word = true
    }
  }
  if in_word {
    count = count + 1
  }
  count
}

///|
fn text_length_for_example(text : String) -> Int {
  text.to_array().length()
}

///|
fn text_substring_for_example(text : String, start : Int, end : Int) -> String {
  let chars = text.to_array()
  let start = clamp_example_int(start, 0, chars.length())
  let end = clamp_example_int(end, start, chars.length())
  String::from_array(chars[start:end])
}

///|
fn clamp_example_int(value : Int, min : Int, max : Int) -> Int {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}
