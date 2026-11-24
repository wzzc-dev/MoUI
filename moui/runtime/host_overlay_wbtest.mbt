///|
fn click_at(runtime : AppRuntime, x : Double, y : Double) -> Unit {
  let point = @core.Point::new(x~, y~)
  ignore(
    runtime.dispatch_event(
      Pointer(
        @core.PointerEvent::new(position=point, phase=@core.PointerPhase::Down),
      ),
    ),
  )
  ignore(
    runtime.dispatch_event(
      Pointer(
        @core.PointerEvent::new(position=point, phase=@core.PointerPhase::Up),
      ),
    ),
  )
}

///|
fn host_overlay_record(received : Array[String]) -> (String) -> Unit {
  message => ignore(received.push(message))
}

///|
test "host overlay mounts above the app root and hit-tests first" {
  let received : Array[String] = []
  let root : @core.View[String] = @views.column(
    [
      @views.button("app", on_click="app-click", width=160.0, height=40.0),
      @views.spacer(min_length=80.0),
    ],
    spacing=0.0,
  )
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=200.0, height=120.0),
    on_message=Some(host_overlay_record(received)),
  )
  ignore(runtime.draw_frame())
  click_at(runtime, 20.0, 20.0)
  assert_eq(received, ["app-click"])
  // Mount the host layer: same surface rect, its button sits on the app's.
  let overlay = HostOverlay::from_view(
    @views.frame(
      @views.button(
        "overlay",
        on_click="overlay-click",
        width=160.0,
        height=40.0,
      ),
      width=200.0,
      height=120.0,
    ),
    emit=host_overlay_record(received),
  )
  runtime.set_host_overlay(Some(overlay))
  ignore(runtime.draw_frame())
  click_at(runtime, 20.0, 20.0)
  // Last child paints on top and wins the hit test: the app's button never
  // sees this click.
  assert_eq(received, ["app-click", "overlay-click"])
  // Clearing the layer restores the app subtree, which kept its identity.
  runtime.set_host_overlay(None)
  ignore(runtime.draw_frame())
  click_at(runtime, 20.0, 20.0)
  assert_eq(received, ["app-click", "overlay-click", "app-click"])
}

///|
test "host overlay mount keeps app control state (no remount)" {
  let mut value = "hello world"
  let root : @core.View[String] = @views.text_field(
    value,
    on_input=input => {
      value = input
      "input"
    },
    width=180.0,
    height=36.0,
  )
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=200.0, height=60.0),
  )
  ignore(runtime.draw_frame())
  click_at(runtime, 20.0, 20.0)
  if !runtime.focused_text_input().focused {
    fail("expected text field focus")
  }
  if !runtime.place_focused_text_caret(5) {
    fail("expected caret placement to be handled")
  }
  assert_eq(runtime.focused_text_input().caret, 5)
  // A rebuild caused by the host layer must not remount the app subtree:
  // control state (caret, focus) survives.
  let no_op : (String) -> Unit = _message => ()
  let overlay = HostOverlay::from_view(
    @views.frame(@views.spacer(), width=200.0, height=60.0),
    emit=no_op,
  )
  runtime.set_host_overlay(Some(overlay))
  ignore(runtime.draw_frame())
  assert_eq(runtime.focused_text_input().caret, 5)
  runtime.set_host_overlay(None)
  ignore(runtime.draw_frame())
  assert_eq(runtime.focused_text_input().caret, 5)
  assert_true(runtime.focused_text_input().focused)
}

///|
test "host overlay survives program rebuilds" {
  let received : Array[String] = []
  let runtime = AppRuntime::new_view(
    root=@views.button("app", on_click="app-click", width=120.0, height=40.0),
    size=@core.Size::new(width=200.0, height=120.0),
    on_message=Some(host_overlay_record(received)),
  )
  let overlay = HostOverlay::from_view(
    @views.frame(
      @views.button(
        "overlay",
        on_click="overlay-click",
        width=120.0,
        height=40.0,
      ),
      width=200.0,
      height=120.0,
    ),
    emit=host_overlay_record(received),
  )
  runtime.set_host_overlay(Some(overlay))
  ignore(runtime.draw_frame())
  // A plain rebuild of the runtime root (no overlay change) keeps the layer
  // mounted: the slot is shared with every root adapter the builder produces.
  ignore(
    runtime.set_environment(
      runtime.environment().with_system_scheme(@core.ColorScheme::Dark),
    ),
  )
  ignore(runtime.draw_frame())
  click_at(runtime, 20.0, 20.0)
  assert_eq(received, ["overlay-click"])
}

///|
/// The layer the Linux fallback menu installs, reduced to what focus cares
/// about: a context-menu region carrying one row, anchored inside the surface.
fn host_overlay_menu_layer(keeps_focus : Bool) -> HostOverlay {
  let menu : @core.View[String] = @views.command_menu(
    [
      @views.command_menu_section(title="", commands=[
        @core.ActionCommand::new(intent=@core.Activate, label="Copy"),
      ]),
    ],
    on_select=_intent => "menu-select",
  )
  let region : @core.View[String] = @views.context_menu_region(
    child=@views.empty(),
    menu~,
    visible=true,
    anchor=Some(@core.Point::new(x=8.0, y=8.0)),
    dismiss=Some("menu-dismiss"),
  )
  HostOverlay::from_view(region, emit=_message => (), keeps_focus~)
}

///|
/// Center of the semantics node labelled `label`, the point a pointer press
/// has to land on to hit that row.
fn host_overlay_row_center(
  runtime : AppRuntime,
  label : String,
) -> @core.Point? {
  match runtime.read_semantics() {
    Ok(Full(snapshot)) => {
      for node in snapshot.nodes() {
        if node.label == label {
          return Some(
            @core.Point::new(
              x=node.frame.origin.x + node.frame.size.width / 2.0,
              y=node.frame.origin.y + node.frame.size.height / 2.0,
            ),
          )
        }
      }
      None
    }
    _ => None
  }
}

///|
/// A runtime whose text field holds focus, ready for a press on a mounted host
/// layer.
fn host_overlay_focused_runtime() -> (AppRuntime, Ref[String]) {
  let value : Ref[String] = Ref("hello world")
  let root : @core.View[String] = @views.column(
    [
      @views.text_field(
        value.val,
        on_input=input => {
          value.val = input
          "input"
        },
        width=180.0,
        height=36.0,
      ),
      @views.spacer(min_length=80.0),
    ],
    spacing=0.0,
  )
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=420.0, height=320.0),
  )
  ignore(runtime.draw_frame())
  click_at(runtime, 20.0, 20.0)
  (runtime, value)
}

///|
test "a non-activating host layer leaves the app's focus owner on press" {
  let (runtime, _) = host_overlay_focused_runtime()
  if !runtime.focused_text_input().focused {
    fail("expected text field focus")
  }
  // A native-style context menu: the press lands on a hoisted popup owned by
  // the host layer, so focus pickup belongs to the layer. The layer declares
  // itself non-activating, so the app's focus owner must survive the press —
  // the command it runs acts on that focus.
  runtime.set_host_overlay(Some(host_overlay_menu_layer(true)))
  ignore(runtime.draw_frame())
  let center = match host_overlay_row_center(runtime, "Copy") {
    Some(point) => point
    None => fail("expected the menu row to be laid out")
  }
  click_at(runtime, center.x, center.y)
  assert_true(runtime.focused_text_input().focused)
  assert_eq(runtime.focused_text_input().text, "hello world")
}

///|
test "a plain host layer still gives up focus to its popup" {
  let (runtime, _) = host_overlay_focused_runtime()
  if !runtime.focused_text_input().focused {
    fail("expected text field focus")
  }
  // The flag is what decides: the same layer without it behaves like any other
  // content — the press lands inside the layer's popup, and the covered text
  // field must not keep a caret it can no longer show.
  runtime.set_host_overlay(Some(host_overlay_menu_layer(false)))
  ignore(runtime.draw_frame())
  let center = match host_overlay_row_center(runtime, "Copy") {
    Some(point) => point
    None => fail("expected the menu row to be laid out")
  }
  click_at(runtime, center.x, center.y)
  assert_true(!runtime.focused_text_input().focused)
}
