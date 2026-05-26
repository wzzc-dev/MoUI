///|
pub fn padding(child : @core.ViewSpec, value : Double) -> @core.ViewSpec {
  @core.ViewSpec::PaddingSpec({
    key: None,
    insets: @core.Insets::all(value),
    child,
  })
}

///|
pub fn padding_xy(
  child : @core.ViewSpec,
  horizontal? : Double = 0.0,
  vertical? : Double = 0.0,
) -> @core.ViewSpec {
  @core.ViewSpec::PaddingSpec({
    key: None,
    insets: @core.Insets::symmetric(horizontal~, vertical~),
    child,
  })
}

///|
pub fn padding_edges(
  child : @core.ViewSpec,
  top? : Double = 0.0,
  right? : Double = 0.0,
  bottom? : Double = 0.0,
  left? : Double = 0.0,
) -> @core.ViewSpec {
  @core.ViewSpec::PaddingSpec({
    key: None,
    insets: { top, right, bottom, left },
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
