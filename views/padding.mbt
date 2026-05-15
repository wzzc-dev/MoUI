///|
pub fn padding(child : @core.ViewSpec, value : Double) -> @core.ViewSpec {
  @core.ViewSpec::PaddingSpec({
    key: None,
    insets: @core.Insets::all(value),
    child,
  })
}

///|
pub fn padding_insets(
  child : @core.ViewSpec,
  insets : @core.Insets,
) -> @core.ViewSpec {
  @core.ViewSpec::PaddingSpec({ key: None, insets, child })
}
