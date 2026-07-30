///|
/// Smoke tests for feedback widgets.
///|
test "badge smoke" {
  let view : @core.View[Unit] = @views.badge("New")
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "status_badge smoke" {
  let view : @core.View[Unit] = @views.status_badge("Active", tone=@views.BadgeTone::Success)
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "banner smoke" {
  let view : @core.View[Unit] = @views.banner("Notice", "Something happened")
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "callout smoke" {
  let view : @core.View[Unit] = @views.callout("Tip", "Useful information")
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "empty_state smoke" {
  let view : @core.View[Unit] = @views.empty_state("No items", "Add some items to get started")
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "loading_state smoke" {
  let view : @core.View[Unit] = @views.loading_state(message="Loading...")
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "error_state smoke" {
  let view : @core.View[Unit] = @views.error_state("Error", "Something went wrong")
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "snackbar smoke" {
  let view : @core.View[Unit] = @views.snackbar("Item saved")
  @common.assert_layouts(view)
  @common.assert_paints(view)
}
