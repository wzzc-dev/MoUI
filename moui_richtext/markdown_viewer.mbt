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
  key? : String? = None,
) -> @core.View[Msg] {
  markdown_viewer_snapshot(
    source~,
    size~,
    font~,
    foreground~,
    background~,
    corner_radius~,
    on_link_click~,
    visible_scroll_y~,
    visible_viewport_height~,
    visible_overscan~,
    key~,
  )
}

///|
fn[Msg] markdown_viewer_snapshot(
  source~ : String,
  size~ : @core.Size,
  font~ : @core.FontSpec,
  foreground~ : @core.Color,
  background~ : @core.Brush,
  corner_radius~ : Double,
  on_link_click~ : ((String) -> Msg)?,
  visible_scroll_y~ : Double,
  visible_viewport_height~ : Double,
  visible_overscan~ : Double,
  key~ : String?,
) -> @core.View[Msg] {
  @core.View::from_node(
    MarkdownViewerNode::{
      source,
      size,
      font,
      foreground,
      background,
      corner_radius,
      visible_scroll_y,
      visible_viewport_height,
      visible_overscan,
      key,
    },
    event=(node, ctx) => {
      markdown_viewer_event(
        ctx,
        source=node.source,
        font=node.font,
        on_link_click~,
        visible_scroll_y~,
        visible_viewport_height=node.visible_viewport_height,
        visible_overscan=node.visible_overscan,
      )
    },
  )
}

///|
priv struct MarkdownViewerNode {
  source : String
  size : @core.Size
  font : @core.FontSpec
  foreground : @core.Color
  background : @core.Brush
  corner_radius : Double
  visible_scroll_y : Double
  visible_viewport_height : Double
  visible_overscan : Double
  key : String?
}

///|
impl @core.ViewNode for MarkdownViewerNode with fn identity(self) {
  @core.ViewIdentity::new(kind="MarkdownViewer", key=self.key)
}

///|
impl @core.ViewNode for MarkdownViewerNode with fn declaration(self) {
  rich_text_declaration(
    layout=rich_text_exact_channel(
      rich_text_record_key("MarkdownViewer.layout", [
        ("source", @core.DeclarationKey::string(self.source)),
        ("size", declaration_size_key(self.size)),
        ("font", declaration_font_key(self.font)),
      ]),
    ),
    paint=rich_text_exact_channel(
      rich_text_record_key("MarkdownViewer.paint", [
        ("foreground", declaration_color_key(self.foreground)),
        ("background", declaration_brush_key(self.background)),
        ("corner_radius", @core.DeclarationKey::double(self.corner_radius)),
        ("scroll_y", @core.DeclarationKey::double(self.visible_scroll_y)),
        (
          "viewport_height",
          @core.DeclarationKey::double(self.visible_viewport_height),
        ),
        ("overscan", @core.DeclarationKey::double(self.visible_overscan)),
      ]),
    ),
  )
}

///|
impl @core.ViewNode for MarkdownViewerNode with fn layout(self, ctx) {
  // The editor's block list supplies a fixed row height. In that mode layout
  // must not parse and shape the same block just to discover a height that the
  // parent immediately clamps back to `self.size.height`; paint performs the
  // cached preparation only for visible rows. A zero height keeps the general
  // viewer's intrinsic-size behavior for unconstrained callers.
  let measured_height = if self.size.height > 0.0 {
    self.size.height
  } else {
    let cache = RichTextDocumentViewCache::new()
    rich_text_document_session_view_measure_height(
      self.source,
      self.size,
      self.font,
      ctx.text_system,
      cache,
    )
  }
  let measured = @core.Size::new(width=self.size.width, height=measured_height)
  @core.ViewLayoutResult::new(size=ctx.constraints.constrain(measured))
}

///|
impl @core.ViewNode for MarkdownViewerNode with fn paint(self, ctx) {
  let cache = RichTextDocumentViewCache::new()
  rich_text_document_session_view_paint(
    ctx,
    self.source,
    self.font,
    self.foreground,
    self.background,
    self.corner_radius,
    self.visible_scroll_y,
    self.visible_viewport_height,
    self.visible_overscan,
    cache,
  )
}

///|
impl @core.ViewNode for MarkdownViewerNode with fn semantics(_self) {
  @core.ViewSemanticsInfo::new(
    composition=@core.SemanticsComposition::Boundary,
    role=@core.SemanticsRole::ScrollView,
    label="Markdown document",
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
