///|
fn window_test_runtime(
  root~ : @core.View[Unit],
  size~ : @core.Size,
) -> @runtime.AppRuntime {
  @runtime.AppRuntime::new_view(root~, size~)
}
