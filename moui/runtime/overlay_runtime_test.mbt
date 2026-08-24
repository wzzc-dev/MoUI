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
          anchor=@views.PresentationAnchor::stable_key("menu-anchor"),
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
