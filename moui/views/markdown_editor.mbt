///|
pub fn[Msg] rich_text_editor(
  value : String,
  format : RichTextFormatter,
  on_input~ : (String) -> Msg,
  placeholder? : String = "Write",
  variant? : TextFieldVariant = TextFieldVariant::Filled,
  theme? : @core.Theme = default_theme(),
  style? : TextFieldStyle,
  font? : @core.FontSpec? = None,
  width? : Double = 520.0,
  height? : Double = 360.0,
  on_selection_change? : ((Int, @core.TextRange?) -> Msg)? = None,
  on_prefix_click? : ((Int) -> Msg)? = None,
  input_transform? : ((String, Int, @core.TextRange?, String) -> RichTextInputTransform?)? = None,
  accepts_tab_input? : Bool = false,
) -> @core.View[Msg] {
  let resolved_style = match style {
    Some(value) => value
    None => variant.style(theme)
  }
  let normal = resolved_style.normal
  let focused = resolved_style.focused
  @widget.controlled_rich_text_editor(
    value~,
    on_input~,
    placeholder~,
    size=@core.Size::new(width~, height~),
    format~,
    font=font.unwrap_or(resolved_style.font),
    foreground=normal.foreground,
    placeholder_color=resolved_style.placeholder_color,
    background=normal.background,
    border=normal.border,
    focused_border=focused.border,
    cursor_color=resolved_style.cursor_color,
    corner_radius=normal.radius,
    on_selection_change~,
    on_prefix_click~,
    input_transform~,
    accepts_tab_input~,
  )
}

///|
pub fn[Msg] markdown_editor(
  value : String,
  format : RichTextFormatter,
  on_input~ : (String) -> Msg,
  placeholder? : String = "Write markdown",
  variant? : TextFieldVariant = TextFieldVariant::Filled,
  theme? : @core.Theme = default_theme(),
  style? : TextFieldStyle,
  font? : @core.FontSpec? = None,
  width? : Double = 520.0,
  height? : Double = 360.0,
  on_selection_change? : ((Int, @core.TextRange?) -> Msg)? = None,
  on_prefix_click? : ((Int) -> Msg)? = None,
  input_transform? : ((String, Int, @core.TextRange?, String) -> RichTextInputTransform?)? = None,
  accepts_tab_input? : Bool = true,
) -> @core.View[Msg] {
  rich_text_editor(
    value,
    format,
    on_input~,
    placeholder~,
    variant~,
    theme~,
    style?,
    font~,
    width~,
    height~,
    on_selection_change~,
    on_prefix_click~,
    input_transform~,
    accepts_tab_input~,
  )
}

///|
pub fn[Msg] rich_text_editor_binding(
  value : @core.Binding[String],
  format : RichTextFormatter,
  placeholder? : String = "Write",
  variant? : TextFieldVariant = TextFieldVariant::Filled,
  theme? : @core.Theme = default_theme(),
  style? : TextFieldStyle,
  font? : @core.FontSpec? = None,
  width? : Double = 520.0,
  height? : Double = 360.0,
  on_selection_change? : ((Int, @core.TextRange?) -> Msg)? = None,
  on_prefix_click? : ((Int) -> Msg)? = None,
  input_transform? : ((String, Int, @core.TextRange?, String) -> RichTextInputTransform?)? = None,
  accepts_tab_input? : Bool = false,
) -> @core.View[Msg] {
  let resolved_style = match style {
    Some(value) => value
    None => variant.style(theme)
  }
  let normal = resolved_style.normal
  let focused = resolved_style.focused
  @widget.rich_text_editor(
    value~,
    placeholder~,
    size=@core.Size::new(width~, height~),
    format~,
    font=font.unwrap_or(resolved_style.font),
    foreground=normal.foreground,
    placeholder_color=resolved_style.placeholder_color,
    background=normal.background,
    border=normal.border,
    focused_border=focused.border,
    cursor_color=resolved_style.cursor_color,
    corner_radius=normal.radius,
    on_selection_change~,
    on_prefix_click~,
    input_transform~,
    accepts_tab_input~,
  )
}

///|
pub fn[Msg] markdown_editor_binding(
  value : @core.Binding[String],
  format : RichTextFormatter,
  placeholder? : String = "Write markdown",
  variant? : TextFieldVariant = TextFieldVariant::Filled,
  theme? : @core.Theme = default_theme(),
  style? : TextFieldStyle,
  font? : @core.FontSpec? = None,
  width? : Double = 520.0,
  height? : Double = 360.0,
  on_selection_change? : ((Int, @core.TextRange?) -> Msg)? = None,
  on_prefix_click? : ((Int) -> Msg)? = None,
  input_transform? : ((String, Int, @core.TextRange?, String) -> RichTextInputTransform?)? = None,
  accepts_tab_input? : Bool = true,
) -> @core.View[Msg] {
  rich_text_editor_binding(
    value,
    format,
    placeholder~,
    variant~,
    theme~,
    style?,
    font~,
    width~,
    height~,
    on_selection_change~,
    on_prefix_click~,
    input_transform~,
    accepts_tab_input~,
  )
}
