///|
/// A floating format bubble that appears above the current selection, mimicking
/// Typora's selection-triggered toolbar. It offers the high-frequency inline
/// and block formatting commands (bold/italic/strike/code/link, heading,
/// list/quote) as a compact row of ghost buttons. The bubble hides when the
/// selection collapses to a caret or the editor loses focus.
fn MarkdownEditorApp::format_bubble(
  self : MarkdownEditorApp,
  theme : @moui.Theme,
) -> @moui.View[MarkdownEditorMsg] {
  // No non-empty selection → no bubble.
  let has_range = match self.selection.get().selection {
    Some(range) => range.start != range.end
    None => false
  }
  if !has_range || self.zen_mode_enabled.get() {
    @views.empty()
  } else {
    let bubble = @views.container(
      @views.row(
        [
          format_bubble_button("B", "Bold", ApplyCommand(Bold), theme),
          format_bubble_button("I", "Italic", ApplyCommand(Italic), theme),
          format_bubble_button("S", "Strikethrough", ApplyCommand(Strikethrough), theme),
          format_bubble_button("</>", "Code", ApplyCommand(Code), theme),
          format_bubble_button("H1", "Heading 1", ApplyCommand(Heading(1)), theme),
          format_bubble_button("H2", "Heading 2", ApplyCommand(Heading(2)), theme),
          format_bubble_button("•", "Bullet list", ApplyCommand(BulletList), theme),
          format_bubble_button("❝", "Quote", ApplyCommand(Quote), theme),
          format_bubble_button("🔗", "Link", ApplyCommand(Link), theme),
        ],
        spacing=theme.spacing_scale.xs,
        align=@views.CrossAlign::Center,
      ),
      variant=@views.ContainerVariant::Raised,
      theme~,
      padding=theme.spacing_scale.xs,
    )
    bubble
  }
}

///|
/// A compact ghost button for the format bubble.
fn format_bubble_button(
  glyph : String,
  tooltip_label : String,
  message : MarkdownEditorMsg,
  theme : @moui.Theme,
) -> @moui.View[MarkdownEditorMsg] {
  tooltip(
    @views.button(
      glyph,
      on_click=message,
      variant=@views.ButtonVariant::Ghost,
      theme~,
      width=32.0,
      height=30.0,
    ),
    tooltip_label,
  )
}

///|
/// Position the format bubble above the selection start. Laid out as an overlay
/// child of the editor stack so it floats over the page card. Returns empty
/// when there is no non-empty selection.
fn markdown_editor_format_bubble_overlay(
  app : MarkdownEditorApp,
  snapshot : MarkdownEditorSnapshot,
  selection : MarkdownEditorSelection,
  editor_font : @core.FontSpec,
  theme : @moui.Theme,
  scroll_offset : @moui.Point,
  editor_width : Double,
  viewport_height : Double,
) -> @moui.View[MarkdownEditorMsg] {
  let has_range = match selection.selection {
    Some(range) => range.start != range.end
    None => false
  }
  if !has_range || app.zen_mode_enabled.get() ||
    app.source_mode_enabled.get() {
    @views.empty()
  } else {
    let bubble = app.format_bubble(theme)
    @views.custom_children_layout(
      children=[bubble],
      measure=ctx =>
        ctx.constraints.constrain(@moui.Size::new(width=editor_width, height=viewport_height)),
      place=ctx => {
        let bubble_size = ctx.child_sizes[0]
        let editor_frame = @core.Rect::new(
          x=ctx.frame.origin.x,
          y=ctx.frame.origin.y,
          width=editor_width,
          height=viewport_height,
        )
        let caret = match selection.selection {
          Some(range) => range.normalized().start
          None => selection.caret
        }
        let content = @moui_richtext.rich_text_editor_content_rect(
          editor_frame,
        ).offset(dx=0.0, dy=-scroll_offset.y)
        match
          @moui_richtext.rich_text_document_caret_rect_at_source(
            snapshot.rich_text,
            caret,
            content,
            editor_font,
          ) {
          Some(rect) => {
            let x = markdown_editor_clamp_double(
              rect.origin.x + rect.size.width / 2.0 - bubble_size.width / 2.0,
              0.0,
              markdown_editor_max_double(
                0.0,
                editor_width - bubble_size.width,
              ),
            )
            let preferred_above = rect.origin.y -
              bubble_size.height -
              theme.spacing_scale.sm
            let y = if preferred_above >= editor_frame.origin.y {
              preferred_above
            } else {
              rect.origin.y + rect.size.height + theme.spacing_scale.sm
            }
            [
              @core.Rect::new(
                x~,
                y~,
                width=bubble_size.width,
                height=bubble_size.height,
              ),
            ]
          }
          None =>
            [
              @core.Rect::new(
                x=ctx.frame.origin.x,
                y=ctx.frame.origin.y,
                width=0.0,
                height=0.0,
              ),
            ]
        }
      },
    )
  }
}
