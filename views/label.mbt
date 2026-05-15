///|
pub fn label(
  text : String,
  width? : Double = 160.0,
  height? : Double = 32.0,
) -> @core.ViewSpec {
  @core.ViewSpec::TextSpec({
    key: None,
    text,
    size: @core.Size::new(width~, height~),
    font: @core.FontSpec::new(size=16.0, weight=500),
    color: @core.Color::black(),
  })
}
