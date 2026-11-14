///|
test "font declaration key distinguishes spacing and features" {
  let base = @core.FontSpec::new(size=14.0)
  let spaced = base.with_letter_spacing(Some(-0.2))
  let featured = base.with_feature(tag="tnum")
  let base_key = view_font_key(base)
  assert_true(base_key != view_font_key(spaced))
  assert_true(base_key != view_font_key(featured))
  assert_true(view_font_key(spaced) != view_font_key(featured))
  // Same feature set keys the same regardless of insertion order.
  let reordered = base
    .with_feature(tag="liga", value=0)
    .with_feature(tag="tnum")
  let ordered = base.with_feature(tag="tnum").with_feature(tag="liga", value=0)
  assert_true(view_font_key(reordered) == view_font_key(ordered))
  // Changing a feature value changes the key.
  assert_true(
    view_font_key(base.with_feature(tag="tnum", value=0)) !=
    view_font_key(featured),
  )
}
