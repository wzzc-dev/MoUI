///|
pub fn markdown_document(
  source : String,
  base? : @core.FontSpec = @core.FontSpec::new(),
) -> RichTextDocument {
  markdown_editor_format(source, base~)
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
  @core.View::node(
    identity=() => @core.ViewIdentity::new(kind="MarkdownSessionEditor", key~),
    revision=() => {
      "markdown-session-editor:\{session.revision}:\{session.blocks.length()}:\{selection.caret}:\{view_text_range_option_revision(selection.selection)}:\{placeholder}:\{view_size_revision(size)}:\{view_font_revision(font)}:\{view_color_revision(foreground)}:\{view_color_revision(placeholder_color)}:\{view_brush_revision(background)}:\{view_border_option_revision(border)}:\{view_border_option_revision(focused_border)}:\{view_color_revision(cursor_color)}:\{corner_radius}:\{source_mode}:\{focus_mode}:\{accepts_tab_input}"
    },
    paint_revision=() => {
      "markdown-session-editor-scroll:\{markdown_session_current_scroll_y(visible_scroll_y, visible_scroll_state)}"
    },
    layout=ctx => {
      @core.ViewLayoutResult::new(size=ctx.constraints.constrain(size))
    },
    paint=ctx => {
      markdown_session_editor_paint(
        ctx,
        session~,
        selection~,
        placeholder~,
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
        visible_scroll_y~,
        visible_viewport_height~,
        visible_overscan~,
        visible_scroll_state~,
      )
    },
    event=ctx => {
      markdown_session_editor_event(
        ctx,
        session~,
        selection~,
        on_transaction~,
        font~,
        source_mode~,
        focus_mode~,
        base_dir~,
        on_selection_change~,
        on_prefix_click~,
        on_command_click~,
        accepts_tab_input~,
        visible_scroll_y~,
        visible_viewport_height~,
        visible_overscan~,
        visible_scroll_state~,
      )
    },
    text_input_state=ctx => {
      Some(
        markdown_session_input_state(
          text=session.source,
          frame=ctx.frame,
          session~,
          selection~,
          font~,
          control=ctx.text_control,
          source_mode~,
          focus_mode~,
          base_dir~,
          visible_scroll_y~,
          visible_viewport_height~,
          visible_overscan~,
          visible_scroll_state~,
          text_system=ctx.text_system,
        ),
      )
    },
    text_command=(ctx, intent, paste_text) => {
      markdown_session_editor_command(
        ctx,
        session~,
        selection~,
        on_transaction~,
        on_selection_change~,
        font~,
        source_mode~,
        focus_mode~,
        base_dir~,
        intent,
        paste_text~,
      )
    },
    semantics=() => {
      @core.ViewSemanticsInfo::new(
        role=@core.SemanticsRole::TextField,
        label=placeholder,
        value="Markdown document",
        actions=[
          @core.SemanticsAction::Focus,
          @core.SemanticsAction::SetText,
          @core.SemanticsAction::Submit,
        ],
      )
    },
    focusable=() => true,
  )
}
