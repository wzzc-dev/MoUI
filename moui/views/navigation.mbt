///|
pub(all) struct NavigationDestination[Msg] {
  route : String
  view : @core.View[Msg]
}

///|
pub(all) struct TabItem[Msg] {
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
  let route = state.current()
  for destination in destinations {
    if destination.route == route {
      return destination.view
    }
  }
  fallback
}

///|
pub fn[Msg] tab_view(
  selection : @core.Binding[String],
  tabs : Array[TabItem[Msg]],
  spacing? : Double = 8.0,
  on_select~ : (String) -> Msg,
) -> @core.View[Msg] {
  let selected = selection.get()
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
    ).semantics_role(@core.SemanticsRole::Tab)
    buttons.push(tab_button)
  }
  column([row(buttons, spacing~), content], spacing~)
}

///|
pub fn[Msg] dialog_host(
  child : @core.View[Msg],
  dialog? : @core.View[Msg]? = None,
  presented? : Bool = false,
) -> @core.View[Msg] {
  if presented {
    match dialog {
      Some(dialog) =>
        stack([
          child,
          surface(
            dialog.semantics_role(@core.SemanticsRole::Dialog),
            width=360.0,
            height=220.0,
            variant=SurfaceVariant::Raised,
          ).align(alignment=@core.Alignment::center()),
        ])
      None => child
    }
  } else {
    child
  }
}
