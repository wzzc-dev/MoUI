///|
pub fn text_field(
  value : @core.Binding[String],
  placeholder? : String = "",
  width? : Double = 240.0,
  height? : Double = 40.0,
) -> @core.ViewSpec {
  text_field_base(value, placeholder~, width~, height~, None)
}

///|
pub fn text_field_on_submit(
  value : @core.Binding[String],
  on_submit : () -> Unit,
  placeholder? : String = "",
  width? : Double = 240.0,
  height? : Double = 40.0,
) -> @core.ViewSpec {
  text_field_base(value, placeholder~, width~, height~, Some(on_submit))
}

///|
fn text_field_base(
  value : @core.Binding[String],
  placeholder~ : String,
  width~ : Double,
  height~ : Double,
  on_submit : (() -> Unit)?,
) -> @core.ViewSpec {
  @core.ViewSpec::TextFieldSpec({
    key: None,
    value,
    placeholder,
    size: @core.Size::new(width~, height~),
    font: @core.FontSpec::new(size=16.0, weight=400),
    foreground: @core.Color::black(),
    placeholder_color: @core.Color::gray(),
    background: @core.Color::white(),
    border_color: @core.Color::gray(),
    focused_border_color: @core.Color::blue(),
    cursor_color: @core.Color::blue(),
    corner_radius: 0.0,
    on_submit,
  })
}
