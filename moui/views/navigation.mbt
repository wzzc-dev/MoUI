///|
pub struct NavigationDestination[Msg] {
  route : String
  view : @core.View[Msg]
}

///|
pub struct TabItem[Msg] {
  route : String
  label : String
  view : @core.View[Msg]
}

///|
pub fn[Msg] navigation_destination(
  route~ : String,
  view~ : @core.View[Msg],
) -> NavigationDestination[Msg] {
  { route, view }
}

///|
pub fn[Msg] tab_item(
  route~ : String,
  label~ : String,
  view~ : @core.View[Msg],
) -> TabItem[Msg] {
  { route, label, view }
}

///|
pub fn[Msg] navigation_stack(
  state : @core.NavigationState,
  destinations : Array[NavigationDestination[Msg]],
  fallback? : @core.View[Msg] = empty(),
) -> @core.View[Msg] {
  navigation_stack_selected(state.current(), destinations, fallback~)
}

///|
pub fn[Msg] navigation_stack_selected(
  selected : String,
  destinations : Array[NavigationDestination[Msg]],
  fallback? : @core.View[Msg] = empty(),
) -> @core.View[Msg] {
  for destination in destinations {
    if destination.route == selected {
      return destination.view
    }
  }
  fallback
}

///|
pub fn[Msg] router_stack(
  router : RouterState,
  destinations : Array[NavigationDestination[Msg]],
  fallback? : @core.View[Msg] = empty(),
) -> @core.View[Msg] {
  let location = router.current()
  for destination in destinations {
    if destination.route == location.path ||
      destination.route == location.to_route() {
      return destination.view
    }
  }
  fallback
}

///|
pub fn[Msg] tab_view(
  selected : String,
  tabs : Array[TabItem[Msg]],
  spacing? : Double = 8.0,
  on_select~ : (String) -> Msg,
) -> @core.View[Msg] {
  let buttons : Array[@core.View[Msg]] = []
  let mut content = empty()
  for tab in tabs {
    if tab.route == selected {
      content = tab.view
    }
    let tab_button = button(
        tab.label,
        on_click=on_select(tab.route),
        variant=if tab.route == selected {
          ButtonVariant::Primary
        } else {
          ButtonVariant::Tonal
        },
        width=112.0,
        height=36.0,
      )
      .semantics_role(@core.SemanticsRole::Tab)
      .semantics_selected(selected=tab.route == selected)
    buttons.push(tab_button)
  }
  column([row(buttons, spacing~), content], spacing~)
}

