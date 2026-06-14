///|
test "section nav dispatches selected item messages" {
  let selected = Ref("")
  let runtime = @runtime.AppRuntime::new_view(
    root=@views.section_nav(
      "Areas",
      [
        @views.SectionNavItem::new(
          id="builder",
          label="Builder",
          summary="App setup",
          message="builder",
        ),
        @views.SectionNavItem::new(
          id="runtime",
          label="Runtime",
          summary="Renderer host",
          message="runtime",
        ),
        @views.SectionNavItem::new(
          id="billing",
          label="Billing",
          summary="Disabled",
          message="billing",
          enabled=false,
        ),
      ],
      selected="builder",
      width=480.0,
    ),
    size=@core.Size::new(width=520.0, height=140.0),
    on_message=Some(message => selected.val = message),
  )
  guard text_frame(runtime.draw_commands(), "Runtime") is Some(runtime_frame) else {
    fail("expected runtime section item")
  }
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(
          x=runtime_frame.origin.x + 4.0,
          y=runtime_frame.origin.y + 4.0,
        ),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(
          x=runtime_frame.origin.x + 4.0,
          y=runtime_frame.origin.y + 4.0,
        ),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  inspect(selected.val, content="runtime")
}

///|
test "router stack selects route location path and preserves query params" {
  let router = @core.RouterState::new(
    initial=@core.RouteLocation::parse("/detail?id=42"),
  )
  let root : @core.View[Unit] = @views.router_stack(
    router,
    [
      @views.navigation_destination(
        route="/home",
        view=@views.text("Home route", width=120.0),
      ),
      @views.navigation_destination(
        route="/detail",
        view=@views.text("Detail route", width=120.0),
      ),
    ],
    fallback=@views.text("Missing route", width=120.0),
  )
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=320.0, height=120.0),
  )
  assert_true(has_text(runtime.draw_commands(), "Detail route"))
  inspect(router.current().param_value("id").unwrap_or(""), content="42")
}
