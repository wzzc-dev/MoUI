///|
pub fn button(
  text : String,
  width? : Double = 180.0,
  height? : Double = 44.0,
) -> @core.ViewSpec {
  button_base(text, None, width~, height~)
}

///|
pub fn button_on_click(
  text : String,
  on_click : @core.ClickHandler,
  width? : Double = 180.0,
  height? : Double = 44.0,
) -> @core.ViewSpec {
  button_base(text, Some(on_click), width~, height~)
}

///|
fn button_base(
  text : String,
  on_click : @core.ClickHandler?,
  width~ : Double,
  height~ : Double,
) -> @core.ViewSpec {
  @core.ViewSpec::ButtonSpec({
    key: None,
    text,
    size: @core.Size::new(width~, height~),
    font: @core.FontSpec::new(size=16.0, weight=600),
    foreground: @core.Color::black(),
    background: @core.Color::gray(),
    hovered_background: @core.Color::rgba(r=0.72, g=0.78, b=0.92),
    pressed_background: @core.Color::blue(),
    corner_radius: 0.0,
    on_click,
  })
}
