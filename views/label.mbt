///|
pub fn label(text : String, width? : Double = 160.0, height? : Double = 32.0) -> @core.ViewNode {
  @core.ViewNode::Label({ text, size: @core.Size::new(width~, height~), color: @core.Color::gray() })
}
