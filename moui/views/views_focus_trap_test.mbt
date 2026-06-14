///|
test "focus trap modifier constrains public view focus traversal" {
  let outside = @core.State::new("")
  let first = @core.State::new("")
  let second = @core.State::new("")
  let after = @core.State::new("")
  let runtime = test_runtime(
    @views.column(
      [
        @views.text_field_binding(outside.binding(), width=120.0),
        @views.column(
          [
            @views.text_field_binding(first.binding(), width=120.0),
            @views.text_field_binding(second.binding(), width=120.0),
          ],
          spacing=8.0,
        ).focus_trap(),
        @views.text_field_binding(after.binding(), width=120.0),
      ],
      spacing=8.0,
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Tab")),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("a")),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Tab")),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("b")),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Tab")),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("c")),
  )
  inspect(outside.get(), content="")
  inspect(first.get(), content="ac")
  inspect(second.get(), content="b")
  inspect(after.get(), content="")
}

///|
test "dialog sheet and popover can trap presentation focus" {
  let outside = @core.State::new("")
  let dialog_value = @core.State::new("")
  let sheet_value = @core.State::new("")
  let popover_value = @core.State::new("")
  let dialog_runtime = test_runtime(
    @views.dialog_host(
      @views.text_field_binding(outside.binding(), width=120.0),
      dialog=Some(
        @views.text_field_binding(dialog_value.binding(), width=120.0),
      ),
      presented=true,
    ),
  )
  dialog_runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Tab")),
  )
  dialog_runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("d")),
  )
  let sheet_runtime = test_runtime(
    @views.sheet_host(
      child=@views.text_field_binding(outside.binding(), width=120.0),
      sheet=Some(@views.text_field_binding(sheet_value.binding(), width=120.0)),
      presented=true,
    ),
  )
  sheet_runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Tab")),
  )
  sheet_runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("s")),
  )
  let popover_runtime = test_runtime(
    @views.column([
      @views.text_field_binding(outside.binding(), width=120.0),
      @views.popover(
        anchor=@views.button("Open", on_click=()),
        content=@views.text_field_binding(popover_value.binding(), width=120.0),
        expanded=true,
        trap_focus=true,
      ),
    ]),
  )
  popover_runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Tab")),
  )
  popover_runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("p")),
  )
  inspect(outside.get(), content="")
  inspect(dialog_value.get(), content="d")
  inspect(sheet_value.get(), content="s")
  inspect(popover_value.get(), content="p")
}

///|
test "sheet host centers bottom sheet presentation" {
  let runtime = test_runtime(
    @views.sheet_host(
      child=@views.text("Host", width=640.0, height=480.0),
      sheet=Some(
        @views.sheet(
          content=@views.text("Sheet body", width=200.0, height=24.0),
          presentation_mode=@core.SheetPresentationMode::BottomSheet,
        ),
      ),
      presented=true,
      presentation_mode=@core.SheetPresentationMode::BottomSheet,
      trap_focus=false,
    ),
  )
  let commands = runtime.draw_commands()
  guard text_frame(commands, "Sheet body") is Some(body_frame) else {
    fail("expected sheet body frame")
  }
  guard smallest_rounded_brush_containing(commands, body_frame)
    is Some(sheet_frame) else {
    fail("expected sheet surface frame")
  }
  let center_x = sheet_frame.origin.x + sheet_frame.size.width / 2.0
  assert_true((center_x - 320.0).abs() <= 1.0)
  assert_true(sheet_frame.origin.y + sheet_frame.size.height <= 480.0)
}
