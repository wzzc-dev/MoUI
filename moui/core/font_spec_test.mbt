///|
test "font spec feature helpers replace by tag" {
  let font = @core.FontSpec::new(size=14.0)
    .with_feature(tag="tnum")
    .with_feature(tag="liga", value=0)
    .with_feature(tag="tnum", value=0)
  assert_eq(font.features.length(), 2)
  let mut tabular = 0
  let mut ligatures = 1
  for feature in font.features {
    if feature.tag == "tnum" {
      tabular = feature.value
    } else if feature.tag == "liga" {
      ligatures = feature.value
    }
  }
  assert_eq(tabular, 0)
  assert_eq(ligatures, 0)
}

///|
test "font spec spacing defaults are absent" {
  let font = @core.FontSpec::new(size=14.0)
  assert_true(font.line_height is None)
  assert_true(font.letter_spacing is None)
  assert_eq(font.features.length(), 0)
  let tightened = font.with_letter_spacing(Some(-0.2))
  assert_eq(tightened.letter_spacing, Some(-0.2))
}
