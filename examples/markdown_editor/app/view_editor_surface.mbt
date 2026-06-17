///|
fn MarkdownEditorApp::target_bar(
  self : MarkdownEditorApp,
  theme : @core.Theme,
) -> @core.View[MarkdownEditorMsg] {
  let kind = self.target_kind.get()
  let block_label = self.block_label.get()
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
          text_field(
            self.link_target.get(),
            on_input=value => UpdateLinkTarget(value),
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
          editor_button("Open", OpenTarget, @views.ButtonVariant::Ghost, theme),
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
          text_field(
            self.image_target.get(),
            on_input=value => UpdateImageTarget(value),
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
          editor_button("Open", OpenTarget, @views.ButtonVariant::Ghost, theme),
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
          text_field(
            self.footnote_text.get(),
            on_input=value => UpdateFootnoteText(value),
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
          text_field(
            self.html_block_text.get(),
            on_input=value => UpdateHtmlBlockText(value),
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
  let content = @moui_richtext.rich_text_editor_content_rect(editor_frame).offset(
    dx=0.0,
    dy=-scroll_offset.y,
  )
  match
    @moui_richtext.rich_text_document_caret_rect_at_source(
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
  let width = if markdown_editor_text_length(label) > 5 { 78.0 } else { 64.0 }
  button(label, on_click=message, variant~, theme~, width~, height=34.0)
}

///|
fn editor_chrome_button(
  label : String,
  message : MarkdownEditorMsg,
  theme : @core.Theme,
) -> @core.View[MarkdownEditorMsg] {
  let width = if label == "Src" ||
    label == "Nav" ||
    label == "Cmd" ||
    label == "Raw" ||
    label == "Zen" {
    42.0
  } else if label == "Type" {
    48.0
  } else if label == "Focus" {
    58.0
  } else if label == "Save As" {
    76.0
  } else if label == "Open" {
    54.0
  } else if label == "Import" || label == "Export" {
    66.0
  } else if label == "New" {
    48.0
  } else if label == "Save" {
    52.0
  } else {
    54.0
  }
  button(
    label,
    on_click=message,
    variant=@views.ButtonVariant::Ghost,
    theme~,
    width~,
    height=30.0,
  )
}

///|
fn MarkdownEditorApp::appearance_spec(
  self : MarkdownEditorApp,
) -> MarkdownEditorAppearanceSpec {
  self.writing_appearance.get().spec()
}

///|
fn MarkdownEditorApp::appearance_label(self : MarkdownEditorApp) -> String {
  self.appearance_spec().label
}

///|
fn MarkdownEditorAppearance::next(
  self : MarkdownEditorAppearance,
) -> MarkdownEditorAppearance {
  match self {
    PaperAppearance => WarmAppearance
    WarmAppearance => WideAppearance
    WideAppearance => PaperAppearance
  }
}

///|
fn MarkdownEditorAppearance::spec(
  self : MarkdownEditorAppearance,
) -> MarkdownEditorAppearanceSpec {
  match self {
    PaperAppearance =>
      {
        label: "Paper",
        editor_font_size: 17.0,
        page_width: markdown_editor_page_width(),
        side_editor_width: markdown_editor_source_editor_width(),
        foreground: @core.Color::rgba(r=0.12, g=0.12, b=0.12),
        placeholder: @core.Color::black().multiply_alpha(0.35),
        page_background: @core.Color::white(),
        window_background: @core.Color::rgba(r=0.992, g=0.992, b=0.99),
        page_border: @core.Color::black().multiply_alpha(0.10),
      }
    WarmAppearance =>
      {
        label: "Warm",
        editor_font_size: 18.0,
        page_width: 724.0,
        side_editor_width: 604.0,
        foreground: @core.Color::rgba(r=0.18, g=0.14, b=0.10),
        placeholder: @core.Color::rgba(r=0.38, g=0.28, b=0.18, a=0.46),
        page_background: @core.Color::rgba(r=1.0, g=0.984, b=0.936),
        window_background: @core.Color::rgba(r=0.968, g=0.944, b=0.890),
        page_border: @core.Color::rgba(r=0.48, g=0.34, b=0.18, a=0.18),
      }
    WideAppearance =>
      {
        label: "Wide",
        editor_font_size: 16.5,
        page_width: 920.0,
        side_editor_width: 720.0,
        foreground: @core.Color::rgba(r=0.10, g=0.12, b=0.15),
        placeholder: @core.Color::rgba(r=0.16, g=0.20, b=0.26, a=0.36),
        page_background: @core.Color::rgba(r=0.986, g=0.990, b=0.994),
        window_background: @core.Color::rgba(r=0.936, g=0.946, b=0.958),
        page_border: @core.Color::rgba(r=0.18, g=0.24, b=0.32, a=0.16),
      }
  }
}

///|
fn markdown_editor_appearance_font(
  appearance : MarkdownEditorAppearanceSpec,
) -> @core.FontSpec {
  @core.FontSpec::new(size=appearance.editor_font_size)
}

///|
fn markdown_editor_page_width() -> Double {
  780.0
}

///|
fn markdown_editor_primary_editor_width(
  show_source : Bool,
  show_outline : Bool,
  show_files : Bool,
  show_info : Bool,
  appearance : MarkdownEditorAppearanceSpec,
) -> Double {
  if show_source || show_outline || show_files || show_info {
    appearance.side_editor_width
  } else {
    appearance.page_width
  }
}

///|
fn markdown_editor_source_editor_width() -> Double {
  640.0
}

///|
fn markdown_editor_outline_inspector_width() -> Double {
  240.0
}

///|
fn markdown_editor_file_sidebar_width() -> Double {
  240.0
}

///|
fn markdown_editor_info_inspector_width() -> Double {
  240.0
}

///|
fn markdown_editor_outline_content_width() -> Double {
  212.0
}

///|
fn markdown_editor_file_sidebar_content_width() -> Double {
  212.0
}

///|
fn markdown_editor_info_content_width() -> Double {
  212.0
}

///|
fn markdown_editor_source_inspector_width() -> Double {
  292.0
}

///|
fn markdown_editor_viewport_height() -> Double {
  520.0
}

///|
fn markdown_editor_page_shadow() -> @core.ShadowStyle {
  @core.ShadowStyle::new(
    color=@core.Color::black().multiply_alpha(0.12),
    offset=@core.Point::new(x=0.0, y=2.0),
    blur_radius=18.0,
  )
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
fn editor_source_layout(
  app : MarkdownEditorApp,
  source : String,
  snapshot : MarkdownEditorSnapshot,
  editor_font : @core.FontSpec,
  appearance : MarkdownEditorAppearanceSpec,
  theme : @core.Theme,
  show_source : Bool,
  show_outline : Bool,
  show_files : Bool,
  show_info : Bool,
  target_bar : @core.View[MarkdownEditorMsg],
  selection : MarkdownEditorSelection,
  target_kind : MarkdownEditorTargetKind,
  scroll_offset : @core.Point,
  on_selection_change : (Int, @core.TextRange?) -> MarkdownEditorMsg,
  on_prefix_click : (Int) -> MarkdownEditorMsg,
) -> @core.View[MarkdownEditorMsg] {
  let editor_width = markdown_editor_primary_editor_width(
    show_source, show_outline, show_files, show_info, appearance,
  )
  let viewport_height = markdown_editor_viewport_height()
  let content_height = markdown_editor_max_double(
    viewport_height,
    @moui_richtext.rich_text_document_height(snapshot.rich_text, editor_font) +
    96.0,
  )
  let max_scroll = markdown_editor_max_double(
    0.0,
    content_height - viewport_height,
  )
  let normalized_offset = @core.Point::new(
    x=0.0,
    y=markdown_editor_clamp_double(scroll_offset.y, 0.0, max_scroll),
  )
  let editor_style : @views.TextFieldStyle = {
    normal: {
      foreground: appearance.foreground,
      background: @core.Brush::solid(appearance.page_background),
      border: None,
      radius: theme.radius_scale.sm,
      shadow: None,
    },
    focused: {
      foreground: appearance.foreground,
      background: @core.Brush::solid(appearance.page_background),
      border: None,
      radius: theme.radius_scale.sm,
      shadow: None,
    },
    disabled: {
      foreground: appearance.foreground,
      background: @core.Brush::solid(appearance.page_background),
      border: None,
      radius: theme.radius_scale.sm,
      shadow: None,
    },
    placeholder_color: appearance.placeholder,
    cursor_color: theme.palette.primary,
    font: editor_font,
  }
  let editor_format = source => {
    if app.source_mode_enabled.get() {
      markdown_editor_format_source_mode(source, editor_font)
    } else {
      markdown_editor_format_for_writing_mode(
        source,
        selection,
        base=editor_font,
        focus_mode=app.focus_mode_enabled.get(),
      )
    }
  }
  let editor_control = controlled_rich_text_editor(
    value=source,
    on_input=value => UpdateDocument(value),
    placeholder="Start writing Markdown",
    size=@core.Size::new(width=editor_width, height=content_height),
    format=editor_format,
    font=editor_style.font,
    foreground=editor_style.normal.foreground,
    placeholder_color=editor_style.placeholder_color,
    background=editor_style.normal.background,
    border=editor_style.normal.border,
    focused_border=editor_style.focused.border,
    cursor_color=editor_style.cursor_color,
    corner_radius=editor_style.normal.radius,
    on_selection_change=Some(on_selection_change),
    on_prefix_click=Some(on_prefix_click),
    input_transform=Some(markdown_editor_transform_input),
    accepts_tab_input=true,
  ).key("markdown-editor")
  let editor = scroll_view(
    editor_page(editor_control, theme, appearance),
    offset=normalized_offset,
    width=editor_width,
    height=viewport_height,
    state=Some(app.editor_scroll),
  )
  let editor_view = if !show_source && !app.source_mode_enabled.get() {
    floating_target_palette(
      editor, target_bar, snapshot, selection, target_kind, editor_font, theme, normalized_offset,
      editor_width, viewport_height,
    )
  } else {
    editor
  }
  if !show_source && !show_outline && !show_files && !show_info {
    editor_view
  } else {
    let side_children : Array[@core.View[MarkdownEditorMsg]] = []
    if show_files {
      side_children.push(
        files_inspector(app, snapshot, theme, height=viewport_height),
      )
    }
    side_children.push(editor_view)
    if show_info {
      side_children.push(
        document_info_inspector(snapshot, theme, height=viewport_height),
      )
    }
    if show_outline {
      side_children.push(
        outline_inspector(snapshot, selection, theme, height=viewport_height),
      )
    }
    if show_source {
      side_children.push(
        source_inspector(snapshot.source, theme, height=viewport_height),
      )
    }
    let editor_and_sidebars = row(
      side_children,
      spacing=theme.spacing_scale.lg,
      align=@views.CrossAlign::Start,
    )
    column(
      if target_kind == PlainSelection || !show_source {
        [editor_and_sidebars]
      } else {
        [editor_and_sidebars, target_bar]
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
  appearance : MarkdownEditorAppearanceSpec,
) -> @core.View[MarkdownEditorMsg] {
  editor
  .shadow(markdown_editor_page_shadow())
  .border(
    @core.BorderStyle::new(
      brush=@core.Brush::solid(appearance.page_border),
      width=1.0,
    ),
  )
  .corner_radius(theme.radius_scale.sm)
  .repaint_boundary()
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
