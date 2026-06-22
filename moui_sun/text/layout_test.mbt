///|
test "LayoutMetrics" {
  let metrics = LayoutMetrics::new(width=100.0, height=50.0, baseline=16.0)
  assert_eq(metrics.width, 100.0)
  assert_eq(metrics.height, 50.0)
  assert_eq(metrics.baseline, 16.0)
}
