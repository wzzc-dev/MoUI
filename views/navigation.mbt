///|
pub(all) struct NavigationDestination {
  route : String
  view : @core.ViewSpec
}

///|
pub(all) struct TabItem {
  route : String
  label : String
  view : @core.ViewSpec
}

///|
pub fn navigation_destination(
  route~ : String,
  view~ : @core.ViewSpec,
) -> NavigationDestination {
  { route, view }
}

///|
pub fn tab_item(
  route~ : String,
  label~ : String,
  view~ : @core.ViewSpec,
) -> TabItem {
  { route, label, view }
}

///|
pub fn navigation_stack(
  state : @core.NavigationState,
  destinations : Array[NavigationDestination],
  fallback? : @core.ViewSpec = @core.ViewSpec::EmptySpec,
) -> @core.ViewSpec {
  let route = state.current()
  for destination in destinations {
    if destination.route == route {
      return destination.view
    }
  }
  fallback
}

///|
pub fn tab_view(
  selection : @core.Binding[String],
  tabs : Array[TabItem],
  spacing? : Double = 8.0,
) -> @core.ViewSpec {
  let selected = selection.get()
  let buttons : Array[@core.ViewSpec] = []
  let mut content = @core.ViewSpec::EmptySpec
  for tab in tabs {
    if tab.route == selected {
      content = tab.view
    }
    buttons.push(
      button(
        tab.label,
        on_click=() => selection.set(tab.route),
        style=if tab.route == selected {
          @core.ButtonStyle::filled()
        } else {
          @core.ButtonStyle::tonal()
        },
        width=112.0,
        height=36.0,
      ).semantics_role(@core.SemanticsRole::Tab),
    )
  }
  column([row(buttons, spacing~), content], spacing~)
}

///|
pub fn dialog_host(
  child : @core.ViewSpec,
  dialog? : @core.ViewSpec? = None,
  presented? : Bool = false,
) -> @core.ViewSpec {
  if presented {
    match dialog {
      Some(dialog) =>
        stack([
          child,
          surface(
            dialog.semantics_role(@core.SemanticsRole::Dialog),
            width=360.0,
            height=220.0,
            style={ ..@core.SurfaceStyle::raised(), shadow: None },
          ).align(alignment=@core.Alignment::center()),
        ])
      None => child
    }
  } else {
    child
  }
}
