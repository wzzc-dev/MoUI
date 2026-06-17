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
