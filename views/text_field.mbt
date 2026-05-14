///|
pub fn text_field(
  value : @core.Binding[String],
  placeholder? : String = "",
  width? : Double = 240.0,
  height? : Double = 40.0,
) -> @core.ViewNode {
  text_field_base(value, placeholder~, width~, height~, None)
}

///|
pub fn text_field_on_submit(
  value : @core.Binding[String],
  on_submit : () -> Unit,
  placeholder? : String = "",
  width? : Double = 240.0,
  height? : Double = 40.0,
) -> @core.ViewNode {
  text_field_base(value, placeholder~, width~, height~, Some(on_submit))
}

///|
fn text_field_base(
  value : @core.Binding[String],
  placeholder~ : String,
  width~ : Double,
  height~ : Double,
  on_submit : (() -> Unit)?,
) -> @core.ViewNode {
  @core.ViewNode::TextField({
    value,
    placeholder,
    size: @core.Size::new(width~, height~),
    on_submit,
  })
}
