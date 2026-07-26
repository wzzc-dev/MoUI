///|
fn[Msg] adapt_view_for_runtime(
  view : @core.View[Msg],
  emit : (Msg) -> Unit,
) -> &RuntimeViewNode {
  runtime_view_node(view, emit)
}
