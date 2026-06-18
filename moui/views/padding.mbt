///|
pub fn[Msg] padding(child : @core.View[Msg], value : Double) -> @core.View[Msg] {
  padding_layout(child~, insets=@core.Insets::all(value))
}

///|
pub fn[Msg] padding_xy(
  child : @core.View[Msg],
  horizontal? : Double = 0.0,
  vertical? : Double = 0.0,
) -> @core.View[Msg] {
  padding_layout(child~, insets=@core.Insets::symmetric(horizontal~, vertical~))
}

///|
pub fn[Msg] padding_edges(
  child : @core.View[Msg],
  top? : Double = 0.0,
  right? : Double = 0.0,
  bottom? : Double = 0.0,
  left? : Double = 0.0,
) -> @core.View[Msg] {
  padding_layout(child~, insets={ top, right, bottom, left })
}

///|
pub fn[Msg] padding_insets(
  child : @core.View[Msg],
  insets : @core.Insets,
) -> @core.View[Msg] {
  padding_layout(child~, insets~)
}
