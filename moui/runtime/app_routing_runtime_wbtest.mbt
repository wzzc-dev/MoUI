///|
test "route focus store restores keyed runtime focus" {
  let store = RouteFocusStore::new()
  store.remember(route="/settings", focus_key="email")
  store.remember_location(
    RouteLocation::parse("/detail?id=42"),
    focus_key="detail-title",
  )
  inspect(store.focus_key("/settings").unwrap_or(""), content="email")
  inspect(
    store
    .focus_key_for_location(RouteLocation::parse("/detail?id=42"))
    .unwrap_or(""),
    content="detail-title",
  )
  inspect(
    store
    .focus_key_for_location(RouteLocation::parse("/settings?tab=form"))
    .unwrap_or(""),
    content="email",
  )
  let email = State::new("")
  let title = State::new("")
  let runtime = RuntimeState::new_spec(
    root=ViewSpec::FlexSpec({
      key: None,
      axis: Axis::Vertical,
      spacing: 8.0,
      main_axis_alignment: MainStart,
      cross_axis_alignment: CrossStretch,
      children: [
        test_text_field(email.binding()).key("email"),
        test_text_field(title.binding()).key("detail-title"),
      ],
    }),
    size=Size::new(width=160.0, height=120.0),
  )
  match store.focus_key("/settings") {
    Some(key) => assert_true(runtime.focus_key(key))
    None => fail("expected settings focus key")
  }
  runtime.dispatch_event(TextInput(InsertText("a")))
  match store.focus_key_for_location(RouteLocation::parse("/detail?id=42")) {
    Some(key) => assert_true(runtime.focus_key(key))
    None => fail("expected detail focus key")
  }
  runtime.dispatch_event(TextInput(InsertText("b")))
  inspect(email.get(), content="a")
  inspect(title.get(), content="b")
}
