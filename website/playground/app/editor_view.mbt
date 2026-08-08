///|
pub fn view(model : Model, env : @moui.ViewEnvironment) -> @moui.View[Msg] {
  let theme = @views.light_theme()
  let source = current_source(model)
  let viewport = env.viewport_size()
  let compact = viewport.width < 520.0
  let gutter_width = 44.0
  let toolbar_height = 30.0
  let tab_height = 28.0
  let status_height = 26.0
  let editor_width = max_playground_double(220.0, viewport.width - gutter_width)
  let editor_height = max_playground_double(
    180.0,
    viewport.height - toolbar_height - tab_height - status_height,
  )
  let font = @text.FontSpec::new(
    families=@text.FontFamilyStack::monospace(),
    size=13.0,
  )
  let editor = @moui_richtext.controlled_rich_text_editor(
    value=source,
    on_input=source => {
      if model.active_file == Main {
        SourceChanged(source)
      } else {
        PackageChanged(source)
      }
    },
    placeholder="Edit MoonBit source",
    size=@geometry.Size::new(width=editor_width, height=editor_height),
    format=source => playground_document(source, font),
    font~,
    foreground=playground_foreground(),
    placeholder_color=theme.palette.muted,
    background=@graphics.Brush::solid(playground_editor_background()),
    cursor_color=playground_primary(),
    corner_radius=0.0,
    on_selection_change=Some((caret, selection) => {
      EditorSelectionChanged(caret, selection)
    }),
    accepts_tab_input=true,
    visible_scroll_y=model.editor_scroll.y,
    on_scroll=Some(y => EditorScrollChanged(@geometry.Point::new(x=0.0, y~))),
    visible_viewport_height=editor_height,
    visible_overscan=160.0,
    selection_caret=model.editor.cursors[0].position,
    selection_range=model.editor.selection,
    kind="MoonBitPlaygroundEditor",
    key=Some("playground-editor"),
  )
  let editor_surface = @views.row(
    [
      playground_line_number_gutter(
        model, source, theme, gutter_width, editor_height,
      ),
      editor,
    ],
    spacing=0.0,
    align=@views.CrossAlign::Stretch,
  )
  @views.column(
    [
      playground_toolbar(model, theme, compact, viewport.width, toolbar_height),
      playground_tabs(model, theme, viewport.width, tab_height),
      @views.expanded(editor_surface),
      playground_status_bar(
        model,
        source,
        theme,
        compact,
        viewport.width,
        status_height,
      ),
    ],
    spacing=0.0,
    align=@views.CrossAlign::Stretch,
  ).background(playground_editor_background())
}

///|
fn playground_toolbar(
  model : Model,
  theme : @moui.Theme,
  compact : Bool,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  let toolbar_items : Array[@moui.View[Msg]] = []
  toolbar_items.push(
    @views.text(
      "MoUI",
      role=@views.TextRole::Control,
      theme~,
      width=if compact { 36.0 } else { 42.0 },
      height=26.0,
      align=@text.TextAlign::TextStart,
    ).foreground(playground_foreground()),
  )
  toolbar_items.push(playground_example_picker(model, theme, compact))
  if !compact {
    toolbar_items.push(
      @views.button(
        "Packages",
        on_click=SelectFile(Package),
        variant=if model.active_file == Package {
          @views.ButtonVariant::Tonal
        } else {
          @views.ButtonVariant::Ghost
        },
        theme~,
        width=82.0,
        height=26.0,
      ),
    )
  }
  toolbar_items.push(@views.spacer(min_length=2.0))
  toolbar_items.push(
    @views.button(
      "Share",
      on_click=Share,
      variant=@views.ButtonVariant::Ghost,
      theme~,
      width=if compact { 50.0 } else { 54.0 },
      height=26.0,
    ),
  )
  toolbar_items.push(
    @views.button(
      if model.status == "Compile requested" {
        "Building"
      } else {
        "Rebuild"
      },
      on_click=Run,
      variant=@views.ButtonVariant::Primary,
      theme~,
      style=playground_rebuild_style(theme),
      width=if compact { 70.0 } else { 76.0 },
      height=26.0,
    ),
  )
  @views.container(
    @views.row(toolbar_items, spacing=2.0, align=@views.CrossAlign::Center).frame(
      width=width - 4.0,
    ),
    width~,
    height~,
    background=playground_toolbar_background(),
    corner_radius=0.0,
    theme~,
    padding=2.0,
  )
}

///|
fn playground_example_picker(
  model : Model,
  theme : @moui.Theme,
  compact : Bool,
) -> @moui.View[Msg] {
  // The playground toolbar is deliberately flat; the default popup elevation
  // reads as a distracting gray halo against the editor.
  let style = @views.PickerStyle::default(theme~)
    .with_font(
      font=@text.FontSpec::new(
        families=@text.FontFamilyStack::monospace(),
        size=if compact { 11.0 } else { 12.0 },
        weight=560,
      ),
    )
    .with_background(
      background=@graphics.Brush::solid(playground_editor_background()),
    )
    .with_radius(radius=4.0)
  let items = if compact {
    [
      @views.picker_item("01-hello-world", "01 Hello"),
      @views.picker_item("02-layout", "02 Layout"),
      @views.picker_item("03-state-events", "03 State"),
      @views.picker_item("04-theme-styling", "04 Theme"),
      @views.picker_item("05-component-composition", "05 Components"),
      @views.picker_item("06-animation", "06 Motion"),
    ]
  } else {
    [
      @views.picker_item("01-hello-world", "01-hello-world"),
      @views.picker_item("02-layout", "02-layout"),
      @views.picker_item("03-state-events", "03-state-events"),
      @views.picker_item("04-theme-styling", "04-theme-styling"),
      @views.picker_item("05-component-composition", "05-component-composition"),
      @views.picker_item("06-animation", "06-animation"),
    ]
  }
  @views.picker(
    items,
    selected=model.lesson_id,
    on_select=id => SelectExample(id),
    placeholder="Examples",
    theme~,
    style~,
    max_height=244.0,
  ).frame(width=if compact { 112.0 } else { 188.0 }, height=26.0)
}

///|
fn playground_tabs(
  model : Model,
  theme : @moui.Theme,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  @views.container(
    @views.row(
      [
        @views.button(
          "main.mbt",
          on_click=SelectFile(Main),
          variant=if model.active_file == Main {
            @views.ButtonVariant::Tonal
          } else {
            @views.ButtonVariant::Ghost
          },
          theme~,
          width=100.0,
          height=26.0,
        ),
        @views.button(
          "moon.pkg",
          on_click=SelectFile(Package),
          variant=if model.active_file == Package {
            @views.ButtonVariant::Tonal
          } else {
            @views.ButtonVariant::Ghost
          },
          theme~,
          width=96.0,
          height=26.0,
        ),
      ],
      spacing=0.0,
      align=@views.CrossAlign::Center,
    ).frame(width=width - 2.0),
    width~,
    height~,
    background=playground_editor_background(),
    corner_radius=0.0,
    theme~,
    padding=1.0,
  )
}

///|
fn playground_line_number_gutter(
  model : Model,
  source : String,
  theme : @moui.Theme,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  let active = @code_editor.code_editor_caret_position(
      source,
      model.editor.cursors[0].position,
    ).line
  let diagnostics = @code_editor.code_editor_diagnostic_lines(
    source,
    model.editor.diagnostics,
  )
  let line_height = 13.0 * 1.55
  let rows : Array[@moui.View[Msg]] = []
  for line in @code_editor.code_editor_source_lines(source) {
    rows.push(
      @views.container(
        @views.text(
          (if diagnostics.contains(line.number) { "!" } else { " " }) +
          line.number.to_string(),
          role=@views.TextRole::Mono,
          theme~,
          width=width - 4.0,
          height=line_height,
          align=@text.TextAlign::TextEnd,
        ).foreground(
          if line.number == active {
            playground_foreground()
          } else {
            playground_muted()
          },
        ),
        width~,
        height=line_height,
        background=if line.number == active {
          playground_active_line_background()
        } else {
          playground_gutter_background()
        },
        corner_radius=0.0,
        theme~,
        padding=0.0,
      ),
    )
  }
  @views.scroll_view(
    @views.column(rows, spacing=0.0),
    width~,
    height~,
    shows_indicator=false,
    offset=model.editor_scroll,
    on_scroll=Some(offset => EditorScrollChanged(offset)),
  )
}

///|
fn playground_status_bar(
  model : Model,
  source : String,
  theme : @moui.Theme,
  compact : Bool,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  let caret = @code_editor.code_editor_caret_position(
    source,
    model.editor.cursors[0].position,
  )
  let status = if model.editor.diagnostics.is_empty() {
    model.status + " | " + model.preview_status
  } else {
    playground_first_diagnostic(source, model.editor.diagnostics)
  }
  let status_items : Array[@moui.View[Msg]] = []
  if compact {
    let short_status = if !model.editor.diagnostics.is_empty() {
      model.editor.diagnostics.length().to_string() + " problems"
    } else if model.preview_status == "Preview running" {
      "Running"
    } else {
      "Ready"
    }
    status_items.push(
      @views.text(
        short_status,
        role=@views.TextRole::Caption,
        theme~,
        width=90.0,
        height=22.0,
        align=@text.TextAlign::TextStart,
      ).foreground(playground_muted()),
    )
    status_items.push(@views.spacer(min_length=2.0))
  } else {
    status_items.push(
      @views.text(
        status,
        role=@views.TextRole::Caption,
        theme~,
        width=max_playground_double(50.0, width - 360.0),
        height=22.0,
        align=@text.TextAlign::TextStart,
      ).foreground(playground_muted()),
    )
    status_items.push(
      @views.text(
        "Ln " + caret.line.to_string() + ", Col " + caret.column.to_string(),
        role=@views.TextRole::Mono,
        theme~,
        width=92.0,
        height=22.0,
      ).foreground(playground_muted()),
    )
    status_items.push(@views.spacer(min_length=2.0))
  }
  status_items.push(
    @views.button(
      "Find",
      on_click=FindNext,
      variant=@views.ButtonVariant::Ghost,
      theme~,
      width=42.0,
      height=22.0,
    ),
  )
  status_items.push(
    @views.button(
      "Reset",
      on_click=Reset,
      variant=@views.ButtonVariant::Ghost,
      theme~,
      width=50.0,
      height=22.0,
    ),
  )
  status_items.push(
    @views.button(
      "Stop",
      on_click=Stop,
      variant=@views.ButtonVariant::Ghost,
      theme~,
      width=42.0,
      height=22.0,
    ),
  )
  @views.container(
    @views.row(status_items, spacing=2.0, align=@views.CrossAlign::Center).frame(
      width=width - 4.0,
    ),
    width~,
    height~,
    background=playground_toolbar_background(),
    corner_radius=0.0,
    theme~,
    padding=2.0,
  )
}

///|
fn playground_first_diagnostic(
  source : String,
  diagnostics : Array[@code_editor.CodeDiagnostic],
) -> String {
  match diagnostics.get(0) {
    None => ""
    Some(diagnostic) => {
      let position = @code_editor.code_editor_caret_position(
        source,
        diagnostic.range.start,
      )
      "Line " +
      position.line.to_string() +
      ":" +
      position.column.to_string() +
      " - " +
      diagnostic.message
    }
  }
}

///|
fn max_playground_double(left : Double, right : Double) -> Double {
  if left > right {
    left
  } else {
    right
  }
}

///|
fn playground_document(
  source : String,
  font : @text.FontSpec,
) -> @moui_richtext.RichTextDocument {
  let blocks : Array[@moui_richtext.RichTextBlock] = []
  let chars = source.to_array()
  let mut line_start = 0
  let mut index = 0
  while index < chars.length() {
    if chars[index] == '\n' {
      blocks.push(
        playground_line_block(
          String::from_array(chars[line_start:index]),
          line_start~,
          content_end=index,
          source_end=index + 1,
          font~,
        ),
      )
      line_start = index + 1
    }
    index = index + 1
  }
  blocks.push(
    playground_line_block(
      String::from_array(chars[line_start:chars.length()]),
      line_start~,
      content_end=chars.length(),
      source_end=chars.length(),
      font~,
    ),
  )
  @moui_richtext.RichTextDocument::new(blocks~)
}

///|
fn playground_line_block(
  line : String,
  line_start~ : Int,
  content_end~ : Int,
  source_end~ : Int,
  font~ : @text.FontSpec,
) -> @moui_richtext.RichTextBlock {
  let runs : Array[@moui_richtext.RichTextRun] = []
  let spans = @moui_richtext.code_highlight_tokenize(line, "moonbit")
  let mut offset = line_start
  for span in spans {
    let end = offset + span.text.length()
    runs.push(
      @moui_richtext.RichTextRun::new(
        text=span.text,
        font=Some(font),
        color=playground_token_color(span.kind),
        source_range=Some({ start: offset, end }),
      ),
    )
    offset = end
  }
  if runs.is_empty() {
    runs.push(
      @moui_richtext.RichTextRun::new(
        text="",
        font=Some(font),
        source_range=Some({ start: line_start, end: line_start }),
      ),
    )
  }
  @moui_richtext.RichTextBlock::new(
    runs~,
    font=Some(font),
    source_range=Some({ start: line_start, end: source_end }),
    content_range=Some({ start: line_start, end: content_end }),
    line_height=Some(font.size * 1.55),
  )
}

///|
fn playground_token_color(
  kind : @moui_richtext.CodeHighlightToken,
) -> @graphics.Color? {
  match kind {
    CodePlain => None
    CodeKeyword => Some(@graphics.Color::rgba(r=0.51, g=0.31, b=0.87, a=1.0))
    CodeString => Some(@graphics.Color::rgba(r=0.04, g=0.48, b=0.33, a=1.0))
    CodeComment => Some(playground_muted())
    CodeNumber => Some(@graphics.Color::rgba(r=0.02, g=0.31, b=0.68, a=1.0))
    CodeFunction => Some(@graphics.Color::rgba(r=0.02, g=0.31, b=0.68, a=1.0))
    CodeType => Some(@graphics.Color::rgba(r=0.58, g=0.22, b=0.0, a=1.0))
    CodeOperator => Some(@graphics.Color::rgba(r=0.81, g=0.16, b=0.16, a=1.0))
    CodeAnnotation => Some(@graphics.Color::rgba(r=0.51, g=0.31, b=0.87, a=1.0))
    CodeEscape => Some(@graphics.Color::rgba(r=0.58, g=0.22, b=0.0, a=1.0))
  }
}

///|
fn playground_foreground() -> @graphics.Color {
  @graphics.Color::rgba(r=0.14, g=0.16, b=0.18, a=1.0)
}

///|
fn playground_muted() -> @graphics.Color {
  @graphics.Color::rgba(r=0.42, g=0.46, b=0.51, a=1.0)
}

///|
fn playground_primary() -> @graphics.Color {
  @graphics.Color::rgba(r=0.04, g=0.37, b=0.82, a=1.0)
}

///|
fn playground_toolbar_background() -> @graphics.Color {
  @graphics.Color::rgba(r=0.98, g=0.98, b=0.98, a=1.0)
}

///|
fn playground_editor_background() -> @graphics.Color {
  @graphics.Color::rgba(r=1.0, g=1.0, b=1.0, a=1.0)
}

///|
fn playground_gutter_background() -> @graphics.Color {
  @graphics.Color::rgba(r=0.985, g=0.985, b=0.985, a=1.0)
}

///|
fn playground_active_line_background() -> @graphics.Color {
  @graphics.Color::rgba(r=0.96, g=0.973, b=0.988, a=1.0)
}

///|
fn playground_rebuild_style(theme : @moui.Theme) -> @views.ButtonStyle {
  let normal = @views.new_control_state_style(
    foreground=playground_editor_background(),
    background=@graphics.Brush::solid(playground_primary()),
    radius=4.0,
  )
  let hovered = @views.new_control_state_style(
    foreground=playground_editor_background(),
    background=@graphics.Brush::solid(
      @graphics.Color::rgba(r=0.03, g=0.31, b=0.72, a=1.0),
    ),
    radius=4.0,
  )
  let pressed = @views.new_control_state_style(
    foreground=playground_editor_background(),
    background=@graphics.Brush::solid(
      @graphics.Color::rgba(r=0.02, g=0.25, b=0.62, a=1.0),
    ),
    radius=4.0,
  )
  let disabled = @views.new_control_state_style(
    foreground=theme.palette.muted,
    background=@graphics.Brush::solid(theme.palette.surface_variant),
    radius=4.0,
  )
  @views.ButtonStyle::new(normal~, hovered~, pressed~, disabled~)
}
