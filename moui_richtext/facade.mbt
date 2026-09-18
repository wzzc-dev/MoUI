///|
fn markdown_document(
  source : String,
  base? : @core.FontSpec = @core.FontSpec::new(),
) -> RichTextDocument {
  markdown_editor_format(source, base~)
}

///|
fn markdown_input_transform(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
  inserted : String,
) -> RichTextInputTransform? {
  markdown_editor_transform_input(source, caret, selection, inserted)
}

///|
pub fn[Msg] markdown_editor(
  value~ : String,
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
    value~,
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
  scroll_glide? : MarkdownScrollGlide = MarkdownScrollGlide::settled(0.0),
  on_scroll? : ((Double, Double) -> Msg)? = None,
  visible_viewport_height? : Double = 0.0,
  visible_overscan? : Double = 320.0,
  key? : String? = None,
) -> @core.View[Msg] {
  controlled_markdown_session_editor_snapshot(
    session~,
    selection~,
    on_transaction~,
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
    source_mode~,
    focus_mode~,
    base_dir~,
    on_selection_change~,
    on_prefix_click~,
    on_command_click~,
    accepts_tab_input~,
    scroll_glide~,
    on_scroll~,
    visible_viewport_height~,
    visible_overscan~,
    key~,
  )
}

///|
fn[Msg] controlled_markdown_session_editor_snapshot(
  session~ : MarkdownDocumentSession,
  selection~ : MarkdownEditorSelection,
  on_transaction~ : (MarkdownEditTransaction) -> Msg,
  placeholder~ : String,
  size~ : @core.Size,
  font~ : @core.FontSpec,
  foreground~ : @core.Color,
  placeholder_color~ : @core.Color,
  background~ : @core.Brush,
  border~ : @core.BorderStyle?,
  focused_border~ : @core.BorderStyle?,
  cursor_color~ : @core.Color,
  corner_radius~ : Double,
  source_mode~ : Bool,
  focus_mode~ : Bool,
  base_dir~ : String?,
  on_selection_change~ : ((Int, @core.TextRange?) -> Msg)?,
  on_prefix_click~ : ((Int) -> Msg)?,
  on_command_click~ : ((Int) -> Msg)?,
  accepts_tab_input~ : Bool,
  scroll_glide~ : MarkdownScrollGlide,
  on_scroll~ : ((Double, Double) -> Msg)?,
  visible_viewport_height~ : Double,
  visible_overscan~ : Double,
  key~ : String?,
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
      scroll_glide,
      visible_viewport_height,
      visible_overscan,
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
        // Hit-testing and visual caret moves use the same frame-local offset
        // as paint. A retained paint may have published a measurement delta
        // before the app rebuilds its glide, so include that pending delta.
        visible_scroll_y=node.scroll_glide.display_offset(
          ctx.now_ms,
          compensation=markdown_scroll_peek_geometry_compensation(),
        ),
        on_scroll~,
        visible_viewport_height=node.visible_viewport_height,
        visible_overscan=node.visible_overscan,
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
    semantics_actions=node => {
      [
        @core.ViewSemanticsActionHandler::set_text((_ctx, next_source) => {
          @core.ViewSemanticsActionResult::message(
            on_transaction(
              MarkdownEditTransaction::from_sources(
                node.session.source(),
                next_source,
                caret=text_length(next_source),
                selection=None,
              ),
            ),
          )
        }),
      ]
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
  /// The scroll transition to draw: evaluated at paint/event time from the
  /// runtime animation clock, never resolved into a stored offset.
  scroll_glide : MarkdownScrollGlide
  visible_viewport_height : Double
  visible_overscan : Double
  key : String?
}

///|
impl @core.ViewNode for MarkdownSessionEditorViewNode with fn identity(self) {
  @core.ViewIdentity::new(kind="MarkdownSessionEditor", key=self.key)
}

///|
impl @core.ViewNode for MarkdownSessionEditorViewNode with fn declaration(self) {
  rich_text_declaration(
    layout=rich_text_exact_channel(declaration_size_key(self.size)),
    paint=rich_text_exact_channel(
      rich_text_record_key("MarkdownSessionEditor.paint", [
        // Identity of the painted source via the session's maintained
        // (length, digest) pair. Encoding the whole document into the key
        // here would make every keystroke pay an O(document) UTF-8 pass,
        // a fresh key buffer, and a full memcmp against the previous key.
        ("source_length", @core.DeclarationKey::int(self.session.source_length)),
        (
          "source_digest",
          @core.DeclarationKey::uint64(self.session.source_digest),
        ),
        ("selection_caret", @core.DeclarationKey::int(self.selection.caret)),
        (
          "selection_range",
          declaration_text_range_option_key(self.selection.selection),
        ),
        ("placeholder", @core.DeclarationKey::string(self.placeholder)),
        ("font", declaration_font_key(self.font)),
        ("foreground", declaration_color_key(self.foreground)),
        ("placeholder_color", declaration_color_key(self.placeholder_color)),
        ("background", declaration_brush_key(self.background)),
        ("border", declaration_border_option_key(self.border)),
        ("focused_border", declaration_border_option_key(self.focused_border)),
        ("cursor_color", declaration_color_key(self.cursor_color)),
        ("corner_radius", @core.DeclarationKey::double(self.corner_radius)),
        ("source_mode", @core.DeclarationKey::bool(self.source_mode)),
        ("focus_mode", @core.DeclarationKey::bool(self.focus_mode)),
        (
          "base_dir",
          @core.DeclarationKey::option(
            self.base_dir.map(@core.DeclarationKey::string),
          ),
        ),
        (
          "accepts_tab_input",
          @core.DeclarationKey::bool(self.accepts_tab_input),
        ),
        (
          "scroll_glide",
          @core.DeclarationKey::record(
            type_tag="moui_richtext.MarkdownScrollGlide.v2",
            fields=[
              ("from_y", @core.DeclarationKey::double(self.scroll_glide.from_y)),
              ("to_y", @core.DeclarationKey::double(self.scroll_glide.to_y)),
              (
                "start_ms",
                @core.DeclarationKey::double(self.scroll_glide.start_ms),
              ),
              ("tau_ms", @core.DeclarationKey::double(self.scroll_glide.tau_ms)),
            ],
          ),
        ),
        (
          "viewport_height",
          @core.DeclarationKey::double(self.visible_viewport_height),
        ),
        ("overscan", @core.DeclarationKey::double(self.visible_overscan)),
      ]),
    ),
    semantics=rich_text_exact_channel(
      @core.DeclarationKey::string(self.placeholder),
    ),
  )
}

///|
impl @core.ViewNode for MarkdownSessionEditorViewNode with fn layout(self, ctx) {
  @core.ViewLayoutResult::new(size=ctx.constraints.constrain(self.size))
}

///|
impl @core.ViewNode for MarkdownSessionEditorViewNode with fn paint(self, ctx) {
  markdown_scroll_publish_frame_time(ctx.now_ms)
  // The offset is sampled for THIS frame: the glide is a function of the
  // animation clock, so the position shown is always correct for the frame
  // being drawn (no timer tick grid to beat against the display refresh).
  // A retained node can paint again before the app consumes the measurement
  // message. Include that pending delta in the frame-local offset so a
  // geometry commit cannot move content backward for one frame.
  let pending_geometry_compensation = markdown_scroll_peek_geometry_compensation()
  let (plan, geometry_compensation) = markdown_session_editor_paint(
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
    visible_scroll_y=self.scroll_glide.display_offset(
      ctx.now_ms,
      compensation=pending_geometry_compensation,
      scale=ctx.environment.scale_factor,
    ),
    visible_viewport_height=self.visible_viewport_height,
    visible_overscan=self.visible_overscan,
  )
  // The application owns the persistent glide. Paint only publishes the
  // measurement compensation; mutating this transient view node as well
  // would apply the same delta a second time when the app consumes it.
  ignore(geometry_compensation)
  // Keep the host's animation-driven redraw loop alive until the glide
  // settles; the runtime stops ticking once this reports false.
  { ..plan, animating: self.scroll_glide.is_animating(ctx.now_ms) }
}

///|
impl @core.ViewNode for MarkdownSessionEditorViewNode with fn text_input_state(
  self,
  ctx,
) {
  Some(
    markdown_session_input_state(
      text=self.session.source(),
      frame=ctx.frame,
      session=self.session,
      selection=self.selection,
      font=self.font,
      control=ctx.text_control,
      source_mode=self.source_mode,
      focus_mode=self.focus_mode,
      base_dir=self.base_dir,
      visible_scroll_y=self.scroll_glide.display_offset(
        ctx.now_ms,
        compensation=markdown_scroll_peek_geometry_compensation(),
      ),
      visible_viewport_height=self.visible_viewport_height,
      visible_overscan=self.visible_overscan,
      text_system=ctx.text_system,
    ),
  )
}

///|
impl @core.ViewNode for MarkdownSessionEditorViewNode with fn semantics(self) {
  @core.ViewSemanticsInfo::new(
    composition=@core.SemanticsComposition::Boundary,
    role=@core.SemanticsRole::TextField,
    label=self.placeholder,
    value="Markdown document",
  )
}

///|
impl @core.ViewNode for MarkdownSessionEditorViewNode with fn focusable(_self) {
  true
}
