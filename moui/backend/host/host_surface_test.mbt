///|
test "host surface metrics tracks logical physical and dpr" {
  let metrics = HostSurfaceMetrics::from_logical(
    size=@core.Size::new(width=120.0, height=80.0),
    scale_factor=2.0,
  )
  assert_true(metrics.logical_size == @core.Size::new(width=120.0, height=80.0))
  assert_true(
    metrics.physical_size == @core.Size::new(width=240.0, height=160.0),
  )
  inspect(metrics.scale_factor, content="2")
}
