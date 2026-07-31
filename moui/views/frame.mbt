///|
pub fn[Msg] frame(
  child : @core.View[Msg],
  width? : Double,
  height? : Double,
  min_width? : Double,
  min_height? : Double,
  max_width? : Double,
  max_height? : Double,
) -> @core.View[Msg] {
  @layout.frame_layout(
    child~,
    width~,
    height~,
    min_width~,
    min_height~,
    max_width~,
    max_height~,
  )
}
