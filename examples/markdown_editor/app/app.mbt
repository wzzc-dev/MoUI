///|
using @views {
  button,
  column,
  empty,
  markdown_editor_binding,
  padding_edges,
  row,
  scroll_view,
  spacer,
  stack,
  surface,
  text,
  text_field_binding,
}

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
  editor_scroll : @core.ScrollState
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
priv enum MarkdownEditorMsg {
  Undo
  Redo
  ToggleSourcePreview
  ApplyLinkTarget
  ApplyImageTarget
  ApplyCodeLanguage
  ApplyFootnoteText
  ApplyHtmlBlockText
  ApplyCommand(MarkdownEditorCommand)
  SetSelection(Int, @core.TextRange?)
  ToggleTaskAt(Int)
  EditorScrollTo(Double)
}

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
    editor_scroll: @core.ScrollState::new(),
  }
}

///|
fn MarkdownEditorApp::toggle_source_preview(self : MarkdownEditorApp) -> Unit {
  self.source_preview_visible.set(!self.source_preview_visible.get())
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
fn MarkdownEditorApp::update(
  self : MarkdownEditorApp,
  message : MarkdownEditorMsg,
) -> Unit {
  match message {
    Undo => ignore(self.undo())
    Redo => ignore(self.redo())
    ToggleSourcePreview => self.toggle_source_preview()
    ApplyLinkTarget => self.apply_link_target()
    ApplyImageTarget => self.apply_image_target()
    ApplyCodeLanguage => self.apply_code_language()
    ApplyFootnoteText => self.apply_footnote_text()
    ApplyHtmlBlockText => self.apply_html_block_text()
    ApplyCommand(command) => self.apply_command_to_selection(command)
    SetSelection(caret, selection) => self.set_selection(caret, selection)
    ToggleTaskAt(offset) => self.toggle_task_at(offset)
    EditorScrollTo(y) => self.editor_scroll.scroll_to(x=0.0, y~)
  }
}

///|
fn MarkdownEditorApp::root(
  self : MarkdownEditorApp,
  ctx : @core.BuildContext,
) -> @core.View[MarkdownEditorMsg] {
  let theme = @core.Theme::light()
  let document = ctx.watch(self.document)
  let snapshot = MarkdownEditorSnapshot::parse(document)
  let binding = ctx.binding(self.document)
  let editor_font = @core.FontSpec::new(size=17.0)
  let show_source = ctx.watch(self.source_preview_visible)
  let target_bar = self.target_bar(ctx, theme)
  let selection = ctx.watch(self.selection)
  let target_kind = ctx.watch(self.target_kind)
  let block_label = ctx.watch(self.block_label)
  let scroll_offset = ctx.watch_scroll(self.editor_scroll)
  let workspace = column(
    [
      self.chrome(theme, snapshot, block_label, document, selection),
      row(
        [
          editor_source_layout(
            self,
            binding,
            snapshot,
            editor_font,
            theme,
            show_source,
            target_bar,
            selection,
            target_kind,
            scroll_offset,
            (caret, selection) => SetSelection(caret, selection),
            offset => ToggleTaskAt(offset),
          ),
        ],
        spacing=theme.spacing_scale.lg,
        align=@views.CrossAlign::Start,
      ),
    ],
    spacing=theme.spacing_scale.md,
    align=@views.CrossAlign::Center,
  )
  markdown_editor_centered_workspace(
    padding_edges(
      workspace,
      top=theme.spacing_scale.lg,
      right=theme.spacing_scale.lg,
      bottom=theme.spacing_scale.lg,
      left=theme.spacing_scale.md,
    ),
  )
}

///|
fn markdown_editor_centered_workspace(
  child : @core.View[MarkdownEditorMsg],
) -> @core.View[MarkdownEditorMsg] {
  @views.custom_children_layout(
    children=[child],
    measure=ctx => ctx.constraints.max,
    place=ctx => {
      let child_size = ctx.child_sizes[0]
      let x = if ctx.frame.size.width >= 1100.0 {
        ctx.frame.origin.x +
        markdown_editor_max_double(
          0.0,
          (ctx.frame.size.width - child_size.width) / 2.0,
        )
      } else {
        ctx.frame.origin.x
      }
      let y = ctx.frame.origin.y
      [
        @core.Rect::new(
          x~,
          y~,
          width=child_size.width,
          height=child_size.height,
        ),
      ]
    },
    paint=bounds => {
      [
        @core.DrawCommand::FillRect(
          bounds,
          @core.Color::rgba(r=0.985, g=0.985, b=0.98),
        ),
      ]
    },
    semantics_label="Markdown editor workspace",
  )
}

///|
fn MarkdownEditorApp::chrome(
  self : MarkdownEditorApp,
  theme : @core.Theme,
  snapshot : MarkdownEditorSnapshot,
  block_label : String,
  source : String,
  selection : MarkdownEditorSelection,
) -> @core.View[MarkdownEditorMsg] {
  ignore(self)
  row(
    [
      text(
        markdown_editor_status_label(block_label, snapshot) +
        markdown_editor_active_format_suffix(source, selection),
        width=560.0,
        height=28.0,
      )
      .font(theme.typography.caption)
      .foreground(theme.palette.muted),
      editor_button("Undo", Undo, @views.ButtonVariant::Tonal, theme),
      editor_button("Redo", Redo, @views.ButtonVariant::Tonal, theme),
      editor_button(
        "Src",
        ToggleSourcePreview,
        @views.ButtonVariant::Tonal,
        theme,
      ),
    ],
    spacing=theme.spacing_scale.sm,
    align=@views.CrossAlign::Center,
  )
}

///|
fn markdown_editor_status_label(
  block_label : String,
  snapshot : MarkdownEditorSnapshot,
) -> String {
  block_label + " / " + markdown_editor_reading_label(snapshot)
}

///|
fn MarkdownEditorApp::target_bar(
  self : MarkdownEditorApp,
  ctx : @core.BuildContext,
  theme : @core.Theme,
) -> @core.View[MarkdownEditorMsg] {
  let kind = ctx.watch(self.target_kind)
  let block_label = ctx.watch(self.block_label)
  let block_badge = text("Block: " + block_label, width=132.0, height=34.0)
    .font(theme.typography.caption)
    .foreground(theme.palette.muted)
  match kind {
    LinkTarget =>
      row(
        [
          block_badge,
          text("Link target", width=88.0, height=34.0)
          .font(theme.typography.caption)
          .foreground(theme.palette.muted),
          text_field_binding(
            ctx.binding(self.link_target),
            on_submit=Some(ApplyLinkTarget),
            placeholder="https://example.com",
            variant=@views.TextFieldVariant::Outline,
            theme~,
            width=360.0,
            height=34.0,
          ).key("markdown-link-target"),
          editor_button(
            "Apply",
            ApplyLinkTarget,
            @views.ButtonVariant::Tonal,
            theme,
          ),
        ],
        spacing=theme.spacing_scale.xs,
        align=@views.CrossAlign::Center,
      )
    ImageTarget =>
      row(
        [
          block_badge,
          text("Image src", width=88.0, height=34.0)
          .font(theme.typography.caption)
          .foreground(theme.palette.muted),
          text_field_binding(
            ctx.binding(self.image_target),
            on_submit=Some(ApplyImageTarget),
            placeholder="assets/image.png",
            variant=@views.TextFieldVariant::Outline,
            theme~,
            width=360.0,
            height=34.0,
          ).key("markdown-image-target"),
          editor_button(
            "Apply",
            ApplyImageTarget,
            @views.ButtonVariant::Tonal,
            theme,
          ),
        ],
        spacing=theme.spacing_scale.xs,
        align=@views.CrossAlign::Center,
      )
    CodeLanguageTarget =>
      row(
        [
          block_badge,
          text("Code lang", width=88.0, height=34.0)
          .font(theme.typography.caption)
          .foreground(theme.palette.muted),
          text_field_binding(
            ctx.binding(self.code_language),
            on_submit=Some(ApplyCodeLanguage),
            placeholder="moonbit",
            variant=@views.TextFieldVariant::Outline,
            theme~,
            width=360.0,
            height=34.0,
          ).key("markdown-code-language"),
          editor_button(
            "Apply",
            ApplyCodeLanguage,
            @views.ButtonVariant::Tonal,
            theme,
          ),
        ],
        spacing=theme.spacing_scale.xs,
        align=@views.CrossAlign::Center,
      )
    FootnoteTarget =>
      row(
        [
          block_badge,
          text("Footnote", width=88.0, height=34.0)
          .font(theme.typography.caption)
          .foreground(theme.palette.muted),
          text_field_binding(
            ctx.binding(self.footnote_text),
            on_submit=Some(ApplyFootnoteText),
            placeholder="Footnote text",
            variant=@views.TextFieldVariant::Outline,
            theme~,
            width=360.0,
            height=34.0,
          ).key("markdown-footnote-text"),
          editor_button(
            "Apply",
            ApplyFootnoteText,
            @views.ButtonVariant::Tonal,
            theme,
          ),
        ],
        spacing=theme.spacing_scale.xs,
        align=@views.CrossAlign::Center,
      )
    HtmlBlockTarget =>
      row(
        [
          block_badge,
          text("HTML block", width=88.0, height=34.0)
          .font(theme.typography.caption)
          .foreground(theme.palette.muted),
          text_field_binding(
            ctx.binding(self.html_block_text),
            on_submit=Some(ApplyHtmlBlockText),
            placeholder="<div>HTML</div>",
            variant=@views.TextFieldVariant::Outline,
            theme~,
            width=360.0,
            height=34.0,
          ).key("markdown-html-block-text"),
          editor_button(
            "Apply",
            ApplyHtmlBlockText,
            @views.ButtonVariant::Tonal,
            theme,
          ),
        ],
        spacing=theme.spacing_scale.xs,
        align=@views.CrossAlign::Center,
      )
    TableTools =>
      row(
        [
          block_badge,
          text("Table tools", width=92.0, height=34.0)
          .font(theme.typography.caption)
          .foreground(theme.palette.muted),
          editor_button(
            "+Row",
            ApplyCommand(InsertTableRow),
            @views.ButtonVariant::Tonal,
            theme,
          ),
          editor_button(
            "+Col",
            ApplyCommand(InsertTableColumn),
            @views.ButtonVariant::Tonal,
            theme,
          ),
          editor_button(
            "-Col",
            ApplyCommand(DeleteTableColumn),
            @views.ButtonVariant::Tonal,
            theme,
          ),
          editor_button(
            "-Row",
            ApplyCommand(DeleteTableRow),
            @views.ButtonVariant::Tonal,
            theme,
          ),
          editor_button(
            "Left",
            ApplyCommand(
              MarkdownEditorCommand::SetTableColumnAlignment(
                Some(@core.TextAlign::TextStart),
              ),
            ),
            @views.ButtonVariant::Tonal,
            theme,
          ),
          editor_button(
            "Center",
            ApplyCommand(
              MarkdownEditorCommand::SetTableColumnAlignment(
                Some(@core.TextAlign::TextCenter),
              ),
            ),
            @views.ButtonVariant::Tonal,
            theme,
          ),
          editor_button(
            "Right",
            ApplyCommand(
              MarkdownEditorCommand::SetTableColumnAlignment(
                Some(@core.TextAlign::TextEnd),
              ),
            ),
            @views.ButtonVariant::Tonal,
            theme,
          ),
          editor_button(
            "Auto",
            ApplyCommand(SetTableColumnAlignment(None)),
            @views.ButtonVariant::Tonal,
            theme,
          ),
        ],
        spacing=theme.spacing_scale.xs,
        align=@views.CrossAlign::Center,
      )
    PlainSelection => empty()
  }
}

///|
fn markdown_editor_command_active(
  source : String,
  selection : MarkdownEditorSelection,
  command : MarkdownEditorCommand,
) -> Bool {
  match command {
    Bold | Italic | Code | Strikethrough =>
      markdown_editor_inline_command_active(source, selection, command)
    Link => markdown_editor_link_context(source, selection) is Some(_)
    Image => markdown_editor_image_context(source, selection) is Some(_)
    Heading(level) =>
      markdown_editor_active_block_label(source, selection) ==
      "Heading " + level.to_string()
    BulletList =>
      markdown_editor_active_block_label(source, selection) == "Bullet list"
    TaskList =>
      markdown_editor_active_block_label(source, selection) == "Task list"
    OrderedList =>
      markdown_editor_active_block_label(source, selection) == "Ordered list"
    Quote => markdown_editor_active_block_label(source, selection) == "Quote"
    CodeBlock =>
      markdown_editor_active_block_label(source, selection) == "Code block"
    HorizontalRule =>
      markdown_editor_active_block_label(source, selection) == "Rule"
    Table => markdown_editor_active_block_label(source, selection) == "Table"
    _ => false
  }
}

///|
fn markdown_editor_active_format_suffix(
  source : String,
  selection : MarkdownEditorSelection,
) -> String {
  let labels : Array[String] = []
  if markdown_editor_command_active(source, selection, Bold) {
    labels.push("Bold")
  }
  if markdown_editor_command_active(source, selection, Italic) {
    labels.push("Italic")
  }
  if markdown_editor_command_active(source, selection, Code) {
    labels.push("Code")
  }
  if markdown_editor_command_active(source, selection, Strikethrough) {
    labels.push("Strike")
  }
  if markdown_editor_command_active(source, selection, Link) {
    labels.push("Link")
  }
  if markdown_editor_command_active(source, selection, Image) {
    labels.push("Image")
  }
  if labels.length() == 0 {
    ""
  } else {
    " / Active: " + labels.join(", ")
  }
}

///|
fn markdown_editor_inline_command_active(
  source : String,
  selection : MarkdownEditorSelection,
  command : MarkdownEditorCommand,
) -> Bool {
  let marker = markdown_editor_inline_marker(command)
  match markdown_editor_active_selection(selection.selection) {
    Some(range) =>
      markdown_editor_range_has_inline_marker(
        source,
        range.normalized(),
        marker,
      ) &&
      markdown_editor_inline_active_marker_supported(
        source,
        range.normalized(),
        marker,
      )
    None =>
      markdown_editor_inline_marker_pair_at_caret(
        source,
        selection.caret,
        marker,
      )
      is Some(range) &&
      markdown_editor_inline_active_marker_supported(source, range, marker)
  }
}

///|
fn markdown_editor_inline_active_marker_supported(
  source : String,
  range : @core.TextRange,
  marker : String,
) -> Bool {
  if marker != "*" {
    return true
  }
  let chars = source.to_array()
  let open = range.start - 1
  let close = range.end
  let doubled_open = open > 0 && chars[open - 1] == '*'
  let doubled_close = close + 1 < chars.length() && chars[close + 1] == '*'
  !doubled_open && !doubled_close
}

///|
fn floating_target_palette(
  editor : @core.View[MarkdownEditorMsg],
  target_bar : @core.View[MarkdownEditorMsg],
  snapshot : MarkdownEditorSnapshot,
  selection : MarkdownEditorSelection,
  target_kind : MarkdownEditorTargetKind,
  editor_font : @core.FontSpec,
  theme : @core.Theme,
  scroll_offset : @core.Point,
  width : Double,
  height : Double,
) -> @core.View[MarkdownEditorMsg] {
  let palette = if target_kind == PlainSelection {
    empty()
  } else {
    surface(
      target_bar,
      variant=@views.SurfaceVariant::Raised,
      theme~,
      padding=theme.spacing_scale.xs,
    )
  }
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
        scroll_offset,
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
  scroll_offset : @core.Point,
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
  let content = @core.rich_text_editor_content_rect(editor_frame).offset(
    dx=0.0,
    dy=-scroll_offset.y,
  )
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
fn editor_button(
  label : String,
  message : MarkdownEditorMsg,
  variant : @views.ButtonVariant,
  theme : @core.Theme,
) -> @core.View[MarkdownEditorMsg] {
  button(label, on_click=message, variant~, theme~, width=64.0, height=34.0)
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
fn markdown_editor_clamp_double(
  value : Double,
  min : Double,
  max : Double,
) -> Double {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
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
fn markdown_editor_control_shortcut(key : String) -> @core.KeyboardShortcut {
  @core.KeyboardShortcut::new(
    key~,
    modifiers=@core.KeyModifiers::new(control=true),
  )
}

///|
fn markdown_editor_control_shift_shortcut(
  key : String,
) -> @core.KeyboardShortcut {
  @core.KeyboardShortcut::new(
    key~,
    modifiers=@core.KeyModifiers::new(control=true, shift=true),
  )
}

///|
fn markdown_editor_command_binding(
  label : String,
  shortcut : @core.KeyboardShortcut,
  action : () -> Unit,
) -> @core.CommandBinding {
  @core.CommandBinding::new(
    command=@core.ActionCommand::new(
      intent=@core.CommandIntent::Activate,
      label~,
      shortcut=Some(shortcut),
    ),
    handle=action,
  )
}

///|
fn MarkdownEditorApp::action_commands(
  self : MarkdownEditorApp,
) -> @core.ActionCommandMap {
  @core.ActionCommandMap::new(bindings=[
    markdown_editor_command_binding("Bold", markdown_editor_shortcut("b"), () => {
      self.update(ApplyCommand(Bold))
    }),
    markdown_editor_command_binding(
      "Bold",
      markdown_editor_control_shortcut("b"),
      () => self.update(ApplyCommand(Bold)),
    ),
    markdown_editor_command_binding("Italic", markdown_editor_shortcut("i"), () => {
      self.update(ApplyCommand(Italic))
    }),
    markdown_editor_command_binding(
      "Italic",
      markdown_editor_control_shortcut("i"),
      () => self.update(ApplyCommand(Italic)),
    ),
    markdown_editor_command_binding(
      "Inline Code",
      markdown_editor_shortcut("e"),
      () => self.update(ApplyCommand(Code)),
    ),
    markdown_editor_command_binding(
      "Inline Code",
      markdown_editor_control_shortcut("e"),
      () => self.update(ApplyCommand(Code)),
    ),
    markdown_editor_command_binding(
      "Strikethrough",
      markdown_editor_shift_shortcut("x"),
      () => self.update(ApplyCommand(Strikethrough)),
    ),
    markdown_editor_command_binding(
      "Strikethrough",
      markdown_editor_control_shift_shortcut("x"),
      () => self.update(ApplyCommand(Strikethrough)),
    ),
    markdown_editor_command_binding("Link", markdown_editor_shortcut("l"), () => {
      self.update(ApplyCommand(Link))
    }),
    markdown_editor_command_binding(
      "Link",
      markdown_editor_control_shortcut("k"),
      () => self.update(ApplyCommand(Link)),
    ),
    markdown_editor_command_binding(
      "Image",
      markdown_editor_shift_shortcut("i"),
      () => self.update(ApplyCommand(Image)),
    ),
    markdown_editor_command_binding(
      "Heading 1",
      markdown_editor_shortcut("1"),
      () => self.update(ApplyCommand(Heading(1))),
    ),
    markdown_editor_command_binding(
      "Heading 1",
      markdown_editor_control_shortcut("1"),
      () => self.update(ApplyCommand(Heading(1))),
    ),
    markdown_editor_command_binding(
      "Heading 2",
      markdown_editor_shortcut("2"),
      () => self.update(ApplyCommand(Heading(2))),
    ),
    markdown_editor_command_binding(
      "Heading 2",
      markdown_editor_control_shortcut("2"),
      () => self.update(ApplyCommand(Heading(2))),
    ),
    markdown_editor_command_binding(
      "Heading 3",
      markdown_editor_shortcut("3"),
      () => self.update(ApplyCommand(Heading(3))),
    ),
    markdown_editor_command_binding(
      "Heading 3",
      markdown_editor_control_shortcut("3"),
      () => self.update(ApplyCommand(Heading(3))),
    ),
    markdown_editor_command_binding(
      "Heading 4",
      markdown_editor_shortcut("4"),
      () => self.update(ApplyCommand(Heading(4))),
    ),
    markdown_editor_command_binding(
      "Heading 4",
      markdown_editor_control_shortcut("4"),
      () => self.update(ApplyCommand(Heading(4))),
    ),
    markdown_editor_command_binding(
      "Heading 5",
      markdown_editor_shortcut("5"),
      () => self.update(ApplyCommand(Heading(5))),
    ),
    markdown_editor_command_binding(
      "Heading 5",
      markdown_editor_control_shortcut("5"),
      () => self.update(ApplyCommand(Heading(5))),
    ),
    markdown_editor_command_binding(
      "Heading 6",
      markdown_editor_shortcut("6"),
      () => self.update(ApplyCommand(Heading(6))),
    ),
    markdown_editor_command_binding(
      "Heading 6",
      markdown_editor_control_shortcut("6"),
      () => self.update(ApplyCommand(Heading(6))),
    ),
    markdown_editor_command_binding(
      "Bullet List",
      markdown_editor_shortcut("u"),
      () => self.update(ApplyCommand(BulletList)),
    ),
    markdown_editor_command_binding(
      "Task List",
      markdown_editor_shortcut("t"),
      () => self.update(ApplyCommand(TaskList)),
    ),
    markdown_editor_command_binding(
      "Ordered List",
      markdown_editor_shortcut("o"),
      () => self.update(ApplyCommand(OrderedList)),
    ),
    markdown_editor_command_binding("Quote", markdown_editor_shortcut("q"), () => {
      self.update(ApplyCommand(Quote))
    }),
    markdown_editor_command_binding(
      "Code Block",
      markdown_editor_shortcut("k"),
      () => self.update(ApplyCommand(CodeBlock)),
    ),
    markdown_editor_command_binding(
      "Insert Table Column",
      markdown_editor_shift_shortcut("="),
      () => self.update(ApplyCommand(InsertTableColumn)),
    ),
    markdown_editor_command_binding(
      "Insert Table Row",
      markdown_editor_shift_shortcut("Enter"),
      () => self.update(ApplyCommand(InsertTableRow)),
    ),
    markdown_editor_command_binding(
      "Delete Table Row",
      markdown_editor_shift_shortcut("-"),
      () => self.update(ApplyCommand(DeleteTableRow)),
    ),
    markdown_editor_command_binding(
      "Delete Table Column",
      markdown_editor_shift_shortcut("_"),
      () => self.update(ApplyCommand(DeleteTableColumn)),
    ),
  ])
}

///|
fn markdown_editor_reading_label(snapshot : MarkdownEditorSnapshot) -> String {
  let minutes = if snapshot.reading_minutes == 0 {
    "less than 1 min"
  } else if snapshot.reading_minutes == 1 {
    "1 min"
  } else {
    snapshot.reading_minutes.to_string() + " min"
  }
  "\{snapshot.word_count} words / \{snapshot.line_count} lines / " + minutes
}

///|
fn source_preview(
  text : String,
  theme : @core.Theme,
  height~ : Double,
) -> @core.View[MarkdownEditorMsg] {
  scroll_view(source_preview_lines(text, theme), width=260.0, height~)
}

///|
fn source_inspector(
  source : String,
  theme : @core.Theme,
  height~ : Double,
) -> @core.View[MarkdownEditorMsg] {
  surface(
    padding_edges(
      column(
        [
          text("Markdown source", width=260.0, height=24.0)
          .font(theme.typography.caption)
          .foreground(theme.palette.muted),
          source_preview(
            source,
            theme,
            height=markdown_editor_max_double(0.0, height - 52.0),
          ),
        ],
        spacing=theme.spacing_scale.sm,
        align=@views.CrossAlign::Start,
      ),
      top=theme.spacing_scale.md,
      right=theme.spacing_scale.sm,
      bottom=theme.spacing_scale.md,
      left=theme.spacing_scale.sm,
    ),
    width=292.0,
    height~,
    variant=@views.SurfaceVariant::Base,
    theme~,
    background=@core.Color::rgba(r=0.972, g=0.972, b=0.966),
    corner_radius=theme.radius_scale.sm,
    padding=0.0,
  )
}

///|
fn editor_source_layout(
  _app : MarkdownEditorApp,
  binding : @core.Binding[String],
  snapshot : MarkdownEditorSnapshot,
  editor_font : @core.FontSpec,
  theme : @core.Theme,
  show_source : Bool,
  target_bar : @core.View[MarkdownEditorMsg],
  selection : MarkdownEditorSelection,
  target_kind : MarkdownEditorTargetKind,
  scroll_offset : @core.Point,
  on_selection_change : (Int, @core.TextRange?) -> MarkdownEditorMsg,
  on_prefix_click : (Int) -> MarkdownEditorMsg,
) -> @core.View[MarkdownEditorMsg] {
  let editor_width = if show_source { 640.0 } else { 780.0 }
  let viewport_height = 520.0
  let content_height = markdown_editor_max_double(
    viewport_height,
    @core.rich_text_document_height(snapshot.rich_text, editor_font) + 72.0,
  )
  let max_scroll = markdown_editor_max_double(
    0.0,
    content_height - viewport_height,
  )
  let normalized_offset = @core.Point::new(
    x=0.0,
    y=markdown_editor_clamp_double(scroll_offset.y, 0.0, max_scroll),
  )
  let editor = scroll_view(
    editor_page(
      markdown_editor_binding(
        binding,
        source => markdown_editor_format_for_selection(source, selection),
        placeholder="Start writing Markdown",
        variant=@views.TextFieldVariant::Plain,
        theme~,
        font=Some(editor_font),
        width=editor_width,
        height=content_height,
        on_selection_change=Some(on_selection_change),
        on_prefix_click=Some(on_prefix_click),
        input_transform=Some(markdown_editor_transform_input),
      ).key("markdown-editor"),
      theme,
      width=editor_width,
      height=content_height,
    ),
    offset=normalized_offset,
    width=editor_width,
    height=viewport_height,
    on_scroll=Some(delta => {
      EditorScrollTo(
        markdown_editor_clamp_double(
          normalized_offset.y - delta.y,
          0.0,
          max_scroll,
        ),
      )
    }),
  )
  if !show_source {
    floating_target_palette(
      editor, target_bar, snapshot, selection, target_kind, editor_font, theme, normalized_offset,
      editor_width, viewport_height,
    )
  } else {
    let editor_and_source = row(
      [editor, source_inspector(snapshot.source, theme, height=viewport_height)],
      spacing=theme.spacing_scale.lg,
      align=@views.CrossAlign::Start,
    )
    column(
      if target_kind == PlainSelection {
        [editor_and_source]
      } else {
        [editor_and_source, target_bar]
      },
      spacing=theme.spacing_scale.md,
      align=@views.CrossAlign::Start,
    )
  }
}

///|
fn editor_page(
  editor : @core.View[MarkdownEditorMsg],
  theme : @core.Theme,
  width~ : Double,
  height~ : Double,
) -> @core.View[MarkdownEditorMsg] {
  stack([
    surface(
      spacer(min_length=0.0, weight=0.0),
      width~,
      height~,
      variant=@views.SurfaceVariant::Raised,
      theme~,
      background=@core.Color::white(),
      corner_radius=theme.radius_scale.sm,
      padding=0.0,
    ),
    editor,
  ])
}

///|
fn source_preview_lines(
  text : String,
  theme : @core.Theme,
) -> @core.View[MarkdownEditorMsg] {
  let font = @core.FontSpec::new(
    families=@core.FontFamilyStack::named("SFMono-Regular")
      .with_fallback(@core.FontFamily::UiMonospace)
      .with_fallback(@core.FontFamily::Monospace),
    size=12.0,
    weight=400,
  )
  let children : Array[@core.View[MarkdownEditorMsg]] = []
  for line in markdown_split_lines(markdown_editor_preview_text(text)) {
    children.push(source_preview_line(line, font, theme.palette.foreground))
  }
  column(children, spacing=0.0, align=@views.CrossAlign::Start)
}

///|
fn source_preview_line(
  line : String,
  font : @core.FontSpec,
  color : @core.Color,
) -> @core.View[MarkdownEditorMsg] {
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
  width? : Double = 1120.0,
  height? : Double = 720.0,
) -> @core.AppRuntime {
  let runtime = @core.AppRuntime::new_component_view(
    root=ctx => self.root(ctx),
    size=@core.Size::new(width~, height~),
    on_message=Some(message => self.update(message)),
  )
  runtime.set_action_commands(self.action_commands())
  runtime
}

///|
fn sample_markdown() -> String {
  "# Editor notes\n\nThis **WYSIWYG** surface keeps `Markdown` as the saved value.\n\n## Today\n- Type into the formatted page\n- Use shortcuts or contextual controls\n- Open source only when needed\n\n> Unsupported syntax stays editable as plain text.\n\n```\nlet saved = markdown\n```\n\n---"
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
