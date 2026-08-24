///|
pub fn view(model : CodeEditorModel) -> @moui.View[CodeEditorMsg] {
  let theme = editor_theme()
  let editor_font = @text.FontSpec::new(
    families=@text.FontFamilyStack::monospace(),
    size=14.0,
  )
  let workspace : Array[@moui.View[CodeEditorMsg]] = [
    activity_rail(model, theme),
    expanded(editor_shell(model, theme, editor_font)),
  ]
  match model.active_panel {
    Some(panel) => workspace.push(side_panel_view(model, panel, theme))
    None => ()
  }
  row(workspace, spacing=0.0, align=@views.CrossAlign::Stretch)
  .padding(0.0)
  .background(editor_chrome_background())
}

///|
fn editor_theme() -> @moui.Theme {
  @views.dark_theme()
}

///|
fn activity_rail(
  model : CodeEditorModel,
  theme : @moui.Theme,
) -> @moui.View[CodeEditorMsg] {
  container(
    column(
      [
        panel_button(
          "C",
          ToggleCapabilities,
          side_panel_matches(model.active_panel, CapabilitiesPanel),
          theme,
        ),
        panel_button(
          "I",
          ToggleIntelliSense,
          side_panel_matches(model.active_panel, IntelliSensePanel),
          theme,
        ),
        panel_button("D", ToggleDiffEditor, model.mode == DiffEditor, theme),
        panel_button("F", ToggleFind, model.find_visible, theme),
      ],
      spacing=8.0,
      align=@views.CrossAlign::Center,
    ),
    width=54.0,
    background=editor_rail_background(),
    padding=8.0,
  )
}

///|
fn panel_button(
  label : String,
  message : CodeEditorMsg,
  active : Bool,
  theme : @moui.Theme,
) -> @moui.View[CodeEditorMsg] {
  button(
    label,
    on_click=message,
    variant=if active {
      @views.ButtonVariant::Primary
    } else {
      @views.ButtonVariant::Tonal
    },
    theme~,
    width=38.0,
    height=34.0,
  )
}

///|
fn side_panel_view(
  model : CodeEditorModel,
  panel : CodeEditorSidePanel,
  theme : @moui.Theme,
) -> @moui.View[CodeEditorMsg] {
  match panel {
    CapabilitiesPanel => capabilities_panel(model, theme)
    IntelliSensePanel => intellisense_panel(model, theme)
  }
}

///|
fn editor_shell(
  model : CodeEditorModel,
  theme : @moui.Theme,
  editor_font : @text.FontSpec,
) -> @moui.View[CodeEditorMsg] {
  column(
    [
      editor_tab_bar(model, theme),
      expanded(
        match model.mode {
          DiffEditor => diff_editor_main(model, theme)
          _ => code_editor_surface(model, theme, editor_font)
        },
      ),
      editor_status(model, theme),
    ],
    spacing=0.0,
  ).background(editor_panel_background())
}

///|
fn editor_tab_bar(
  model : CodeEditorModel,
  theme : @moui.Theme,
) -> @moui.View[CodeEditorMsg] {
  container(
    row(
      [
        button(
          "main.mbt",
          on_click=SetMode(SourceEditor),
          variant=if model.mode == SourceEditor {
            @views.ButtonVariant::Primary
          } else {
            @views.ButtonVariant::Ghost
          },
          theme~,
          width=116.0,
          height=34.0,
        ),
        button(
          "diff",
          on_click=ToggleDiffEditor,
          variant=if model.mode == DiffEditor {
            @views.ButtonVariant::Primary
          } else {
            @views.ButtonVariant::Ghost
          },
          theme~,
          width=78.0,
          height=34.0,
        ),
        spacer(min_length=12.0),
        button(
          "Search",
          on_click=ToggleFind,
          variant=@views.ButtonVariant::Ghost,
          theme~,
          width=86.0,
          height=34.0,
        ),
        button(
          "Complete",
          on_click=TriggerCompletion,
          variant=@views.ButtonVariant::Ghost,
          theme~,
          width=96.0,
          height=34.0,
        ),
        button(
          "Problems",
          on_click=ToggleIntelliSense,
          variant=@views.ButtonVariant::Ghost,
          theme~,
          width=98.0,
          height=34.0,
        ),
        button(
          "Info",
          on_click=ToggleCapabilities,
          variant=@views.ButtonVariant::Ghost,
          theme~,
          width=70.0,
          height=34.0,
        ),
      ],
      spacing=4.0,
      align=@views.CrossAlign::Center,
    ),
    height=44.0,
    background=editor_tab_background(),
    padding=5.0,
  )
}

///|
fn code_editor_surface(
  model : CodeEditorModel,
  theme : @moui.Theme,
  editor_font : @text.FontSpec,
) -> @moui.View[CodeEditorMsg] {
  let viewport_height = 520.0
  let editor = @moui_richtext.controlled_rich_text_editor(
    value=model.source,
    on_input=value => SourceChanged(value),
    placeholder="Write native code",
    size=@geometry.Size::new(width=850.0, height=viewport_height),
    format=source => {
      code_editor_document(
        source,
        model.language_id,
        model.registry,
        editor_font,
      )
    },
    font=editor_font,
    foreground=editor_text_color(),
    placeholder_color=theme.palette.muted,
    background=@graphics.Brush::solid(editor_surface_background()),
    cursor_color=theme.palette.primary,
    corner_radius=0.0,
    on_selection_change=Some((caret, range) => SelectionChanged(caret, range)),
    input_transform=Some((source, caret, selection, inserted) => {
      if inserted == "\n" {
        let (text, cursors) = code_insert_text(
          source,
          [CodeCursor::new(position=caret, selection~)],
          inserted,
        )
        let next_caret = match cursors {
          [cursor, ..] => cursor.position
          [] => caret
        }
        Some(
          @moui_richtext.RichTextInputTransform::new(
            text~,
            caret=next_caret,
            selection=None,
          ),
        )
      } else {
        None
      }
    }),
    accepts_tab_input=true,
    visible_scroll_y=model.editor_scroll.y,
    on_scroll=Some(y => EditorScrollChanged(@geometry.Point::new(x=0.0, y~))),
    visible_viewport_height=viewport_height,
    visible_overscan=160.0,
    selection_caret=model.primary_offset(),
    selection_range=model.selection,
    kind="NativeCodeEditor",
    key=Some("native-code-editor"),
  )
  let base = container(
    row(
      [line_number_gutter(model, theme, viewport_height), editor],
      spacing=0.0,
      align=@views.CrossAlign::Stretch,
    ),
    background=editor_surface_background(),
  )
  let with_completion = if model.completion_visible {
    stack([
      base,
      completion_overlay(model, theme).offset(
        dx=completion_overlay_x(model),
        dy=completion_overlay_y(model),
      ),
    ])
  } else {
    base
  }
  if model.find_visible {
    stack([
      with_completion,
      find_overlay(model, theme).offset(dx=430.0, dy=14.0),
    ])
  } else {
    with_completion
  }
}

///|
fn line_number_gutter(
  model : CodeEditorModel,
  theme : @moui.Theme,
  viewport_height : Double,
) -> @moui.View[CodeEditorMsg] {
  let active = code_editor_caret_position(model.source, model.primary_offset()).line
  let diagnostic_lines = code_editor_diagnostic_lines(
    model.source,
    model.diagnostics,
  )
  let rows : Array[@moui.View[CodeEditorMsg]] = []
  for line in code_editor_source_lines(model.source) {
    let marker = if diagnostic_lines.contains(line.number) { "!" } else { " " }
    rows.push(
      container(
        text(
          marker + " " + line.number.to_string(),
          role=@views.TextRole::Mono,
          theme~,
          width=48.0,
          height=20.0,
        ).foreground(
          if line.number == active {
            theme.palette.foreground
          } else {
            theme.palette.muted
          },
        ),
        width=56.0,
        height=20.0,
        background=if line.number == active {
          editor_active_line_background()
        } else {
          editor_gutter_background()
        },
      ),
    )
  }
  scroll_view(
    column(rows, spacing=0.0),
    width=58.0,
    height=viewport_height,
    offset=model.editor_scroll,
    on_scroll=Some(offset => EditorScrollChanged(offset)),
  )
}

///|
fn completion_overlay(
  model : CodeEditorModel,
  theme : @moui.Theme,
) -> @moui.View[CodeEditorMsg] {
  let rows : Array[@moui.View[CodeEditorMsg]] = []
  if model.completions.is_empty() {
    rows.push(
      text("No completions", role=@views.TextRole::Caption, theme~, width=240.0),
    )
  } else {
    for index in 0..<model.completions.length() {
      let item = model.completions[index]
      rows.push(
        button(
          item.label,
          on_click=ApplyCompletion(index),
          variant=if index == 0 {
            @views.ButtonVariant::Primary
          } else {
            @views.ButtonVariant::Ghost
          },
          theme~,
          width=240.0,
          height=30.0,
        ),
      )
    }
  }
  container(
    column(rows, spacing=2.0),
    width=260.0,
    background=editor_popup_background(),
    padding=8.0,
  ).border(
    @graphics.BorderStyle::new(
      brush=@graphics.Brush::solid(theme.palette.outline),
    ),
  )
}

///|
fn find_overlay(
  model : CodeEditorModel,
  theme : @moui.Theme,
) -> @moui.View[CodeEditorMsg] {
  container(
    row(
      [
        text(
          "Find",
          role=@views.TextRole::Caption,
          theme~,
          width=38.0,
          height=30.0,
        ),
        text_field(
          model.find.query,
          on_input=value => SetFindQuery(value),
          placeholder="Find",
          variant=@views.TextFieldVariant::Outline,
          theme~,
          width=150.0,
          height=32.0,
        ),
        text(
          "Replace",
          role=@views.TextRole::Caption,
          theme~,
          width=58.0,
          height=30.0,
        ),
        text_field(
          model.find.replacement,
          on_input=value => SetReplaceText(value),
          placeholder="Replace",
          variant=@views.TextFieldVariant::Outline,
          theme~,
          width=150.0,
          height=32.0,
        ),
        button(
          "Next",
          on_click=FindNext,
          variant=@views.ButtonVariant::Tonal,
          theme~,
          width=68.0,
          height=32.0,
        ),
        button(
          "All",
          on_click=ReplaceAll,
          variant=@views.ButtonVariant::Outline,
          theme~,
          width=62.0,
          height=32.0,
        ),
        button(
          "x",
          on_click=CloseFind,
          variant=@views.ButtonVariant::Ghost,
          theme~,
          width=36.0,
          height=32.0,
        ),
      ],
      spacing=6.0,
      align=@views.CrossAlign::Center,
    ),
    background=editor_popup_background(),
    padding=8.0,
  ).border(
    @graphics.BorderStyle::new(
      brush=@graphics.Brush::solid(theme.palette.outline),
    ),
  )
}

///|
fn editor_status(
  model : CodeEditorModel,
  theme : @moui.Theme,
) -> @moui.View[CodeEditorMsg] {
  let position = code_editor_caret_position(
    model.source,
    model.primary_offset(),
  )
  status_bar(
    [
      "Ln \{position.line}, Col \{position.column}",
      code_editor_language_label(model.language_id),
      "\{model.cursors.length()} cursor(s)",
      "\{model.diagnostics.length()} diagnostic(s)",
      model.status,
    ],
    theme~,
    width=1080.0,
    height=30.0,
  )
}

///|
fn diff_editor_main(
  model : CodeEditorModel,
  theme : @moui.Theme,
) -> @moui.View[CodeEditorMsg] {
  let diff = code_diff(model.original_source, model.source)
  container(
    row(
      [
        diff_column("Original", diff, old=true, theme),
        diff_column("Modified", diff, old=false, theme),
      ],
      spacing=1.0,
      align=@views.CrossAlign::Stretch,
    ),
    background=editor_surface_background(),
    padding=12.0,
  )
}

///|
fn diff_column(
  title : String,
  diff : CodeDiff,
  old~ : Bool,
  theme : @moui.Theme,
) -> @moui.View[CodeEditorMsg] {
  let rows : Array[@moui.View[CodeEditorMsg]] = [
    container(
      text(
        title,
        role=@views.TextRole::Control,
        theme~,
        width=420.0,
        height=28.0,
      ),
      background=editor_tab_background(),
      padding=4.0,
    ),
  ]
  for line in diff.lines {
    let number = if old { line.old_line } else { line.new_line }
    let visible = match line.kind {
      Added => !old
      Removed => old
      Context => true
    }
    let label = match number {
      Some(value) => value.to_string()
      None => ""
    }
    let content = if visible { diff_prefix(line.kind) + line.text } else { "" }
    rows.push(
      container(
        row(
          [
            text(
              label,
              role=@views.TextRole::Mono,
              theme~,
              width=42.0,
              height=22.0,
            ).foreground(theme.palette.muted),
            text(
              content,
              role=@views.TextRole::Mono,
              theme~,
              width=370.0,
              height=22.0,
            ).foreground(diff_color(line.kind, theme)),
          ],
          spacing=4.0,
          align=@views.CrossAlign::Center,
        ),
        background=diff_line_background(line.kind, old, visible),
      ),
    )
  }
  scroll_view(column(rows, spacing=0.0), width=470.0, height=520.0)
}

///|
fn completion_overlay_x(model : CodeEditorModel) -> Double {
  let position = code_editor_caret_position(
    model.source,
    model.primary_offset(),
  )
  let raw = 68.0 + (position.column - 1).to_double() * 8.4
  if raw > 680.0 {
    680.0
  } else {
    raw
  }
}

///|
fn completion_overlay_y(model : CodeEditorModel) -> Double {
  let position = code_editor_caret_position(
    model.source,
    model.primary_offset(),
  )
  let raw = 46.0 +
    (position.line - 1).to_double() * 20.0 -
    model.editor_scroll.y
  if raw < 34.0 {
    34.0
  } else {
    raw
  }
}

///|
fn code_editor_language_label(language_id : String) -> String {
  match language_id {
    "moonbit" => "MoonBit"
    "moui-script" => "MoUI Script"
    "calc" => "Calc DSL"
    _ => language_id
  }
}

///|
fn editor_chrome_background() -> @graphics.Color {
  @graphics.Color::rgba(r=0.10, g=0.11, b=0.13, a=1.0)
}

///|
fn editor_rail_background() -> @graphics.Color {
  @graphics.Color::rgba(r=0.08, g=0.09, b=0.10, a=1.0)
}

///|
fn editor_panel_background() -> @graphics.Color {
  @graphics.Color::rgba(r=0.12, g=0.13, b=0.15, a=1.0)
}

///|
fn editor_tab_background() -> @graphics.Color {
  @graphics.Color::rgba(r=0.16, g=0.17, b=0.19, a=1.0)
}

///|
fn editor_surface_background() -> @graphics.Color {
  @graphics.Color::rgba(r=0.11, g=0.12, b=0.14, a=1.0)
}

///|
fn editor_gutter_background() -> @graphics.Color {
  @graphics.Color::rgba(r=0.10, g=0.11, b=0.13, a=1.0)
}

///|
fn editor_active_line_background() -> @graphics.Color {
  @graphics.Color::rgba(r=0.18, g=0.19, b=0.20, a=1.0)
}

///|
fn editor_popup_background() -> @graphics.Color {
  @graphics.Color::rgba(r=0.18, g=0.19, b=0.22, a=1.0)
}

///|
fn editor_text_color() -> @graphics.Color {
  @graphics.Color::rgba(r=0.86, g=0.88, b=0.86, a=1.0)
}

///|
fn diff_line_background(
  kind : CodeDiffLineKind,
  old : Bool,
  visible : Bool,
) -> @graphics.Color {
  if !visible {
    return editor_surface_background()
  }
  match (kind, old) {
    (Removed, true) => @graphics.Color::rgba(r=0.27, g=0.10, b=0.11, a=1.0)
    (Added, false) => @graphics.Color::rgba(r=0.09, g=0.22, b=0.15, a=1.0)
    _ => editor_surface_background()
  }
}

///|
fn capabilities_panel(
  _model : CodeEditorModel,
  theme : @moui.Theme,
) -> @moui.View[CodeEditorMsg] {
  let rows : Array[@moui.View[CodeEditorMsg]] = [
    text("Capabilities", role=@views.TextRole::Control, theme~, width=232.0),
  ]
  for item in code_editor_features() {
    rows.push(
      column(
        [
          text(
            item.label,
            role=@views.TextRole::Caption,
            theme~,
            width=232.0,
            height=22.0,
          ),
          text(
            item.detail,
            role=@views.TextRole::Caption,
            theme~,
            width=232.0,
            height=30.0,
          ).foreground(theme.palette.muted),
        ],
        spacing=0.0,
      ),
    )
  }
  container(
    scroll_view(column(rows, spacing=8.0), width=252.0, height=438.0),
    width=268.0,
    padding=12.0,
  ).border(
    @graphics.BorderStyle::new(
      brush=@graphics.Brush::solid(theme.palette.outline),
    ),
  )
}

///|
fn intellisense_panel(
  model : CodeEditorModel,
  theme : @moui.Theme,
) -> @moui.View[CodeEditorMsg] {
  container(
    column(
      [
        text("IntelliSense", role=@views.TextRole::Control, theme~, width=260.0),
        text(
          "Completion provider",
          role=@views.TextRole::Caption,
          theme~,
          width=260.0,
        ),
        completion_list(model, theme),
        text("Diagnostics", role=@views.TextRole::Caption, theme~, width=260.0),
        diagnostic_list(model, theme),
        text(
          "Bracket Match",
          role=@views.TextRole::Caption,
          theme~,
          width=260.0,
        ),
        bracket_match_view(model, theme),
        text("Hover", role=@views.TextRole::Caption, theme~, width=260.0),
        hover_view(model, theme),
        text("Definition", role=@views.TextRole::Caption, theme~, width=260.0),
        definition_view(model, theme),
        button(
          "Go to Definition",
          on_click=GoToDefinition,
          variant=@views.ButtonVariant::Tonal,
          theme~,
          width=160.0,
        ),
        button(
          "Register Custom Language",
          on_click=RegisterSampleLanguage,
          variant=@views.ButtonVariant::Outline,
          theme~,
          width=220.0,
        ),
      ],
      spacing=8.0,
    ),
    width=292.0,
    padding=12.0,
  ).border(
    @graphics.BorderStyle::new(
      brush=@graphics.Brush::solid(theme.palette.outline),
    ),
  )
}

///|
fn completion_list(
  model : CodeEditorModel,
  theme : @moui.Theme,
) -> @moui.View[CodeEditorMsg] {
  let rows : Array[@moui.View[CodeEditorMsg]] = []
  if model.completions.is_empty() {
    rows.push(
      text(
        "No completions yet",
        role=@views.TextRole::Caption,
        theme~,
        width=252.0,
      ).foreground(theme.palette.muted),
    )
  } else {
    for item in model.completions {
      rows.push(
        text(
          item.label + " - " + item.detail,
          role=@views.TextRole::Caption,
          theme~,
          width=252.0,
          height=24.0,
        ),
      )
    }
  }
  column(rows, spacing=4.0)
}

///|
fn diagnostic_list(
  model : CodeEditorModel,
  theme : @moui.Theme,
) -> @moui.View[CodeEditorMsg] {
  let rows : Array[@moui.View[CodeEditorMsg]] = []
  if model.diagnostics.is_empty() {
    rows.push(
      text("No diagnostics", role=@views.TextRole::Caption, theme~, width=252.0).foreground(
        theme.palette.muted,
      ),
    )
  } else {
    for item in model.diagnostics {
      rows.push(
        text(
          item.severity.label() + ": " + item.message,
          role=@views.TextRole::Caption,
          theme~,
          width=252.0,
          height=28.0,
        ),
      )
    }
  }
  column(rows, spacing=4.0)
}

///|
fn bracket_match_view(
  model : CodeEditorModel,
  theme : @moui.Theme,
) -> @moui.View[CodeEditorMsg] {
  let detail = match model.bracket_match {
    Some(value) => "open \{value.open}, close \{value.close}"
    None => "No active bracket pair"
  }
  text(detail, role=@views.TextRole::Caption, theme~, width=252.0, height=28.0).foreground(
    if model.bracket_match is Some(_) {
      theme.palette.foreground
    } else {
      theme.palette.muted
    },
  )
}

///|
fn hover_view(
  model : CodeEditorModel,
  theme : @moui.Theme,
) -> @moui.View[CodeEditorMsg] {
  let detail = match model.hover {
    Some(value) => value.detail
    None => "No hover result"
  }
  text(detail, role=@views.TextRole::Caption, theme~, width=252.0, height=38.0).foreground(
    if model.hover is Some(_) {
      theme.palette.foreground
    } else {
      theme.palette.muted
    },
  )
}

///|
fn definition_view(
  model : CodeEditorModel,
  theme : @moui.Theme,
) -> @moui.View[CodeEditorMsg] {
  let detail = match model.definition {
    Some(value) =>
      value.symbol + " -> " + value.file + ":\{value.line}:\{value.column}"
    None => "No definition result"
  }
  text(detail, role=@views.TextRole::Caption, theme~, width=252.0, height=38.0).foreground(
    if model.definition is Some(_) {
      theme.palette.foreground
    } else {
      theme.palette.muted
    },
  )
}

///|
fn diff_prefix(kind : CodeDiffLineKind) -> String {
  match kind {
    Context => "  "
    Added => "+ "
    Removed => "- "
  }
}

///|
fn diff_color(kind : CodeDiffLineKind, theme : @moui.Theme) -> @graphics.Color {
  match kind {
    Context => theme.palette.foreground
    Added => @graphics.Color::rgba(r=0.10, g=0.50, b=0.25, a=1.0)
    Removed => @graphics.Color::rgba(r=0.72, g=0.16, b=0.16, a=1.0)
  }
}

///|
pub fn program() -> @moui.Program[CodeEditorModel, CodeEditorMsg] {
  @moui.Program::simple(init=CodeEditorModel::new(), update~, view~).with_commands(commands=_model => {
      let commands = code_editor_action_commands()
      [
        @moui.ProgramCommand::new(
          command=commands[0],
          message=OpenCommandPalette,
        ),
        @moui.ProgramCommand::new(command=commands[1], message=RunDiagnostics),
        @moui.ProgramCommand::new(
          command=commands[2],
          message=TriggerCompletion,
        ),
      ]
    },
  )
}

///|
fn sample_original_source() -> String {
  "fn add(a, b) {\n  a + b\n}\n"
}

///|
fn sample_source() -> String {
  "fn add(a, b) {\n  return a + b\n}\n\nfn main {\n  println(add(1, 2))\n}\n"
}

///|
fn sample_provider() -> CodeLanguageProvider {
  CodeLanguageProvider::new(
    id="calc",
    label="Calc DSL",
    tokenizer=source => {
      [
        {
          text: source,
          kind: if source.contains("let") {
            "keyword"
          } else {
            "plain"
          },
        },
      ]
    },
    completion_provider=(_source, _offset) => {
      [CodeCompletionItem::new(label="let", insert_text="let value = ")]
    },
    hover_provider=(_source, _offset) => {
      Some(CodeHover::new(symbol="let", detail="Declares a Calc value."))
    },
    definition_provider=(_source, _offset) => {
      Some(CodeDefinition::new(symbol="let", file="calc.dsl", line=1, column=1))
    },
  )
}
