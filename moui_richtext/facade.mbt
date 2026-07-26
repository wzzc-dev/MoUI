///|
pub fn markdown_document(
  source : String,
  base? : @core.FontSpec = @core.FontSpec::new(),
) -> RichTextDocument {
  markdown_editor_format(source, base~)
}

///|
/// A read-only plain text viewer that renders text using proper text
/// measurement and word-wrapping, matching the RichText pipeline.
pub fn[Msg] text_viewer(
  source~ : String,
  size~ : @core.Size,
  font? : @core.FontSpec = @core.FontSpec::new(),
  foreground? : @core.Color = @core.Color::black(),
  key? : String? = None,
) -> @core.View[Msg] {
  let cache = RichTextDocumentViewCache::new()
  @core.View::from_node(TextViewerNode::{
    source,
    size,
    font,
    foreground,
    key,
    cache,
  })
}

///|
priv struct TextViewerNode {
  source : String
  size : @core.Size
  font : @core.FontSpec
  foreground : @core.Color
  key : String?
  cache : RichTextDocumentViewCache
}

///|
impl @core.ViewNode for TextViewerNode with fn identity(self) {
  @core.ViewIdentity::new(kind="TextViewer", key=self.key)
}

///|
impl @core.ViewNode for TextViewerNode with fn revision(self) {
  "text-viewer:\{self.source.length()}:\{view_size_revision(self.size)}:\{view_font_revision(self.font)}:\{view_color_revision(self.foreground)}"
}

///|
impl @core.ViewNode for TextViewerNode with fn layout(self, ctx) {
  let measured_height = rich_text_document_session_view_measure_height(
    self.source,
    self.size,
    self.font,
    ctx.text_system,
    self.cache,
  )
  let measured = @core.Size::new(width=self.size.width, height=measured_height)
  @core.ViewLayoutResult::new(size=ctx.constraints.constrain(measured))
}

///|
impl @core.ViewNode for TextViewerNode with fn paint(self, ctx) {
  rich_text_document_session_view_paint(
    ctx,
    self.source,
    self.font,
    self.foreground,
    @core.Brush::solid(@core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0)),
    0.0,
    0.0,
    0.0,
    320.0,
    None,
    self.cache,
  )
}

///|
impl @core.ViewNode for TextViewerNode with fn semantics(self) {
  @core.ViewSemanticsInfo::new(
    role=@core.SemanticsRole::Text,
    label=self.source,
  )
}

///|
pub fn markdown_input_transform(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
  inserted : String,
) -> RichTextInputTransform? {
  markdown_editor_transform_input(source, caret, selection, inserted)
}

///|
pub fn[Msg] markdown_editor(
  value~ : @core.Binding[String],
  placeholder~ : String,
  size~ : @core.Size,
  font~ : @core.FontSpec,
  foreground~ : @core.Color,
  placeholder_color~ : @core.Color,
  background~ : @core.Brush,
  border? : @core.BorderStyle? = None,
  focused_border? : @core.BorderStyle? = None,
  cursor_color~ : @core.Color,
  corner_radius? : Double = 0.0,
  on_input? : ((String) -> Msg)? = None,
  on_selection_change? : ((Int, @core.TextRange?) -> Msg)? = None,
  on_prefix_click? : ((Int) -> Msg)? = None,
  accepts_tab_input? : Bool = true,
  key? : String? = None,
) -> @core.View[Msg] {
  rich_text_editor(
    value~,
    placeholder~,
    size~,
    format=source => markdown_document(source, base=font),
    font~,
    foreground~,
    placeholder_color~,
    background~,
    border~,
    focused_border~,
    cursor_color~,
    corner_radius~,
    on_input~,
    on_selection_change~,
    on_prefix_click~,
    input_transform=Some(markdown_input_transform),
    accepts_tab_input~,
    kind="MarkdownEditor",
    key~,
  )
}

///|
pub fn[Msg] controlled_markdown_editor(
  value~ : String,
  on_input~ : (String) -> Msg,
  placeholder~ : String,
  size~ : @core.Size,
  font~ : @core.FontSpec,
  foreground~ : @core.Color,
  placeholder_color~ : @core.Color,
  background~ : @core.Brush,
  border? : @core.BorderStyle? = None,
  focused_border? : @core.BorderStyle? = None,
  cursor_color~ : @core.Color,
  corner_radius? : Double = 0.0,
  on_selection_change? : ((Int, @core.TextRange?) -> Msg)? = None,
  on_prefix_click? : ((Int) -> Msg)? = None,
  accepts_tab_input? : Bool = true,
  key? : String? = None,
) -> @core.View[Msg] {
  markdown_editor(
    value=@core.Binding::new(get=() => value, set=_next => ()),
    placeholder~,
    size~,
    font~,
    foreground~,
    placeholder_color~,
    background~,
    border~,
    focused_border~,
    cursor_color~,
    corner_radius~,
    on_input=Some(on_input),
    on_selection_change~,
    on_prefix_click~,
    accepts_tab_input~,
    key~,
  )
}

///|
pub fn[Msg] controlled_markdown_session_editor(
  session~ : MarkdownDocumentSession,
  selection~ : MarkdownEditorSelection,
  on_transaction~ : (MarkdownEditTransaction) -> Msg,
  placeholder~ : String,
  size~ : @core.Size,
  font~ : @core.FontSpec,
  foreground~ : @core.Color,
  placeholder_color~ : @core.Color,
  background~ : @core.Brush,
  border? : @core.BorderStyle? = None,
  focused_border? : @core.BorderStyle? = None,
  cursor_color~ : @core.Color,
  corner_radius? : Double = 0.0,
  source_mode? : Bool = false,
  focus_mode? : Bool = false,
  base_dir? : String? = None,
  on_selection_change? : ((Int, @core.TextRange?) -> Msg)? = None,
  on_prefix_click? : ((Int) -> Msg)? = None,
  on_command_click? : ((Int) -> Msg)? = None,
  accepts_tab_input? : Bool = true,
  visible_scroll_y? : Double = 0.0,
  visible_viewport_height? : Double = 0.0,
  visible_overscan? : Double = 320.0,
  visible_scroll_state? : @core.ScrollState? = None,
  key? : String? = None,
) -> @core.View[Msg] {
  @core.View::from_node(
    MarkdownSessionEditorViewNode::{
      session,
      selection,
      placeholder,
      size,
      font,
      foreground,
      placeholder_color,
      background,
      border,
      focused_border,
      cursor_color,
      corner_radius,
      source_mode,
      focus_mode,
      base_dir,
      accepts_tab_input,
      visible_scroll_y,
      visible_viewport_height,
      visible_overscan,
      visible_scroll_state,
      key,
    },
    event=(node, ctx) => {
      markdown_session_editor_event(
        ctx,
        session=node.session,
        selection=node.selection,
        on_transaction~,
        font=node.font,
        source_mode=node.source_mode,
        focus_mode=node.focus_mode,
        base_dir=node.base_dir,
        on_selection_change~,
        on_prefix_click~,
        on_command_click~,
        accepts_tab_input=node.accepts_tab_input,
        visible_scroll_y=node.visible_scroll_y,
        visible_viewport_height=node.visible_viewport_height,
        visible_overscan=node.visible_overscan,
        visible_scroll_state=node.visible_scroll_state,
      )
    },
    text_command=(node, ctx, intent, paste_text) => {
      markdown_session_editor_command(
        ctx,
        session=node.session,
        selection=node.selection,
        on_transaction~,
        on_selection_change~,
        font=node.font,
        source_mode=node.source_mode,
        focus_mode=node.focus_mode,
        base_dir=node.base_dir,
        intent,
        paste_text~,
      )
    },
  )
}

///|
priv struct MarkdownSessionEditorViewNode {
  session : MarkdownDocumentSession
  selection : MarkdownEditorSelection
  placeholder : String
  size : @core.Size
  font : @core.FontSpec
  foreground : @core.Color
  placeholder_color : @core.Color
  background : @core.Brush
  border : @core.BorderStyle?
  focused_border : @core.BorderStyle?
  cursor_color : @core.Color
  corner_radius : Double
  source_mode : Bool
  focus_mode : Bool
  base_dir : String?
  accepts_tab_input : Bool
  visible_scroll_y : Double
  visible_viewport_height : Double
  visible_overscan : Double
  visible_scroll_state : @core.ScrollState?
  key : String?
}

///|
impl @core.ViewNode for MarkdownSessionEditorViewNode with fn identity(self) {
  @core.ViewIdentity::new(kind="MarkdownSessionEditor", key=self.key)
}

///|
impl @core.ViewNode for MarkdownSessionEditorViewNode with fn revision(self) {
  "markdown-session-editor:\{self.session.revision}:\{self.session.blocks.length()}:\{self.selection.caret}:\{view_text_range_option_revision(self.selection.selection)}:\{self.placeholder}:\{view_size_revision(self.size)}:\{view_font_revision(self.font)}:\{view_color_revision(self.foreground)}:\{view_color_revision(self.placeholder_color)}:\{view_brush_revision(self.background)}:\{view_border_option_revision(self.border)}:\{view_border_option_revision(self.focused_border)}:\{view_color_revision(self.cursor_color)}:\{self.corner_radius}:\{self.source_mode}:\{self.focus_mode}:\{self.accepts_tab_input}"
}

///|
impl @core.ViewNode for MarkdownSessionEditorViewNode with fn paint_revision(
  self,
) {
  "markdown-session-editor-scroll:\{markdown_session_current_scroll_y(self.visible_scroll_y, self.visible_scroll_state)}"
}

///|
impl @core.ViewNode for MarkdownSessionEditorViewNode with fn layout(self, ctx) {
  @core.ViewLayoutResult::new(size=ctx.constraints.constrain(self.size))
}

///|
impl @core.ViewNode for MarkdownSessionEditorViewNode with fn paint(self, ctx) {
  markdown_session_editor_paint(
    ctx,
    session=self.session,
    selection=self.selection,
    placeholder=self.placeholder,
    font=self.font,
    foreground=self.foreground,
    placeholder_color=self.placeholder_color,
    background=self.background,
    border=self.border,
    focused_border=self.focused_border,
    cursor_color=self.cursor_color,
    corner_radius=self.corner_radius,
    source_mode=self.source_mode,
    focus_mode=self.focus_mode,
    base_dir=self.base_dir,
    visible_scroll_y=self.visible_scroll_y,
    visible_viewport_height=self.visible_viewport_height,
    visible_overscan=self.visible_overscan,
    visible_scroll_state=self.visible_scroll_state,
  )
}

///|
impl @core.ViewNode for MarkdownSessionEditorViewNode with fn text_input_state(
  self,
  ctx,
) {
  Some(
    markdown_session_input_state(
      text=self.session.source,
      frame=ctx.frame,
      session=self.session,
      selection=self.selection,
      font=self.font,
      control=ctx.text_control,
      source_mode=self.source_mode,
      focus_mode=self.focus_mode,
      base_dir=self.base_dir,
      visible_scroll_y=self.visible_scroll_y,
      visible_viewport_height=self.visible_viewport_height,
      visible_overscan=self.visible_overscan,
      visible_scroll_state=self.visible_scroll_state,
      text_system=ctx.text_system,
    ),
  )
}

///|
impl @core.ViewNode for MarkdownSessionEditorViewNode with fn semantics(self) {
  @core.ViewSemanticsInfo::new(
    role=@core.SemanticsRole::TextField,
    label=self.placeholder,
    value="Markdown document",
    actions=[
      @core.SemanticsAction::Focus,
      @core.SemanticsAction::SetText,
      @core.SemanticsAction::Submit,
    ],
  )
}

///|
impl @core.ViewNode for MarkdownSessionEditorViewNode with fn focusable(_self) {
  true
}
