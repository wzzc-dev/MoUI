///|
pub fn rich_text_editor(
  value : @core.Binding[String],
  format : @core.RichTextFormatter,
  placeholder? : String = "Write",
  variant? : TextFieldVariant = TextFieldVariant::Filled,
  theme? : @core.Theme = @core.Theme::default(),
  font? : @core.FontSpec? = None,
  width? : Double = 520.0,
  height? : Double = 360.0,
  on_selection_change? : ((Int, @core.TextRange?) -> Unit)? = None,
  on_prefix_click? : ((Int) -> Unit)? = None,
  input_transform? : ((String, Int, @core.TextRange?, String) -> @core.RichTextInputTransform?)? = None,
  accepts_tab_input? : Bool = false,
) -> @core.ViewSpec {
  let style = variant.style(theme)
  let normal = style.normal
  let focused = style.focused
  @core.ViewSpec::RichTextEditorSpec({
    key: None,
    value,
    placeholder,
    size: @core.Size::new(width~, height~),
    format,
    font: font.unwrap_or(style.font),
    foreground: normal.foreground,
    placeholder_color: style.placeholder_color,
    background: normal.background,
    border: normal.border,
    focused_border: focused.border,
    cursor_color: style.cursor_color,
    corner_radius: normal.radius,
    on_selection_change,
    on_prefix_click,
    input_transform,
    accepts_tab_input,
  })
}

///|
pub fn markdown_editor(
  value : @core.Binding[String],
  format : @core.RichTextFormatter,
  placeholder? : String = "Write markdown",
  variant? : TextFieldVariant = TextFieldVariant::Filled,
  theme? : @core.Theme = @core.Theme::default(),
  font? : @core.FontSpec? = None,
  width? : Double = 520.0,
  height? : Double = 360.0,
  on_selection_change? : ((Int, @core.TextRange?) -> Unit)? = None,
  on_prefix_click? : ((Int) -> Unit)? = None,
  input_transform? : ((String, Int, @core.TextRange?, String) -> @core.RichTextInputTransform?)? = None,
  accepts_tab_input? : Bool = true,
) -> @core.ViewSpec {
  rich_text_editor(
    value,
    format,
    placeholder~,
    variant~,
    theme~,
    font~,
    width~,
    height~,
    on_selection_change~,
    on_prefix_click~,
    input_transform~,
    accepts_tab_input~,
  )
}
