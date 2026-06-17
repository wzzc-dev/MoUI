///|
pub fn[Msg] multiline_text_area_shell(
  value : String,
  on_input~ : (String) -> Msg,
  placeholder? : String = "",
  lines? : Int = 4,
  variant? : TextFieldVariant = TextFieldVariant::Outline,
  theme? : @core.Theme = default_theme(),
  width? : Double = 320.0,
  line_height? : Double = 28.0,
) -> @core.View[Msg] {
  text_field(
    value,
    on_input~,
    placeholder~,
    variant~,
    theme~,
    width~,
    height=views_max_double(line_height, lines.to_double() * line_height),
  ).accessibility_label("Multiline text area")
}
