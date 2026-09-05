///|
using @views {fill_rect, draw_text}

///|
fn MarkdownEditorApp::target_bar(
  self : MarkdownEditorApp,
  theme : @moui.Theme,
) -> @moui.View[MarkdownEditorMsg] {
  let kind = self.target_kind
  let block_label = self.block_label
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
            self.link_target,
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
            self.image_target,
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
            self.footnote_text,
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
            self.html_block_text,
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
                Some(@text.TextAlign::TextStart),
              ),
            ),
            @views.ButtonVariant::Tonal,
            theme,
          ),
          editor_button(
            "Center",
            ApplyCommand(
              MarkdownEditorCommand::SetTableColumnAlignment(
                Some(@text.TextAlign::TextCenter),
              ),
            ),
            @views.ButtonVariant::Tonal,
            theme,
          ),
          editor_button(
            "Right",
            ApplyCommand(
              MarkdownEditorCommand::SetTableColumnAlignment(
                Some(@text.TextAlign::TextEnd),
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
  editor : @moui.View[MarkdownEditorMsg],
  target_bar : @moui.View[MarkdownEditorMsg],
  session : MarkdownDocumentSession,
  selection : MarkdownEditorSelection,
  target_kind : MarkdownEditorTargetKind,
  editor_font : @text.FontSpec,
  theme : @moui.Theme,
  scroll_offset : @geometry.Point,
  width : Double,
  height : Double,
) -> @moui.View[MarkdownEditorMsg] {
  let palette = if target_kind == PlainSelection {
    empty()
  } else {
    container(
      target_bar,
      variant=@views.ContainerVariant::Raised,
      theme~,
      padding=theme.spacing_scale.xs,
    )
  }
  @views.custom_children_layout(
    children=[editor, palette],
    measure=_ => @geometry.Size::new(width~, height~),
    place=ctx => {
      let palette_size = if ctx.children.length() > 1 {
        ctx.children[1].size
      } else {
        @geometry.Size::new(width=0.0, height=0.0)
      }
      let editor_frame = @geometry.Rect::new(
        x=ctx.frame.origin.x,
        y=ctx.frame.origin.y,
        width=ctx.frame.size.width,
        height~,
      )
      let palette_width = markdown_editor_min_double(palette_size.width, width)
      let anchor = markdown_editor_palette_anchor(
        session,
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
        @geometry.Rect::new(
          x=palette_x,
          y=palette_y,
          width=palette_width,
          height=palette_size.height,
        ),
      ]
    },
    semantics_label="Markdown editor floating target palette",
    paint=(_ctx, _frame) => (),
  )
}

///|
fn markdown_editor_palette_anchor(
  session : MarkdownDocumentSession,
  selection : MarkdownEditorSelection,
  target_kind : MarkdownEditorTargetKind,
  editor_frame : @geometry.Rect,
  editor_font : @text.FontSpec,
  palette_width : Double,
  palette_height : Double,
  scroll_offset : @geometry.Point,
  theme : @moui.Theme,
) -> @geometry.Point {
  if target_kind == PlainSelection {
    return @geometry.Point::new(
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
  match
    markdown_editor_session_caret_rect(
      session,
      selection,
      caret,
      editor_frame,
      editor_font,
      scroll_offset,
      viewport_height=editor_frame.size.height,
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
      @geometry.Point::new(x~, y~)
    }
    None =>
      @geometry.Point::new(
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
fn markdown_editor_session_caret_rect(
  session : MarkdownDocumentSession,
  selection : MarkdownEditorSelection,
  caret : Int,
  editor_frame : @geometry.Rect,
  editor_font : @text.FontSpec,
  scroll_offset : @geometry.Point,
  viewport_height~ : Double,
  source_mode? : Bool = false,
  focus_mode? : Bool = false,
  base_dir? : String? = None,
) -> @geometry.Rect? {
  let window = session.rich_text_window(
    selection,
    base=editor_font,
    source_mode~,
    focus_mode~,
    base_dir~,
    scroll_y=scroll_offset.y,
    viewport_height~,
    overscan=markdown_editor_visible_overscan(viewport_height),
    content_width=@moui_richtext.rich_text_editor_content_rect(editor_frame).size.width,
  )
  let content = @moui_richtext.rich_text_editor_content_rect(editor_frame).offset(
    dx=0.0,
    dy=window.top_padding - scroll_offset.y,
  )
  @moui_richtext.rich_text_document_caret_rect_at_source(
    window.document,
    caret,
    content,
    editor_font,
  )
}

///|
fn editor_button(
  label : String,
  message : MarkdownEditorMsg,
  variant : @views.ButtonVariant,
  theme : @moui.Theme,
) -> @moui.View[MarkdownEditorMsg] {
  let width = if markdown_editor_text_length(label) > 5 { 78.0 } else { 64.0 }
  button(label, on_click=message, variant~, theme~, width~, height=34.0)
}

///|
/// A compact ghost icon button for the find bar (prev/next/close), with a
/// tooltip describing the action.
fn editor_find_icon_button(
  icon : @views.IconName,
  tooltip_label : String,
  message : MarkdownEditorMsg,
  theme : @moui.Theme,
) -> @moui.View[MarkdownEditorMsg] {
  tooltip(
    button(
      "",
      on_click=message,
      variant=@views.ButtonVariant::Ghost,
      theme~,
      icon=Some(icon),
      width=34.0,
      height=34.0,
    ),
    tooltip_label,
  )
}

///|
/// A compact toggle chip for find/replace options. Renders as a small ghost
/// button that switches to Tonal when active, with a tooltip describing the
/// option.
fn editor_find_toggle(
  glyph : String,
  tooltip_label : String,
  message : MarkdownEditorMsg,
  active : Bool,
  theme : @moui.Theme,
) -> @moui.View[MarkdownEditorMsg] {
  let variant = if active {
    @views.ButtonVariant::Tonal
  } else {
    @views.ButtonVariant::Ghost
  }
  tooltip(
    button(glyph, on_click=message, variant~, theme~, width=34.0, height=34.0),
    tooltip_label,
  )
}

///|
fn MarkdownEditorApp::appearance_spec(
  self : MarkdownEditorApp,
) -> MarkdownEditorAppearanceSpec {
  let base = self.writing_appearance.spec(dark=self.dark_mode_enabled)
  { ..base, font_family: markdown_editor_font_family_stack(self.font_family) }
}

///|
/// Map the user's font-family choice to a FontFamilyStack.
fn markdown_editor_font_family_stack(
  family : MarkdownEditorFontFamily,
) -> @text.FontFamilyStack {
  match family {
    SansFont => markdown_editor_typora_github_font_family_stack()
    SerifFont => @text.FontFamilyStack::serif()
    MonoFont => @text.FontFamilyStack::monospace()
  }
}

///|
/// Typora's default Github theme uses Open Sans first, then platform sans
/// fallbacks. Native Skia will use the first installed family in this stack.
fn markdown_editor_typora_github_font_family_stack() -> @text.FontFamilyStack {
  @text.FontFamilyStack::named("Open Sans")
  .with_fallback(@text.FontFamily::Name("Clear Sans"))
  .with_fallback(@text.FontFamily::Name("Helvetica Neue"))
  .with_fallback(@text.FontFamily::Name("Helvetica"))
  .with_fallback(@text.FontFamily::Name("Arial"))
  .with_fallback(@text.FontFamily::Name("Segoe UI Emoji"))
  .with_fallback(@text.FontFamily::Name("SF Pro"))
  .with_fallback(@text.FontFamily::SansSerif)
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
  dark? : Bool = false,
) -> MarkdownEditorAppearanceSpec {
  match self {
    PaperAppearance =>
      if dark {
        {
          label: "Paper",
          editor_font_size: 17.0,
          page_width: markdown_editor_page_width(),
          side_editor_width: markdown_editor_source_editor_width(),
          foreground: @graphics.Color::rgba(r=0.90, g=0.90, b=0.90),
          placeholder: @graphics.Color::white().multiply_alpha(0.32),
          page_background: @graphics.Color::rgba(r=0.13, g=0.14, b=0.16),
          window_background: @graphics.Color::rgba(r=0.13, g=0.14, b=0.16),
          font_family: @text.FontFamilyStack::sans_serif(),
        }
      } else {
        {
          label: "Paper",
          editor_font_size: 17.0,
          page_width: markdown_editor_page_width(),
          side_editor_width: markdown_editor_source_editor_width(),
          foreground: @graphics.Color::rgba(r=0.12, g=0.12, b=0.12),
          placeholder: @graphics.Color::black().multiply_alpha(0.35),
          page_background: @graphics.Color::white(),
          window_background: @graphics.Color::white(),
          font_family: @text.FontFamilyStack::sans_serif(),
        }
      }
    WarmAppearance =>
      if dark {
        {
          label: "Warm",
          editor_font_size: 18.0,
          page_width: 724.0,
          side_editor_width: 604.0,
          foreground: @graphics.Color::rgba(r=0.92, g=0.88, b=0.80),
          placeholder: @graphics.Color::rgba(r=0.80, g=0.72, b=0.60, a=0.40),
          page_background: @graphics.Color::rgba(r=0.16, g=0.14, b=0.11),
          window_background: @graphics.Color::rgba(r=0.16, g=0.14, b=0.11),
          font_family: @text.FontFamilyStack::sans_serif(),
        }
      } else {
        {
          label: "Warm",
          editor_font_size: 18.0,
          page_width: 724.0,
          side_editor_width: 604.0,
          foreground: @graphics.Color::rgba(r=0.18, g=0.14, b=0.10),
          placeholder: @graphics.Color::rgba(r=0.38, g=0.28, b=0.18, a=0.46),
          page_background: @graphics.Color::rgba(r=1.0, g=0.984, b=0.936),
          window_background: @graphics.Color::rgba(r=1.0, g=0.984, b=0.936),
          font_family: @text.FontFamilyStack::sans_serif(),
        }
      }
    WideAppearance =>
      if dark {
        {
          label: "Wide",
          editor_font_size: 16.5,
          page_width: 920.0,
          side_editor_width: 720.0,
          foreground: @graphics.Color::rgba(r=0.86, g=0.90, b=0.94),
          placeholder: @graphics.Color::rgba(r=0.60, g=0.70, b=0.80, a=0.40),
          page_background: @graphics.Color::rgba(r=0.11, g=0.13, b=0.16),
          window_background: @graphics.Color::rgba(r=0.11, g=0.13, b=0.16),
          font_family: @text.FontFamilyStack::sans_serif(),
        }
      } else {
        {
          label: "Wide",
          editor_font_size: 16.5,
          page_width: 920.0,
          side_editor_width: 720.0,
          foreground: @graphics.Color::rgba(r=0.10, g=0.12, b=0.15),
          placeholder: @graphics.Color::rgba(r=0.16, g=0.20, b=0.26, a=0.36),
          page_background: @graphics.Color::rgba(r=0.986, g=0.990, b=0.994),
          window_background: @graphics.Color::rgba(r=0.986, g=0.990, b=0.994),
          font_family: @text.FontFamilyStack::sans_serif(),
        }
      }
  }
}

///|
fn markdown_editor_appearance_font(
  appearance : MarkdownEditorAppearanceSpec,
) -> @text.FontSpec {
  @text.FontSpec::new(
    size=appearance.editor_font_size,
    families=appearance.font_family,
  )
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
fn markdown_editor_sidebar_total_width(
  show_source : Bool,
  show_outline : Bool,
  show_files : Bool,
  show_info : Bool,
) -> Double {
  let mut width = 0.0
  if show_files {
    width = width + markdown_editor_file_sidebar_width()
  }
  if show_info {
    width = width + markdown_editor_info_inspector_width()
  }
  if show_outline {
    width = width + markdown_editor_outline_inspector_width()
  }
  if show_source {
    width = width + markdown_editor_source_inspector_width()
  }
  width
}

///|
fn markdown_editor_primary_editor_width_for_viewport(
  show_source : Bool,
  show_outline : Bool,
  show_files : Bool,
  show_info : Bool,
  appearance : MarkdownEditorAppearanceSpec,
  viewport_width~ : Double,
) -> Double {
  let preferred = markdown_editor_primary_editor_width(
    show_source, show_outline, show_files, show_info, appearance,
  )
  let sidebars_width = markdown_editor_sidebar_total_width(
    show_source, show_outline, show_files, show_info,
  )
  let available = markdown_editor_max_double(
    0.0,
    viewport_width - sidebars_width,
  )
  markdown_editor_min_double(preferred, available)
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
/// A thin scroll indicator drawn at the right edge of the editor viewport.
/// The framework's `scroll_view` exposes only the current offset (not the
/// content size), so this is a presence indicator — visible while the document
/// is scrolled — rather than a proportional thumb. It fades out at the top so
/// the page edge stays clean when unscrolled.
fn markdown_editor_scroll_indicator(
  scroll : @geometry.Point,
  viewport_height~ : Double,
  theme : @moui.Theme,
) -> @moui.View[MarkdownEditorMsg] {
  let offset_y = scroll.y
  // Hide entirely while at the top (no content scrolled past).
  if offset_y <= 0.0 {
    @views.empty()
  } else {
    let indicator_alpha = if offset_y > 40.0 {
      0.5
    } else {
      offset_y / 40.0 * 0.5
    }
    custom_layout(
      measure=constraints => {
        constraints.constrain(
          @geometry.Size::new(width=0.0, height=viewport_height),
        )
      },
      paint=(ctx, frame) => {
        // A 3px-wide track pinned to the right edge of the laid-out frame.
        let track_x = frame.origin.x + frame.size.width - 3.0
        let track = @geometry.Rect::new(
          x=track_x,
          y=frame.origin.y,
          width=3.0,
          height=frame.size.height,
        )
        let thumb_height = markdown_editor_max_double(
          40.0,
          frame.size.height * 0.18,
        )
        // Position the thumb proportionally to the offset within the visible
        // region (approximate, since content size is unknown).
        let max_thumb_travel = markdown_editor_max_double(
          1.0,
          frame.size.height - thumb_height,
        )
        let thumb_y = track.origin.y +
          markdown_editor_min_double(max_thumb_travel, offset_y / 4.0)
        let track_color = theme.palette.muted.multiply_alpha(0.18)
        let thumb_color = theme.palette.muted.multiply_alpha(indicator_alpha)
        fill_rect(ctx, track, track_color)
        fill_rect(
          ctx,
          @geometry.Rect::new(
            x=track.origin.x,
            y=thumb_y,
            width=track.size.width,
            height=thumb_height,
          ),
          thumb_color,
        )
      },
      semantics_label="Editor scroll indicator",
    )
  }
}

///|
fn markdown_editor_viewport_height() -> Double {
  520.0
}

///|
fn markdown_editor_page_shadow() -> @graphics.ShadowStyle {
  @graphics.ShadowStyle::new(
    color=@graphics.Color::white().multiply_alpha(0.12),
    offset=@geometry.Point::new(x=0.0, y=2.0),
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
fn markdown_editor_visible_overscan(viewport_height : Double) -> Double {
  markdown_editor_min_double(320.0, viewport_height * 0.5)
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
  session : MarkdownDocumentSession,
  editor_font : @text.FontSpec,
  appearance : MarkdownEditorAppearanceSpec,
  theme : @moui.Theme,
  show_source : Bool,
  show_outline : Bool,
  show_files : Bool,
  show_info : Bool,
  target_bar : @moui.View[MarkdownEditorMsg],
  selection : MarkdownEditorSelection,
  target_kind : MarkdownEditorTargetKind,
  scroll_offset : @geometry.Point,
  on_selection_change : (Int, @text.TextRange?) -> MarkdownEditorMsg,
  on_prefix_click : (Int) -> MarkdownEditorMsg,
  viewport_width? : Double = 1120.0,
  viewport_height? : Double = 520.0,
) -> @moui.View[MarkdownEditorMsg] {
  let editor_width = markdown_editor_primary_editor_width_for_viewport(
    show_source,
    show_outline,
    show_files,
    show_info,
    appearance,
    viewport_width~,
  )
  let source_mode = app.source_mode_enabled
  let content_height = markdown_editor_max_double(
    viewport_height,
    session.estimated_content_height(
      base=editor_font,
      source_mode~,
      content_width=markdown_editor_max_double(0.0, editor_width - 28.0),
    ) +
    96.0,
  )
  let max_scroll = markdown_editor_max_double(
    0.0,
    content_height - viewport_height,
  )
  let normalized_offset = @geometry.Point::new(
    x=0.0,
    y=markdown_editor_clamp_double(scroll_offset.y, 0.0, max_scroll),
  )
  let page_brush = @graphics.Brush::solid(appearance.page_background)
  let editor_style : @views.TextFieldStyle = @views.TextFieldStyle::new(
    normal=@views.new_control_state_style(
      foreground=appearance.foreground,
      background=page_brush,
      radius=theme.radius_scale.md,
    ),
    focused=@views.new_control_state_style(
      foreground=appearance.foreground,
      background=page_brush,
      radius=theme.radius_scale.md,
    ),
    disabled=@views.new_control_state_style(
      foreground=appearance.foreground,
      background=page_brush,
      radius=theme.radius_scale.md,
    ),
    placeholder_color=appearance.placeholder,
    cursor_color=theme.palette.primary,
    font=editor_font,
  )
  let editor_control = controlled_markdown_session_editor(
    session~,
    selection~,
    on_transaction=transaction => ApplyEditorTransaction(transaction),
    placeholder="Start writing Markdown",
    size=@geometry.Size::new(width=editor_width, height=viewport_height),
    font=editor_style.font(),
    foreground=appearance.foreground,
    placeholder_color=editor_style.placeholder_color(),
    background=page_brush,
    border=None,
    focused_border=None,
    cursor_color=editor_style.cursor_color(),
    corner_radius=theme.radius_scale.md,
    source_mode~,
    focus_mode=app.focus_mode_enabled,
    base_dir=markdown_editor_document_base_dir(app.document_path),
    on_selection_change=Some(on_selection_change),
    on_prefix_click=Some(on_prefix_click),
    on_command_click=Some(offset => CommandClickAt(offset)),
    accepts_tab_input=true,
    visible_scroll_y=normalized_offset.y,
    on_scroll=Some(y => EditorScrollChanged(@geometry.Point::new(x=0.0, y~))),
    visible_viewport_height=viewport_height,
    visible_overscan=markdown_editor_visible_overscan(viewport_height),
  ).key("markdown-editor")
  let editor = editor_page(editor_control, theme, appearance).on_file_drop((
    paths,
    _position,
  ) => {
    match paths {
      [path, ..] if path != "" => InsertMediaFromFileDrop(path)
      _ => DismissAuxiliaryPanels
    }
  })
  // Temporarily disabled: floating block-target palette (the "Block: ..." /
  // Apply overlay). Uncomment the if/else below and drop the direct binding
  // to re-enable it.
  // let editor_view = if !show_source && !app.source_mode_enabled {
  //   floating_target_palette(
  //     editor, target_bar, session, selection, target_kind, editor_font, theme,
  //     normalized_offset, editor_width, viewport_height,
  //   )
  // } else {
  //   editor
  // }
  let editor_view = editor

  let editor_with_indicator = @views.stack([
    editor_view,
    markdown_editor_scroll_indicator(app.editor_scroll, viewport_height~, theme),
    // Temporarily disabled: selection-triggered format bubble (B/I/S/... toolbar).
    // markdown_editor_format_bubble_overlay(
    //   app, session, selection, editor_font, theme, normalized_offset, editor_width,
    //   viewport_height,
    // ),
  ])
  let side_children : Array[@moui.View[MarkdownEditorMsg]] = []
  if show_files {
    side_children.push(
      files_inspector(app, session, theme, height=viewport_height),
    )
  }
  side_children.push(spacer(min_length=0.0, weight=1.0))
  side_children.push(editor_with_indicator)
  side_children.push(spacer(min_length=0.0, weight=1.0))
  if show_info {
    side_children.push(
      document_info_inspector(session, theme, height=viewport_height),
    )
  }
  if show_outline {
    side_children.push(
      outline_inspector(app, session, selection, theme, height=viewport_height),
    )
  }
  if show_source {
    side_children.push(
      source_inspector(session.source(), theme, height=viewport_height),
    )
  }
  let editor_and_sidebars = row(
    side_children,
    spacing=0.0,
    align=@views.CrossAlign::Stretch,
  ).frame(width=viewport_width)
  column(
    if target_kind == PlainSelection || !show_source {
      [editor_and_sidebars]
    } else {
      [editor_and_sidebars, target_bar]
    },
    spacing=theme.spacing_scale.md,
    align=@views.CrossAlign::Stretch,
  )
}

///|
fn editor_page(
  editor : @moui.View[MarkdownEditorMsg],
  theme : @moui.Theme,
  _appearance : MarkdownEditorAppearanceSpec,
) -> @moui.View[MarkdownEditorMsg] {
  editor
  .shadow(markdown_editor_page_shadow())
  .corner_radius(theme.radius_scale.sm)
  .repaint_boundary()
}

///|
fn source_preview_lines(
  text : String,
  theme : @moui.Theme,
) -> @moui.View[MarkdownEditorMsg] {
  let font = @text.FontSpec::new(
    families=@text.FontFamilyStack::named("SFMono-Regular")
      .with_fallback(@text.FontFamily::UiMonospace)
      .with_fallback(@text.FontFamily::Monospace),
    size=12.0,
    weight=400,
  )
  let children : Array[@moui.View[MarkdownEditorMsg]] = []
  for line in markdown_split_lines(markdown_editor_preview_text(text)) {
    children.push(source_preview_line(line, font, theme.palette.foreground))
  }
  column(children, spacing=0.0, align=@views.CrossAlign::Start)
}

///|
fn source_preview_line(
  line : String,
  font : @text.FontSpec,
  color : @graphics.Color,
) -> @moui.View[MarkdownEditorMsg] {
  custom_layout(
    measure=_ => @geometry.Size::new(width=260.0, height=18.0),
    paint=(ctx, frame) => {
      draw_text(
        ctx,
        @text.TextRun::new(
          text=line,
          frame~,
          font~,
          color~,
          align=@text.TextAlign::TextStart,
        ),
      )
    },
    semantics_label=line,
  )
}

///|
