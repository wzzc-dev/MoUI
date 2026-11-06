///|
fn window_test_runtime(
  root~ : @core.View[Unit],
  size~ : @core.Size,
) -> @apphost.AppRuntime {
  @apphost.AppRuntime::new_view(root~, size~)
}
