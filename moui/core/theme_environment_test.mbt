///|
test "environment fingerprint tracks locale and layout direction" {
  let base = Environment::neutral()
  let chinese = base.with_locale("zh-Hans")
  let right_to_left = base.with_layout_direction(LayoutDirection::RightToLeft)
  assert_true(base.revision_fingerprint() != chinese.revision_fingerprint())
  assert_true(
    base.revision_fingerprint() != right_to_left.revision_fingerprint(),
  )
}
