///|
test "engine reconciles keyed children by identity" {
  let old = mount_view_spec(
    ViewSpec::FlexSpec({
      key: None,
      axis: Axis::Vertical,
      spacing: 0.0,
      main_axis_alignment: MainStart,
      cross_axis_alignment: CrossStretch,
      children: [test_label("A", key="a"), test_label("B", key="b")],
    }),
  )
  let old_a = old.children[0].id
  let old_b = old.children[1].id
  let next = reconcile_element(
    old,
    ViewSpec::FlexSpec({
      key: None,
      axis: Axis::Vertical,
      spacing: 0.0,
      main_axis_alignment: MainStart,
      cross_axis_alignment: CrossStretch,
      children: [test_label("B", key="b"), test_label("A", key="a")],
    }),
  )
  assert_true(next.children[0].id == old_b)
  assert_true(next.children[1].id == old_a)
}
