///|
pub struct MarkdownEditorApp {
  document : @core.State[String]
  selection : @core.State[MarkdownEditorSelection]
  link_target : @core.State[String]
  image_target : @core.State[String]
  target_kind : @core.State[MarkdownEditorTargetKind]
  block_label : @core.State[String]
  undo_stack : @core.State[Array[MarkdownEditorHistoryEntry]]
  redo_stack : @core.State[Array[MarkdownEditorHistoryEntry]]
}

///|
pub(all) struct MarkdownEditorHistoryEntry {
  source : String
  selection : MarkdownEditorSelection
} derive(Eq, Debug, ToJson)

///|
pub(all) enum MarkdownEditorTargetKind {
  PlainSelection
  LinkTarget
  ImageTarget
} derive(Eq, Debug, ToJson)

///|
pub fn MarkdownEditorApp::new() -> MarkdownEditorApp {
  {
    document: @core.State::new(sample_markdown()),
    selection: @core.State::new({ caret: 0, selection: None }),
    link_target: @core.State::new("https://moui.dev"),
    image_target: @core.State::new("assets/image.png"),
    target_kind: @core.State::new(PlainSelection),
    block_label: @core.State::new("Paragraph"),
    undo_stack: @core.State::new([]),
    redo_stack: @core.State::new([]),
  }
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
  self.selection.set({ caret: 0, selection: None })
  self.clear_history()
  self.sync_target_inputs()
}

///|
pub fn MarkdownEditorApp::clear(self : MarkdownEditorApp) -> Unit {
  self.document.set("")
  self.selection.set({ caret: 0, selection: None })
  self.clear_history()
  self.sync_target_inputs()
}

///|
pub fn MarkdownEditorApp::apply_action(
  self : MarkdownEditorApp,
  action : String,
) -> Unit {
  match markdown_command_from_action(action) {
    Some(command) => self.apply_command_to_selection(command)
    None => ()
  }
}

///|
pub fn MarkdownEditorApp::apply_command(
  self : MarkdownEditorApp,
  command : MarkdownEditorCommand,
) -> Unit {
  self.apply_command_to_selection(command)
}

///|
pub fn MarkdownEditorApp::apply_command_to_selection(
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
pub fn MarkdownEditorApp::undo(self : MarkdownEditorApp) -> Bool {
  self.restore_history(undo=true)
}

///|
pub fn MarkdownEditorApp::redo(self : MarkdownEditorApp) -> Bool {
  self.restore_history(undo=false)
}

///|
pub fn MarkdownEditorApp::can_undo(self : MarkdownEditorApp) -> Bool {
  self.undo_stack.get().length() > 0
}

///|
pub fn MarkdownEditorApp::can_redo(self : MarkdownEditorApp) -> Bool {
  self.redo_stack.get().length() > 0
}

///|
pub fn MarkdownEditorApp::set_selection(
  self : MarkdownEditorApp,
  caret : Int,
  selection : @core.TextRange?,
) -> Unit {
  self.selection.set({ caret, selection })
  self.sync_target_inputs()
}

///|
pub fn MarkdownEditorApp::set_link_target(
  self : MarkdownEditorApp,
  target : String,
) -> Unit {
  self.link_target.set(target)
}

///|
pub fn MarkdownEditorApp::set_image_target(
  self : MarkdownEditorApp,
  target : String,
) -> Unit {
  self.image_target.set(target)
}

///|
pub fn MarkdownEditorApp::link_target(self : MarkdownEditorApp) -> String {
  self.link_target.get()
}

///|
pub fn MarkdownEditorApp::image_target(self : MarkdownEditorApp) -> String {
  self.image_target.get()
}

///|
pub fn MarkdownEditorApp::target_kind(
  self : MarkdownEditorApp,
) -> MarkdownEditorTargetKind {
  self.target_kind.get()
}

///|
pub fn MarkdownEditorApp::block_label(self : MarkdownEditorApp) -> String {
  self.block_label.get()
}

///|
pub fn MarkdownEditorApp::apply_link_target(self : MarkdownEditorApp) -> Unit {
  self.apply_command_to_selection(SetLinkTarget(self.link_target.get()))
}

///|
pub fn MarkdownEditorApp::apply_image_target(self : MarkdownEditorApp) -> Unit {
  self.apply_command_to_selection(SetImageTarget(self.image_target.get()))
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
fn MarkdownEditorApp::clear_history(self : MarkdownEditorApp) -> Unit {
  self.undo_stack.set([])
  self.redo_stack.set([])
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
  self.block_label.set(
    markdown_editor_active_block_label(self.document.get(), selection),
  )
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
    None => self.target_kind.set(PlainSelection)
  }
}

///|
pub fn MarkdownEditorApp::toggle_task_at(
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
pub fn MarkdownEditorApp::root(
  self : MarkdownEditorApp,
  ctx : @core.BuildContext,
) -> @core.ViewSpec {
  let theme = @core.Theme::light()
  let document = ctx.watch(self.document)
  let snapshot = MarkdownEditorSnapshot::parse(document)
  let binding = ctx.binding(self.document)
  let editor_style = @core.TextFieldStyle::outline(theme~)
  let source_style = @core.SurfaceStyle::default(theme~)
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
          (caret, selection) => self.set_selection(caret, selection),
          offset => self.toggle_task_at(offset),
        ),
        self.target_bar(ctx, theme),
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
        "Current milestone keeps source preview visible while the editor core tracks blocks, source ranges, and rich text output.",
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
        toolbar_button("Src", () => self.apply_image_target(), style),
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
          "Block",
          () => self.apply_command_to_selection(CodeBlock),
          style,
        ).keyboard_shortcut(markdown_editor_shortcut("k")),
        toolbar_button("Undo", () => ignore(self.undo()), style),
        toolbar_button("Redo", () => ignore(self.redo()), style),
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
fn toolbar_button(
  label : String,
  action : () -> Unit,
  style : @core.ButtonStyle,
) -> @core.ViewSpec {
  @views.button(label, on_click=action, style~, width=64.0, height=34.0)
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
  on_selection_change : (Int, @core.TextRange?) -> Unit,
  on_prefix_click : (Int) -> Unit,
) -> @core.ViewSpec {
  @views.row(
    [
      @views.markdown_editor(
        binding,
        markdown_editor_format,
        placeholder="Start writing Markdown",
        style=editor_style,
        width=560.0,
        height=400.0,
        on_selection_change=Some(on_selection_change),
        on_prefix_click=Some(on_prefix_click),
        input_transform=Some(markdown_editor_transform_input),
      ).key("markdown-editor"),
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
pub fn markdown_apply_action(text : String, action : String) -> String {
  match markdown_command_from_action(action) {
    Some(command) =>
      markdown_editor_apply_command_at(
        text,
        command,
        Some({ caret: markdown_editor_text_length(text), selection: None }),
      ).source
    None => text
  }
}

///|
fn markdown_command_from_action(action : String) -> MarkdownEditorCommand? {
  if action == "bold" {
    Some(Bold)
  } else if action == "italic" {
    Some(Italic)
  } else if action == "code" {
    Some(Code)
  } else if action == "strike" {
    Some(Strikethrough)
  } else if action == "link" {
    Some(Link)
  } else if action == "link-target" {
    Some(SetLinkTarget("https://moui.dev"))
  } else if action == "image" {
    Some(Image)
  } else if action == "image-target" {
    Some(SetImageTarget("assets/image.png"))
  } else if action == "paragraph" {
    Some(Paragraph)
  } else if action == "h1" {
    Some(Heading(1))
  } else if action == "h2" {
    Some(Heading(2))
  } else if action == "h3" {
    Some(Heading(3))
  } else if action == "ul" {
    Some(BulletList)
  } else if action == "task" {
    Some(TaskList)
  } else if action == "ol" {
    Some(OrderedList)
  } else if action == "quote" {
    Some(Quote)
  } else if action == "rule" {
    Some(HorizontalRule)
  } else if action == "table" {
    Some(Table)
  } else if action == "codeblock" {
    Some(CodeBlock)
  } else {
    None
  }
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
