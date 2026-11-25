///|
test "host driver hooks override semantics, text input and frame fields" {
  let root : @core.View[Unit] = @views.empty()
  let runtime : @runtime.AppRuntime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=120.0, height=80.0),
    on_message=Option::None,
  )
  let semantics_reads : Ref[Int32] = Ref(0)
  let actions : Ref[Int32] = Ref(0)
  let hook_input : @core.TextInputState = {
    focused: true,
    text: "hook",
    caret: 4,
    selection: None,
    composition: None,
    composition_cursor: None,
    frame: @core.Rect::new(x=1.0, y=2.0, width=30.0, height=10.0),
    caret_rect: @core.Rect::new(x=31.0, y=2.0, width=1.0, height=10.0),
  }
  let hooks = @apphost.HostDriverHooks::new(
    read_semantics=Some(_since => {
      semantics_reads.val = semantics_reads.val + 1
      Err(@runtime.SemanticsReadError::RuntimeClosed)
    }),
    perform_semantics_action=Some(request => {
      actions.val = actions.val + 1
      Err(@runtime.SemanticsActionDispatchError::TargetNotFound(request.target))
    }),
    focused_text_input=Some(() => hook_input),
    augment_frame=Some(frame => {
      ..frame,
      clear_color: @core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.25),
    }),
  )
  let driver = @apphost.HostRuntimeDriver::new(
    runtime~,
    schedule_redraw=() => (),
    hooks=Some(hooks),
  )
  assert_true(
    driver.read_semantics() is Err(@runtime.SemanticsReadError::RuntimeClosed),
  )
  assert_eq(semantics_reads.val, 1)
  let input = driver.focused_text_input()
  assert_eq(input.text, "hook")
  assert_eq(input.caret, 4)
  let request : @runtime.PerformSemanticsActionRequest = {
    target: @core.SemanticsTarget::ByNodeId(@core.SemanticsNodeId::new(1UL)),
    action: @core.SemanticsAction::Activate,
    precondition: @runtime.SemanticsGenerationPrecondition::Latest,
  }
  match driver.perform_semantics_action(request) {
    Err(@runtime.SemanticsActionDispatchError::TargetNotFound(target)) =>
      assert_eq(
        target,
        @core.SemanticsTarget::ByNodeId(@core.SemanticsNodeId::new(1UL)),
      )
    _ => fail("expected the hook's dispatch error")
  }
  assert_eq(actions.val, 1)
  let frame = driver.draw_frame()
  assert_eq(frame.clear_color.a, 0.25)
}
