///|
/// Smoke tests for disclosure, accordion, collapsible_panel.

///|
test "disclosure smoke" {
  let view : @core.View[Unit] = @views.disclosure(
    "Details",
    content=@views.text("body"),
    expanded=true,
    on_toggle=(),
  )
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "collapsible_panel smoke" {
  let view : @core.View[Unit] = @views.collapsible_panel(
    "Header",
    content=@views.text("Body"),
    expanded=true,
    on_toggle=(),
  )
  @common.assert_layouts(view)
  @common.assert_paints(view)
}

///|
test "wizard_step accordion item smoke" {
  let step = @views.WizardStep::new(
    id="1",
    title="Step 1",
    content=@views.text("content"),
  )
  let view : @core.View[Unit] = @views.accordion([step], expanded=[], on_toggle=fn(
    _s,
  ) {
    ()
  })
  @common.assert_layouts(view)
  @common.assert_paints(view)
}
