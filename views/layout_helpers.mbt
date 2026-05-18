///|
pub fn expanded(
  child : @core.ViewSpec,
  weight? : Double = 1.0,
) -> @core.ViewSpec {
  child.expanded(weight~)
}

///|
pub fn flexible(
  child : @core.ViewSpec,
  weight? : Double = 1.0,
) -> @core.ViewSpec {
  child.flexible(weight~)
}

///|
pub fn align(
  child : @core.ViewSpec,
  alignment? : @core.Alignment = @core.Alignment::center(),
) -> @core.ViewSpec {
  child.align(alignment~)
}

///|
pub fn aspect_ratio(child : @core.ViewSpec, ratio : Double) -> @core.ViewSpec {
  child.aspect_ratio(ratio)
}

///|
pub fn intrinsic_width(child : @core.ViewSpec) -> @core.ViewSpec {
  child.intrinsic_width()
}

///|
pub fn intrinsic_height(child : @core.ViewSpec) -> @core.ViewSpec {
  child.intrinsic_height()
}

///|
pub fn custom_layout(
  measure~ : (@core.Constraints) -> @core.Size,
  paint~ : (@core.Rect) -> Array[@core.DrawCommand],
  semantics_role? : @core.SemanticsRole = @core.SemanticsRole::Group,
  semantics_label? : String = "",
) -> @core.ViewSpec {
  @core.ViewSpec::custom(measure~, paint~, semantics_role~, semantics_label~)
}
