///|
test "overlay host modal barrier blocks base and dismisses outside" {
  let received : Array[String] = []
  let base = @views.button("Base", on_click="base")
  let root = @views.overlay_host(base, [
    @views.PresentationSpec::new(
      id="dialog",
      kind=@views.PresentationKind::Dialog,
      content=@views.text("Dialog", width=40.0, height=20.0),
      modality=@views.PresentationModality::Modal,
      dismiss=@views.PresentationDismissPolicy::new(
        outside_tap=true,
        message=Some("dismiss"),
      ),
    ),
  ])
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=200.0, height=100.0),
    on_message=Some(message => received.push(message)),
  )
  ignore(runtime.layout())
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(
        position=@core.Point::new(x=2.0, y=2.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  assert_true(received == ["dismiss"])
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(
        position=@core.Point::new(x=2.0, y=2.0),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  assert_true(!received.contains("base"))
}

///|
test "overlay host escape dismisses the top-most presentation" {
  let received : Array[String] = []
  let root = @views.overlay_host(@views.text("Base"), [
    @views.PresentationSpec::new(
      id="first",
      kind=@views.PresentationKind::Dialog,
      content=@views.text("First"),
      dismiss=@views.PresentationDismissPolicy::new(message=Some("first")),
    ),
    @views.PresentationSpec::new(
      id="second",
      kind=@views.PresentationKind::Dialog,
      content=@views.text("Second"),
      dismiss=@views.PresentationDismissPolicy::new(message=Some("second")),
    ),
  ])
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=200.0, height=100.0),
    on_message=Some(message => received.push(message)),
  )
  ignore(runtime.layout())
  assert_true(runtime.dispatch_presentation_escape())
  assert_true(received == ["second"])
}

///|
test "overlay host back and host close use independent policies" {
  let received : Array[String] = []
  let root = @views.overlay_host(@views.text("Base"), [
    @views.PresentationSpec::new(
      id="back",
      kind=@views.PresentationKind::Sheet,
      content=@views.text("Back"),
      dismiss=@views.PresentationDismissPolicy::new(
        escape=false,
        system_back=true,
        host_close=false,
        message=Some("back"),
      ),
    ),
  ])
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=120.0, height=80.0),
    on_message=Some(message => received.push(message)),
  )
  ignore(runtime.layout())
  assert_true(!runtime.dispatch_presentation_escape())
  assert_true(received.is_empty())
  assert_true(runtime.dispatch_presentation_back())
  assert_true(received == ["back"])
}

///|
test "overlay host resolves stable anchors after base layout" {
  let anchor : @core.View[Unit] = @views.frame(
    @views.text("Anchor"),
    width=32.0,
    height=18.0,
  ).key("menu-anchor")
  let base = @views.padding_edges(anchor, top=12.0, left=24.0)
  let root = @views.overlay_host(base, [
    @views.PresentationSpec::new(
      id="menu",
      kind=@views.PresentationKind::Popover,
      anchor=@views.PresentationAnchor::stable_key("menu-anchor"),
      placement=Some(
        @views.PresentationPlacement::new(
          candidates=[@views.PresentationPlacementCandidate::BelowStart],
          viewport_insets=@core.Insets::all(4.0),
        ),
      ),
      content=@views.frame(@views.text("Menu"), width=40.0, height=20.0),
    ),
  ])
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=200.0, height=100.0),
  )
  let layout = runtime.layout()
  let anchor_frame = match runtime.anchor_frame("menu-anchor") {
    Some(frame) => frame
    None => fail("missing anchor")
  }
  assert_true(anchor_frame.origin.x == 24.0)
  assert_true(anchor_frame.origin.y == 12.0)
  assert_true(layout.children.length() == 2)
  let presentation_frame = layout.children[1].frame
  assert_true(presentation_frame.origin.x == anchor_frame.origin.x)
  assert_true(presentation_frame.origin.y >= anchor_frame.max_y())
}

///|
test "overlay host placement settles in a single layout pass" {
  let anchor : @core.View[Unit] = @views.frame(
    @views.text("Anchor"),
    width=32.0,
    height=18.0,
  ).key("menu-anchor")
  let base = @views.padding_edges(anchor, top=12.0, left=24.0)
  let root = @views.overlay_host(base, [
    @views.PresentationSpec::new(
      id="menu",
      kind=@views.PresentationKind::Popover,
      anchor=@views.PresentationAnchor::stable_key("menu-anchor"),
      content=@views.frame(@views.text("Menu"), width=40.0, height=20.0),
    ),
  ])
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=200.0, height=100.0),
  )
  // First frame: the presentation is already at its resolved position. The
  // former anchor-in-layout design fell back to the viewport center and only
  // converged on a second full-tree pass.
  let layout = runtime.layout()
  assert_true(layout.children.length() == 2)
  let presentation_frame = layout.children[1].frame
  assert_true(presentation_frame.origin.x == 24.0)
  assert_true(presentation_frame.origin.y >= 30.0)
  assert_true(runtime.inspector_snapshot().runtime().layout_pass_count() == 1)
  // An undispatched frame performs no extra layout work.
  ignore(runtime.layout())
  assert_true(runtime.inspector_snapshot().runtime().layout_pass_count() == 1)
}

///|
test "anchored relayout adds exactly one layout pass" {
  let anchor : @core.View[Unit] = @views.frame(
    @views.text("Anchor"),
    width=32.0,
    height=18.0,
  ).key("menu-anchor")
  let base = @views.padding_edges(anchor, top=12.0, left=24.0)
  let root = @views.overlay_host(base, [
    @views.PresentationSpec::new(
      id="menu",
      kind=@views.PresentationKind::Popover,
      anchor=@views.PresentationAnchor::stable_key("menu-anchor"),
      content=@views.frame(@views.text("Menu"), width=40.0, height=20.0),
    ),
  ])
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=200.0, height=100.0),
  )
  ignore(runtime.layout())
  let passes_before = runtime.inspector_snapshot().runtime().layout_pass_count()
  // A relayout request with an open presentation must not re-enter layout for
  // anchor resolution: exactly one pass, and the placement stays resolved.
  runtime.set_text_system(@core.TextSystem::fallback())
  let layout = runtime.layout()
  let passes_after = runtime.inspector_snapshot().runtime().layout_pass_count()
  assert_true(passes_after == passes_before + 1)
  assert_true(layout.children[1].frame.origin.x == 24.0)
  assert_true(layout.children[1].frame.origin.y >= 30.0)
}

///|
test "popup host sizes to base and places popup below it" {
  let root = @views.popup_host(
    @views.frame(
      @views.button("Open", on_click="open"),
      width=80.0,
      height=32.0,
    ),
    [
      @views.PresentationSpec::new(
        id="menu",
        kind=@views.PresentationKind::Popover,
        anchor=@views.PresentationAnchor::HostBase,
        placement=Some(
          @views.PresentationPlacement::new(
            viewport_insets=@core.Insets::all(0.0),
          ),
        ),
        content=@views.frame(@views.text("Item"), width=60.0, height=24.0),
      ),
    ],
  )
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=200.0, height=100.0),
  )
  let layout = runtime.layout()
  // The base child keeps its own size and the popup anchors to it, even
  // though a parent-assigned frame may be larger than the control.
  assert_true(layout.children.length() == 2)
  let base_frame = layout.children[0].frame
  assert_true(base_frame.size.width == 80.0)
  assert_true(base_frame.size.height == 32.0)
  // The popup is placed below the base child's frame (BelowStart default).
  let popup_frame = layout.children[1].frame
  assert_true(popup_frame.origin.x == 0.0)
  assert_true(popup_frame.origin.y == 32.0)
  assert_true(runtime.inspector_snapshot().runtime().layout_pass_count() == 1)
}

///|
test "nested overlay hosts dismiss top-most first" {
  // A dialog (outer host) whose content contains a popover (inner host):
  // Escape must reach the inner popover before the dialog, matching visual
  // top-most order.
  let received : Array[String] = []
  let inner_popover : @core.View[String] = @views.popup_host(
    @views.frame(@views.text("Anchor"), width=40.0, height=12.0),
    [
      @views.PresentationSpec::new(
        id="inner",
        kind=@views.PresentationKind::Popover,
        anchor=@views.PresentationAnchor::HostBase,
        content=@views.frame(@views.text("Inner"), width=40.0, height=20.0),
        dismiss=@views.PresentationDismissPolicy::new(
          message=Some("close-inner"),
        ),
      ),
    ],
  )
  let root = @views.overlay_host(@views.text("Base"), [
    @views.PresentationSpec::new(
      id="dialog",
      kind=@views.PresentationKind::Dialog,
      content=@views.frame(inner_popover, width=100.0, height=40.0),
      modality=@views.PresentationModality::Modal,
      dismiss=@views.PresentationDismissPolicy::new(
        message=Some("close-dialog"),
      ),
    ),
  ])
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=200.0, height=100.0),
    on_message=Some(message => received.push(message)),
  )
  ignore(runtime.layout())
  ignore(runtime.dispatch_presentation_escape())
  if received != ["close-inner"] {
    fail("expected the inner popover to dismiss before the dialog")
  }
}

///|
test "closing a picker popup retains a fading ghost then prunes it" {
  let received : Array[String] = []
  let runtime = AppRuntime::new_view(
    root=@views.column(
      [
        @views.frame(
          @views.picker(
            [@views.picker_item("one", "One"), @views.picker_item("two", "Two")],
            selected="one",
            on_select=id => id,
            placeholder="Pick",
            max_height=160.0,
          ),
          width=200.0,
          height=40.0,
        ),
      ],
      spacing=0.0,
    ),
    size=@core.Size::new(width=200.0, height=160.0),
    on_message=Some(message => received.push(message)),
  )
  ignore(runtime.draw_frame())
  ignore(
    runtime.dispatch_event(
      @core.AppEvent::Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=12.0, y=12.0),
          phase=@core.PointerPhase::Up,
        ),
      ),
    ),
  )
  ignore(runtime.draw_frame())
  let has_fade = () => {
    runtime
    .draw_commands()
    .any(command => {
      match command {
        @core.DrawCommand::PushOpacity(_) => true
        _ => false
      }
    })
  }
  // Selecting an item closes the popup: the removed subtree replays as a
  // fading ghost until the transition duration elapses.
  ignore(
    runtime.dispatch_event(
      @core.AppEvent::Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=12.0, y=84.0),
          phase=@core.PointerPhase::Up,
        ),
      ),
    ),
  )
  ignore(runtime.draw_frame())
  assert_true(has_fade())
  runtime.advance_time(400.0)
  ignore(runtime.draw_frame())
  assert_true(!has_fade())
}
