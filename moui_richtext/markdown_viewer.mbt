///|
/// A read-only markdown viewer that renders markdown source using the same
/// `MarkdownDocumentSession` pipeline as the markdown editor, but without
/// editing capabilities (no caret, selection, IME, or keyboard input).
///
/// The viewer is designed for embedding inside a `scroll_view` or similar
/// scrollable parent. Pass `visible_scroll_y`, `visible_viewport_height`, and
/// `visible_overscan` so the paint pass can cull off-screen blocks for
/// performance, matching the session editor's windowed rendering strategy.
pub fn[Msg] markdown_viewer(
  source~ : String,
  size~ : @core.Size,
  font? : @core.FontSpec = @core.FontSpec::new(),
  foreground? : @core.Color = @core.Color::black(),
  background? : @core.Brush = @core.Brush::solid(
    @core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0),
  ),
  corner_radius? : Double = 0.0,
  on_link_click? : ((String) -> Msg)? = None,
  visible_scroll_y? : Double = 0.0,
  visible_viewport_height? : Double = 0.0,
  visible_overscan? : Double = 320.0,
  visible_scroll_state? : @core.ScrollState? = None,
  key? : String? = None,
) -> @core.View[Msg] {
  let cache = RichTextDocumentViewCache::new()
  @core.View::node(
    identity=() => @core.ViewIdentity::new(kind="MarkdownViewer", key~),
    revision=() => {
      "markdown-viewer:\{source.length()}:\{view_size_revision(size)}:\{view_font_revision(font)}:\{view_color_revision(foreground)}:\{view_brush_revision(background)}:\{corner_radius}"
    },
    paint_revision=() => {
      "markdown-viewer-scroll:\{markdown_session_current_scroll_y(visible_scroll_y, visible_scroll_state)}"
    },
    layout=ctx => {
      let measured_height = rich_text_document_session_view_measure_height(
        source,
        size,
        font,
        ctx.text_system,
        cache,
      )
      let measured = @core.Size::new(width=size.width, height=measured_height)
      @core.ViewLayoutResult::new(size=ctx.constraints.constrain(measured))
    },
    paint=ctx => {
      rich_text_document_session_view_paint(
        ctx, source, font, foreground, background, corner_radius, visible_scroll_y,
        visible_viewport_height, visible_overscan, visible_scroll_state, cache,
      )
    },
    event=ctx => {
      markdown_viewer_event(
        ctx,
        source~,
        font~,
        on_link_click~,
        visible_scroll_y~,
        visible_viewport_height~,
        visible_overscan~,
        visible_scroll_state~,
      )
    },
    semantics=() => {
      @core.ViewSemanticsInfo::new(
        role=@core.SemanticsRole::ScrollView,
        label="Markdown document",
      )
    },
  )
}

///|
fn[Msg] markdown_viewer_event(
  ctx : @core.ViewEventContext,
  source~ : String,
  font~ : @core.FontSpec,
  on_link_click~ : ((String) -> Msg)?,
  visible_scroll_y~ : Double,
  visible_viewport_height~ : Double,
  visible_overscan~ : Double,
  visible_scroll_state~ : @core.ScrollState?,
) -> @core.ViewEventResult[Msg] {
  match on_link_click {
    Some(handler) =>
      match ctx.event {
        @core.AppEvent::Pointer(event) =>
          if event.phase == @core.PointerPhase::Up && event.button == 0 {
            match
              rich_text_document_session_view_offset_at_point(
                source,
                event.position,
                ctx.frame,
                font,
                ctx.text_system,
                visible_scroll_y,
                visible_viewport_height,
                visible_overscan,
                visible_scroll_state,
              ) {
              Some(offset) =>
                match markdown_editor_link_context_at_caret(source, offset) {
                  Some(context) =>
                    match
                      markdown_editor_reference_target(source, context.bounds) {
                      Some(target) =>
                        view_event_result(captured=true, messages=[
                          handler(target),
                        ])
                      None => view_event_result()
                    }
                  None => view_event_result()
                }
              None => view_event_result()
            }
          } else {
            view_event_result()
          }
        _ => view_event_result()
      }
    None => view_event_result()
  }
}
