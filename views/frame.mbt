///|
pub fn frame(
  child : @core.ViewSpec,
  width? : Double,
  height? : Double,
  min_width? : Double,
  min_height? : Double,
  max_width? : Double,
  max_height? : Double,
) -> @core.ViewSpec {
  @core.ViewSpec::FrameSpec({
    key: None,
    width,
    height,
    min_width,
    min_height,
    max_width,
    max_height,
    child,
  })
}
