///|
fn test_runtime(root : @core.View[Unit]) -> @runtime.AppRuntime {
  @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=640.0, height=480.0),
  )
}

///|
test "controls and modifiers expose semantics" {
  let runtime = test_runtime(
    @views.column([
      @views.toggle_switch("Enabled", true, on_change=_value => ()),
      @views.progress(0.6, width=120.0),
      @views.text("Tip").semantics_role(@core.SemanticsRole::Tooltip),
    ]),
  )
  let semantics = runtime.semantics()
  inspect(semantics.children.length() > 0, content="true")
}
