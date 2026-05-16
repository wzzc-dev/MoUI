///|
test "macos startup surface size preserves runtime logical dimensions" {
  let size = runtime_size_to_window_surface_size(
    @core.Size::new(width=800.0, height=600.0),
  )
  assert_eq(size.to_logical(2.0), @dpi.LogicalSize::new(800.0, 600.0))
  assert_eq(size.to_physical(2.0), @dpi.PhysicalSize::new(1600, 1200))
}
