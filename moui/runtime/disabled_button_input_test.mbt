///|
enum DisabledButtonMsg {
  AddDisabledTest
  ToggleDisabledTestEnabled
}

///|
struct DisabledButtonModel {
  enabled : Bool
}

///|
test "disabled button ignores pointer and keyboard activation" {
  let received : Array[String] = []
  let runtime = @runtime.AppRuntime::new_program(
    program=@core.Program::simple(
      init=({ enabled: false, } : DisabledButtonModel),
      update=(model, message) => {
        match message {
          AddDisabledTest => {
            received.push("add")
            model
          }
          ToggleDisabledTestEnabled => {
            received.push("toggle")
            { enabled: !model.enabled, }
          }
        }
      },
      view=model => {
        @views.column(
          [
            @views.button("Add", on_click=AddDisabledTest)
            .disabled(disabled=!model.enabled)
            .key("add")
            .frame(width=100.0, height=40.0),
            @views.button("Toggle", on_click=ToggleDisabledTestEnabled)
            .key("toggle")
            .frame(width=100.0, height=40.0),
          ],
          spacing=0.0,
        )
      },
    ),
    size=@core.Size::new(width=200.0, height=100.0),
  )
  ignore(runtime.draw_frame())
  let click = (x, y) => {
    runtime.dispatch_event(
      Pointer(
        @core.PointerEvent::new(position=@core.Point::new(x~, y~), phase=Down),
      ),
    )
    runtime.dispatch_event(
      Pointer(
        @core.PointerEvent::new(position=@core.Point::new(x~, y~), phase=Up),
      ),
    )
  }
  click(10.0, 10.0)
  if !received.is_empty() {
    fail("disabled button must not dispatch a pointer click")
  }
  if runtime.focus_key("add") {
    fail("disabled button must not be focusable")
  }
  // Enable it through the sibling, then the same click must work.
  click(10.0, 50.0)
  ignore(runtime.draw_frame())
  click(10.0, 10.0)
  if received != ["toggle", "add"] {
    fail("enabled button should dispatch its click after re-enable")
  }
  if !runtime.focus_key("add") {
    fail("enabled button should be focusable")
  }
  // Toggling an enabled control back to disabled must make it inert again.
  click(10.0, 50.0)
  ignore(runtime.draw_frame())
  click(10.0, 10.0)
  if received != ["toggle", "add", "toggle"] {
    fail("re-disabled button must stop dispatching clicks")
  }
  if runtime.focus_key("add") {
    fail("re-disabled button must not be focusable")
  }
}
