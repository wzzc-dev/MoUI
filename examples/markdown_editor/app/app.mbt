///|
pub struct MarkdownEditorApp {
  document : @core.State[String]
  selection : @core.State[MarkdownEditorSelection]
  link_target : @core.State[String]
  image_target : @core.State[String]
  code_language : @core.State[String]
  footnote_text : @core.State[String]
  html_block_text : @core.State[String]
  target_kind : @core.State[MarkdownEditorTargetKind]
  block_label : @core.State[String]
  source_preview_visible : @core.State[Bool]
  undo_stack : @core.State[Array[MarkdownEditorHistoryEntry]]
  redo_stack : @core.State[Array[MarkdownEditorHistoryEntry]]
}

///|
struct MarkdownEditorHistoryEntry {
  source : String
  selection : MarkdownEditorSelection
} derive(Eq, Debug, ToJson)

///|
enum MarkdownEditorTargetKind {
  PlainSelection
  LinkTarget
  ImageTarget
  CodeLanguageTarget
  FootnoteTarget
  HtmlBlockTarget
  TableTools
} derive(Eq, Debug, ToJson)

///|
pub fn MarkdownEditorApp::new() -> MarkdownEditorApp {
  {
    document: @core.State::new(sample_markdown()),
    selection: @core.State::new({ caret: 0, selection: None }),
    link_target: @core.State::new("https://moui.dev"),
    image_target: @core.State::new("assets/image.png"),
    code_language: @core.State::new("moonbit"),
    footnote_text: @core.State::new("Footnote text"),
    html_block_text: @core.State::new("<div>HTML</div>"),
    target_kind: @core.State::new(PlainSelection),
    block_label: @core.State::new("Paragraph"),
    source_preview_visible: @core.State::new(false),
    undo_stack: @core.State::new([]),
    redo_stack: @core.State::new([]),
  }
}

///|
fn MarkdownEditorApp::toggle_source_preview(self : MarkdownEditorApp) -> Unit {
  self.source_preview_visible.set(!self.source_preview_visible.get())
}

///|
fn MarkdownEditorApp::apply_command(
  self : MarkdownEditorApp,
  command : MarkdownEditorCommand,
) -> Unit {
  self.apply_command_to_selection(command)
}

///|
fn MarkdownEditorApp::apply_command_to_selection(
  self : MarkdownEditorApp,
  command : MarkdownEditorCommand,
) -> Unit {
  let before = self.history_entry()
  let result = markdown_editor_apply_command_at(
    before.source,
    command,
    Some(before.selection),
  )
  if result.source == before.source &&
    result.selection == before.selection.selection &&
    result.caret == before.selection.caret {
    return
  }
  self.push_undo(before)
  self.redo_stack.set([])
  self.document.set(result.source)
  self.selection.set({ caret: result.caret, selection: result.selection })
  self.sync_target_inputs()
}

///|
fn MarkdownEditorApp::undo(self : MarkdownEditorApp) -> Bool {
  self.restore_history(undo=true)
}

///|
fn MarkdownEditorApp::redo(self : MarkdownEditorApp) -> Bool {
  self.restore_history(undo=false)
}

///|
fn MarkdownEditorApp::set_selection(
  self : MarkdownEditorApp,
  caret : Int,
  selection : @core.TextRange?,
) -> Unit {
  self.selection.set({ caret, selection })
  self.sync_target_inputs()
}

///|
fn MarkdownEditorApp::apply_link_target(self : MarkdownEditorApp) -> Unit {
  self.apply_command_to_selection(SetLinkTarget(self.link_target.get()))
}

///|
fn MarkdownEditorApp::apply_image_target(self : MarkdownEditorApp) -> Unit {
  self.apply_command_to_selection(SetImageTarget(self.image_target.get()))
}

///|
fn MarkdownEditorApp::apply_code_language(self : MarkdownEditorApp) -> Unit {
  self.apply_command_to_selection(SetCodeLanguage(self.code_language.get()))
}

///|
fn MarkdownEditorApp::apply_footnote_text(self : MarkdownEditorApp) -> Unit {
  self.apply_command_to_selection(SetFootnoteText(self.footnote_text.get()))
}

///|
fn MarkdownEditorApp::apply_html_block_text(self : MarkdownEditorApp) -> Unit {
  self.apply_command_to_selection(SetHtmlBlockText(self.html_block_text.get()))
}

///|
fn MarkdownEditorApp::history_entry(
  self : MarkdownEditorApp,
) -> MarkdownEditorHistoryEntry {
  { source: self.document.get(), selection: self.selection.get() }
}

///|
fn MarkdownEditorApp::push_undo(
  self : MarkdownEditorApp,
  entry : MarkdownEditorHistoryEntry,
) -> Unit {
  let stack = self.undo_stack.get()
  stack.push(entry)
  self.undo_stack.set(stack)
}

///|
fn MarkdownEditorApp::push_redo(
  self : MarkdownEditorApp,
  entry : MarkdownEditorHistoryEntry,
) -> Unit {
  let stack = self.redo_stack.get()
  stack.push(entry)
  self.redo_stack.set(stack)
}

///|
fn MarkdownEditorApp::restore_history(
  self : MarkdownEditorApp,
  undo~ : Bool,
) -> Bool {
  let stack = if undo { self.undo_stack.get() } else { self.redo_stack.get() }
  if stack.length() == 0 {
    return false
  }
  let entry = stack[stack.length() - 1]
  ignore(stack.pop())
  if undo {
    self.undo_stack.set(stack)
    self.push_redo(self.history_entry())
  } else {
    self.redo_stack.set(stack)
    self.push_undo(self.history_entry())
  }
  self.document.set(entry.source)
  self.selection.set(entry.selection)
  self.sync_target_inputs()
  true
}

///|
fn MarkdownEditorApp::sync_target_inputs(self : MarkdownEditorApp) -> Unit {
  let selection = self.selection.get()
  let block_label = markdown_editor_active_block_label(
    self.document.get(),
    selection,
  )
  self.block_label.set(block_label)
  match markdown_editor_selected_link_target(self.document.get(), selection) {
    Some(target) => {
      self.link_target.set(target)
      self.target_kind.set(LinkTarget)
      return
    }
    None => ()
  }
  match markdown_editor_selected_image_target(self.document.get(), selection) {
    Some(target) => {
      self.image_target.set(target)
      self.target_kind.set(ImageTarget)
    }
    None =>
      match
        markdown_editor_selected_footnote_text(self.document.get(), selection) {
        Some(text) => {
          self.footnote_text.set(text)
          self.target_kind.set(FootnoteTarget)
        }
        None =>
          match
            markdown_editor_selected_code_language(
              self.document.get(),
              selection,
            ) {
            Some(language) => {
              self.code_language.set(language)
              self.target_kind.set(CodeLanguageTarget)
            }
            None =>
              match
                markdown_editor_selected_html_block_text(
                  self.document.get(),
                  selection,
                ) {
                Some(text) => {
                  self.html_block_text.set(text)
                  self.target_kind.set(HtmlBlockTarget)
                }
                None =>
                  if block_label == "Table" {
                    self.target_kind.set(TableTools)
                  } else if block_label == "Code block" {
                    self.target_kind.set(CodeLanguageTarget)
                  } else {
                    self.target_kind.set(PlainSelection)
                  }
              }
          }
      }
  }
}

///|
fn MarkdownEditorApp::toggle_task_at(
  self : MarkdownEditorApp,
  content_offset : Int,
) -> Unit {
  match markdown_editor_toggle_task_at(self.document.get(), content_offset) {
    Some(result) => {
      self.document.set(result.source)
      self.selection.set({ caret: result.caret, selection: result.selection })
    }
    None => ()
  }
}

///|
fn MarkdownEditorApp::root(
  self : MarkdownEditorApp,
  ctx : @core.BuildContext,
) -> @core.ViewSpec {
  let theme = @core.Theme::light()
  let document = ctx.watch(self.document)
  let snapshot = MarkdownEditorSnapshot::parse(document)
  let binding = ctx.binding(self.document)
  let editor_style = @core.TextFieldStyle::outline(theme~)
  let source_style = @core.SurfaceStyle::default(theme~)
  let show_source = ctx.watch(self.source_preview_visible)
  let target_bar = self.target_bar(ctx, theme)
  let selection = ctx.watch(self.selection)
  let target_kind = ctx.watch(self.target_kind)
  @views.surface(
    @views.column(
      [
        self.header(theme, snapshot.active_heading),
        self.toolbar(theme),
        editor_source_layout(
          binding,
          snapshot,
          editor_style,
          source_style,
          theme,
          show_source,
          target_bar,
          selection,
          target_kind,
          (caret, selection) => self.set_selection(caret, selection),
          offset => self.toggle_task_at(offset),
        ),
        @views.text(
          "\{snapshot.word_count} words · \{snapshot.line_count} lines",
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
  title : String,
) -> @core.ViewSpec {
  @views.column(
    [
      @views.text(title, width=560.0, height=36.0)
      .font(theme.typography.title)
      .foreground(theme.palette.foreground),
      @views.text(
        "Typora-style editing core: Markdown source remains canonical while the page renders as formatted content.",
        width=560.0,
        height=26.0,
      )
      .font(theme.typography.caption)
      .foreground(theme.palette.muted),
      @views.text(
        "The formatted editor is the primary surface; source preview is available from the toolbar when needed.",
        width=760.0,
        height=24.0,
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
  @views.scroll_view(
    @views.row(
      [
        toolbar_button("B", () => self.apply_command_to_selection(Bold), style).keyboard_shortcut(
          markdown_editor_shortcut("b"),
        ),
        toolbar_button(
          "I",
          () => self.apply_command_to_selection(Italic),
          style,
        ).keyboard_shortcut(markdown_editor_shortcut("i")),
        toolbar_button(
          "Code",
          () => self.apply_command_to_selection(Code),
          style,
        ).keyboard_shortcut(markdown_editor_shortcut("e")),
        toolbar_button(
          "S",
          () => self.apply_command_to_selection(Strikethrough),
          style,
        ).keyboard_shortcut(markdown_editor_shift_shortcut("x")),
        toolbar_button(
          "Link",
          () => self.apply_command_to_selection(Link),
          style,
        ).keyboard_shortcut(markdown_editor_shortcut("l")),
        toolbar_button("URL", () => self.apply_link_target(), style),
        toolbar_button(
          "Img",
          () => self.apply_command_to_selection(Image),
          style,
        ).keyboard_shortcut(markdown_editor_shift_shortcut("i")),
        toolbar_button("ImgSrc", () => self.apply_image_target(), style),
        toolbar_button(
          "Para",
          () => self.apply_command_to_selection(Paragraph),
          style,
        ),
        toolbar_button(
          "H1",
          () => self.apply_command_to_selection(Heading(1)),
          style,
        ).keyboard_shortcut(markdown_editor_shortcut("1")),
        toolbar_button(
          "H2",
          () => self.apply_command_to_selection(Heading(2)),
          style,
        ).keyboard_shortcut(markdown_editor_shortcut("2")),
        toolbar_button(
          "H3",
          () => self.apply_command_to_selection(Heading(3)),
          style,
        ).keyboard_shortcut(markdown_editor_shortcut("3")),
        toolbar_button(
          "H4",
          () => self.apply_command_to_selection(Heading(4)),
          style,
        ).keyboard_shortcut(markdown_editor_shortcut("4")),
        toolbar_button(
          "H5",
          () => self.apply_command_to_selection(Heading(5)),
          style,
        ).keyboard_shortcut(markdown_editor_shortcut("5")),
        toolbar_button(
          "H6",
          () => self.apply_command_to_selection(Heading(6)),
          style,
        ).keyboard_shortcut(markdown_editor_shortcut("6")),
        toolbar_button(
          "Bullet",
          () => self.apply_command_to_selection(BulletList),
          style,
        ).keyboard_shortcut(markdown_editor_shortcut("u")),
        toolbar_button(
          "Task",
          () => self.apply_command_to_selection(TaskList),
          style,
        ).keyboard_shortcut(markdown_editor_shortcut("t")),
        toolbar_button(
          "1.",
          () => self.apply_command_to_selection(OrderedList),
          style,
        ).keyboard_shortcut(markdown_editor_shortcut("o")),
        toolbar_button(
          "Quote",
          () => self.apply_command_to_selection(Quote),
          style,
        ).keyboard_shortcut(markdown_editor_shortcut("q")),
        toolbar_button(
          "Rule",
          () => self.apply_command_to_selection(HorizontalRule),
          style,
        ),
        toolbar_button(
          "Table",
          () => self.apply_command_to_selection(Table),
          style,
        ),
        toolbar_button(
          "+Col",
          () => self.apply_command_to_selection(InsertTableColumn),
          style,
        ).keyboard_shortcut(markdown_editor_shift_shortcut("=")),
        toolbar_button(
          "+Row",
          () => self.apply_command_to_selection(InsertTableRow),
          style,
        ).keyboard_shortcut(markdown_editor_shift_shortcut("Enter")),
        toolbar_button(
          "-Row",
          () => self.apply_command_to_selection(DeleteTableRow),
          style,
        ).keyboard_shortcut(markdown_editor_shift_shortcut("-")),
        toolbar_button(
          "-Col",
          () => self.apply_command_to_selection(DeleteTableColumn),
          style,
        ).keyboard_shortcut(markdown_editor_shift_shortcut("_")),
        toolbar_button(
          "Left",
          () => {
            self.apply_command_to_selection(
              SetTableColumnAlignment(Some(@core.TextAlign::TextStart)),
            )
          },
          style,
        ),
        toolbar_button(
          "Center",
          () => {
            self.apply_command_to_selection(
              SetTableColumnAlignment(Some(@core.TextAlign::TextCenter)),
            )
          },
          style,
        ),
        toolbar_button(
          "Right",
          () => {
            self.apply_command_to_selection(
              SetTableColumnAlignment(Some(@core.TextAlign::TextEnd)),
            )
          },
          style,
        ),
        toolbar_button(
          "Block",
          () => self.apply_command_to_selection(CodeBlock),
          style,
        ).keyboard_shortcut(markdown_editor_shortcut("k")),
        toolbar_button("Undo", () => ignore(self.undo()), style),
        toolbar_button("Redo", () => ignore(self.redo()), style),
        toolbar_button("Src", () => self.toggle_source_preview(), style),
        @views.button(
          "Clear",
          on_click=() => self.apply_command(Clear),
          style=@core.ButtonStyle::outline(theme~),
          width=72.0,
        ),
      ],
      spacing=theme.spacing_scale.xs,
      cross_axis_alignment=@core.CrossAxisAlignment::CrossCenter,
    ),
    width=720.0,
    height=38.0,
  )
}

///|
fn MarkdownEditorApp::target_bar(
  self : MarkdownEditorApp,
  ctx : @core.BuildContext,
  theme : @core.Theme,
) -> @core.ViewSpec {
  let kind = ctx.watch(self.target_kind)
  let block_label = ctx.watch(self.block_label)
  let field_style = @core.TextFieldStyle::outline(theme~)
  let button_style = flat_toolbar_button_style(theme)
  let block_badge = @views.text(
      "Block: " + block_label,
      width=132.0,
      height=34.0,
    )
    .font(theme.typography.caption)
    .foreground(theme.palette.muted)
  match kind {
    LinkTarget =>
      @views.row(
        [
          block_badge,
          @views.text("Link target", width=88.0, height=34.0)
          .font(theme.typography.caption)
          .foreground(theme.palette.muted),
          @views.text_field(
            ctx.binding(self.link_target),
            on_submit=Some(() => self.apply_link_target()),
            placeholder="https://example.com",
            style=field_style,
            width=360.0,
            height=34.0,
          ).key("markdown-link-target"),
          toolbar_button("Apply", () => self.apply_link_target(), button_style),
        ],
        spacing=theme.spacing_scale.xs,
        cross_axis_alignment=@core.CrossAxisAlignment::CrossCenter,
      )
    ImageTarget =>
      @views.row(
        [
          block_badge,
          @views.text("Image src", width=88.0, height=34.0)
          .font(theme.typography.caption)
          .foreground(theme.palette.muted),
          @views.text_field(
            ctx.binding(self.image_target),
            on_submit=Some(() => self.apply_image_target()),
            placeholder="assets/image.png",
            style=field_style,
            width=360.0,
            height=34.0,
          ).key("markdown-image-target"),
          toolbar_button("Apply", () => self.apply_image_target(), button_style),
        ],
        spacing=theme.spacing_scale.xs,
        cross_axis_alignment=@core.CrossAxisAlignment::CrossCenter,
      )
    CodeLanguageTarget =>
      @views.row(
        [
          block_badge,
          @views.text("Code lang", width=88.0, height=34.0)
          .font(theme.typography.caption)
          .foreground(theme.palette.muted),
          @views.text_field(
            ctx.binding(self.code_language),
            on_submit=Some(() => self.apply_code_language()),
            placeholder="moonbit",
            style=field_style,
            width=360.0,
            height=34.0,
          ).key("markdown-code-language"),
          toolbar_button(
            "Apply",
            () => self.apply_code_language(),
            button_style,
          ),
        ],
        spacing=theme.spacing_scale.xs,
        cross_axis_alignment=@core.CrossAxisAlignment::CrossCenter,
      )
    FootnoteTarget =>
      @views.row(
        [
          block_badge,
          @views.text("Footnote", width=88.0, height=34.0)
          .font(theme.typography.caption)
          .foreground(theme.palette.muted),
          @views.text_field(
            ctx.binding(self.footnote_text),
            on_submit=Some(() => self.apply_footnote_text()),
            placeholder="Footnote text",
            style=field_style,
            width=360.0,
            height=34.0,
          ).key("markdown-footnote-text"),
          toolbar_button(
            "Apply",
            () => self.apply_footnote_text(),
            button_style,
          ),
        ],
        spacing=theme.spacing_scale.xs,
        cross_axis_alignment=@core.CrossAxisAlignment::CrossCenter,
      )
    HtmlBlockTarget =>
      @views.row(
        [
          block_badge,
          @views.text("HTML block", width=88.0, height=34.0)
          .font(theme.typography.caption)
          .foreground(theme.palette.muted),
          @views.text_field(
            ctx.binding(self.html_block_text),
            on_submit=Some(() => self.apply_html_block_text()),
            placeholder="<div>HTML</div>",
            style=field_style,
            width=360.0,
            height=34.0,
          ).key("markdown-html-block-text"),
          toolbar_button(
            "Apply",
            () => self.apply_html_block_text(),
            button_style,
          ),
        ],
        spacing=theme.spacing_scale.xs,
        cross_axis_alignment=@core.CrossAxisAlignment::CrossCenter,
      )
    TableTools =>
      @views.row(
        [
          block_badge,
          @views.text("Table tools", width=92.0, height=34.0)
          .font(theme.typography.caption)
          .foreground(theme.palette.muted),
          toolbar_button(
            "+Row",
            () => self.apply_command_to_selection(InsertTableRow),
            button_style,
          ),
          toolbar_button(
            "+Col",
            () => self.apply_command_to_selection(InsertTableColumn),
            button_style,
          ),
          toolbar_button(
            "-Col",
            () => self.apply_command_to_selection(DeleteTableColumn),
            button_style,
          ),
          toolbar_button(
            "-Row",
            () => self.apply_command_to_selection(DeleteTableRow),
            button_style,
          ),
          toolbar_button(
            "Left",
            () => {
              self.apply_command_to_selection(
                SetTableColumnAlignment(Some(@core.TextAlign::TextStart)),
              )
            },
            button_style,
          ),
          toolbar_button(
            "Center",
            () => {
              self.apply_command_to_selection(
                SetTableColumnAlignment(Some(@core.TextAlign::TextCenter)),
              )
            },
            button_style,
          ),
          toolbar_button(
            "Right",
            () => {
              self.apply_command_to_selection(
                SetTableColumnAlignment(Some(@core.TextAlign::TextEnd)),
              )
            },
            button_style,
          ),
          toolbar_button(
            "Auto",
            () => self.apply_command_to_selection(SetTableColumnAlignment(None)),
            button_style,
          ),
        ],
        spacing=theme.spacing_scale.xs,
        cross_axis_alignment=@core.CrossAxisAlignment::CrossCenter,
      )
    PlainSelection =>
      @views.row(
        [
          block_badge,
          @views.text(
            "Select link or image text to edit its target",
            width=360.0,
            height=34.0,
          )
          .font(theme.typography.caption)
          .foreground(theme.palette.muted),
          toolbar_button(
            "Link",
            () => self.apply_command_to_selection(Link),
            button_style,
          ),
          toolbar_button(
            "Image",
            () => self.apply_command_to_selection(Image),
            button_style,
          ),
        ],
        spacing=theme.spacing_scale.xs,
        cross_axis_alignment=@core.CrossAxisAlignment::CrossCenter,
      )
  }
}

///|
fn floating_target_palette(
  editor : @core.ViewSpec,
  target_bar : @core.ViewSpec,
  snapshot : MarkdownEditorSnapshot,
  selection : MarkdownEditorSelection,
  target_kind : MarkdownEditorTargetKind,
  editor_font : @core.FontSpec,
  theme : @core.Theme,
  width : Double,
  height : Double,
) -> @core.ViewSpec {
  let palette_style = {
    ..@core.SurfaceStyle::raised(theme~),
    padding: @core.Insets::all(theme.spacing_scale.xs),
    radius: theme.radius_scale.md,
  }
  let palette = @views.surface(target_bar, style=palette_style)
  @views.custom_children_layout(
    children=[editor, palette],
    measure=_ => @core.Size::new(width~, height~),
    place=ctx => {
      let palette_size = if ctx.child_sizes.length() > 1 {
        ctx.child_sizes[1]
      } else {
        @core.Size::new(width=0.0, height=0.0)
      }
      let editor_frame = @core.Rect::new(
        x=ctx.frame.origin.x,
        y=ctx.frame.origin.y,
        width=ctx.frame.size.width,
        height~,
      )
      let palette_width = markdown_editor_min_double(palette_size.width, width)
      let anchor = markdown_editor_palette_anchor(
        snapshot,
        selection,
        target_kind,
        editor_frame,
        editor_font,
        palette_width,
        palette_size.height,
        theme,
      )
      let palette_x = ctx.frame.origin.x +
        markdown_editor_max_double(
          0.0,
          markdown_editor_min_double(
            ctx.frame.size.width - palette_width,
            anchor.x - ctx.frame.origin.x,
          ),
        )
      let palette_y = ctx.frame.origin.y +
        markdown_editor_max_double(
          0.0,
          markdown_editor_min_double(
            ctx.frame.size.height - palette_size.height,
            anchor.y - ctx.frame.origin.y,
          ),
        )
      [
        editor_frame,
        @core.Rect::new(
          x=palette_x,
          y=palette_y,
          width=palette_width,
          height=palette_size.height,
        ),
      ]
    },
    semantics_label="Markdown editor floating target palette",
  )
}

///|
fn markdown_editor_palette_anchor(
  snapshot : MarkdownEditorSnapshot,
  selection : MarkdownEditorSelection,
  target_kind : MarkdownEditorTargetKind,
  editor_frame : @core.Rect,
  editor_font : @core.FontSpec,
  palette_width : Double,
  palette_height : Double,
  theme : @core.Theme,
) -> @core.Point {
  if target_kind == PlainSelection {
    return @core.Point::new(
      x=editor_frame.origin.x + (editor_frame.size.width - palette_width) / 2.0,
      y=editor_frame.origin.y +
        markdown_editor_max_double(
          0.0,
          editor_frame.size.height - palette_height - theme.spacing_scale.sm,
        ),
    )
  }
  let caret = match selection.selection {
    Some(range) => range.normalized().start
    None => selection.caret
  }
  let content = @core.rich_text_editor_content_rect(editor_frame)
  match
    @core.rich_text_document_caret_rect_at_source(
      snapshot.rich_text,
      caret,
      content,
      editor_font,
    ) {
    Some(rect) => {
      let x = rect.origin.x + rect.size.width / 2.0 - palette_width / 2.0
      let preferred_above = rect.origin.y -
        palette_height -
        theme.spacing_scale.sm
      let y = if preferred_above >= editor_frame.origin.y {
        preferred_above
      } else if target_kind == TableTools {
        editor_frame.origin.y +
        markdown_editor_max_double(
          0.0,
          editor_frame.size.height - palette_height - theme.spacing_scale.sm,
        )
      } else {
        rect.origin.y + rect.size.height + theme.spacing_scale.sm
      }
      @core.Point::new(x~, y~)
    }
    None =>
      @core.Point::new(
        x=editor_frame.origin.x +
          (editor_frame.size.width - palette_width) / 2.0,
        y=editor_frame.origin.y +
          markdown_editor_max_double(
            0.0,
            editor_frame.size.height - palette_height - theme.spacing_scale.sm,
          ),
      )
  }
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
fn markdown_editor_min_double(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn markdown_editor_max_double(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn markdown_editor_shortcut(key : String) -> @core.KeyboardShortcut {
  @core.KeyboardShortcut::new(
    key~,
    modifiers=@core.KeyModifiers::new(meta=true),
  )
}

///|
fn markdown_editor_shift_shortcut(key : String) -> @core.KeyboardShortcut {
  @core.KeyboardShortcut::new(
    key~,
    modifiers=@core.KeyModifiers::new(meta=true, shift=true),
  )
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
    source_preview_lines(text, theme),
    width=260.0,
    height=340.0,
  )
}

///|
fn editor_source_layout(
  binding : @core.Binding[String],
  snapshot : MarkdownEditorSnapshot,
  editor_style : @core.TextFieldStyle,
  source_style : @core.SurfaceStyle,
  theme : @core.Theme,
  show_source : Bool,
  target_bar : @core.ViewSpec,
  selection : MarkdownEditorSelection,
  target_kind : MarkdownEditorTargetKind,
  on_selection_change : (Int, @core.TextRange?) -> Unit,
  on_prefix_click : (Int) -> Unit,
) -> @core.ViewSpec {
  let editor_width = if show_source { 560.0 } else { 880.0 }
  let editor = @views.markdown_editor(
    binding,
    markdown_editor_format,
    placeholder="Start writing Markdown",
    style=editor_style,
    width=editor_width,
    height=400.0,
    on_selection_change=Some(on_selection_change),
    on_prefix_click=Some(on_prefix_click),
    input_transform=Some(markdown_editor_transform_input),
  ).key("markdown-editor")
  if !show_source {
    floating_target_palette(
      editor,
      target_bar,
      snapshot,
      selection,
      target_kind,
      editor_style.font,
      theme,
      editor_width,
      400.0,
    )
  } else {
    let editor_and_source = @views.row(
      [
        editor,
        @views.surface(
          @views.column(
            [
              @views.text("Markdown source", width=260.0, height=28.0)
              .font(theme.typography.control)
              .foreground(theme.palette.foreground),
              source_preview(snapshot.source, theme),
            ],
            spacing=theme.spacing_scale.sm,
            cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
          ),
          style=source_style,
        ).frame(width=300.0, height=400.0),
      ],
      spacing=theme.spacing_scale.lg,
      cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
    )
    @views.column(
      [editor_and_source, target_bar],
      spacing=theme.spacing_scale.md,
      cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
    )
  }
}

///|
fn source_preview_lines(text : String, theme : @core.Theme) -> @core.ViewSpec {
  let font = @core.FontSpec::new(
    families=@core.FontFamilyStack::named("SFMono-Regular")
      .with_fallback(@core.FontFamily::UiMonospace)
      .with_fallback(@core.FontFamily::Monospace),
    size=12.0,
    weight=400,
  )
  let children : Array[@core.ViewSpec] = []
  for line in markdown_split_lines(markdown_editor_preview_text(text)) {
    children.push(source_preview_line(line, font, theme.palette.foreground))
  }
  @views.column(
    children,
    spacing=0.0,
    cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
  )
}

///|
fn source_preview_line(
  line : String,
  font : @core.FontSpec,
  color : @core.Color,
) -> @core.ViewSpec {
  @views.custom_layout(
    measure=_ => @core.Size::new(width=260.0, height=18.0),
    paint=bounds => {
      [
        @core.DrawCommand::DrawText(
          @core.TextRun::new(
            text=line,
            frame=bounds,
            font~,
            color~,
            align=@core.TextAlign::TextStart,
          ),
        ),
      ]
    },
    semantics_label=line,
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
fn clamp_example_int(value : Int, min : Int, max : Int) -> Int {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}
