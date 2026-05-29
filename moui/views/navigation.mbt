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
  router : @core.RouterState,
  destinations : Array[NavigationDestination[Msg]],
  fallback? : @core.View[Msg] = empty(),
) -> @core.View[Msg] {
  let location = router.current()
  for destination in destinations {
    if destination.route == location.path || destination.route == location.to_route() {
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
    ).semantics_role(@core.SemanticsRole::Tab)
    .semantics_selected(selected=tab.route == selected)
    buttons.push(tab_button)
  }
  column([row(buttons, spacing~), content], spacing~)
}

///|
pub fn[Msg] tab_view_binding(
  selection : @core.Binding[String],
  tabs : Array[TabItem[Msg]],
  spacing? : Double = 8.0,
  on_select~ : (String) -> Msg,
) -> @core.View[Msg] {
  tab_view(selection.get(), tabs, spacing~, on_select~)
}

///|
pub fn[Msg] sidebar(
  title : String,
  items : Array[SidebarItem[Msg]],
  selected~ : String,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 240.0,
  height? : Double = 320.0,
) -> @core.View[Msg] {
  let inner_width = views_max_double(96.0, width - theme.spacing_scale.md * 2.0)
  let rows : Array[@core.View[Msg]] = [
    text(title, role=TextRole::Control, theme~, width=inner_width, height=28.0),
  ]
  for item in items {
    let variant = if item.id == selected {
      ButtonVariant::Primary
    } else {
      ButtonVariant::Ghost
    }
    rows.push(
      button(
        item.label,
        on_click=item.message,
        variant~,
        theme~,
        width=inner_width,
        height=34.0,
      )
      .disabled(disabled=!item.enabled)
      .semantics_selected(selected=item.id == selected)
      .key("sidebar-item-" + item.id),
    )
  }
  surface(
    column(rows, spacing=theme.spacing_scale.sm, align=CrossAlign::Start),
    width~,
    height~,
    variant=SurfaceVariant::Base,
    theme~,
    padding=theme.spacing_scale.md,
  ).semantics_role(@core.SemanticsRole::List)
}

///|
pub fn[Msg] breadcrumb(
  items : Array[BreadcrumbItem[Msg]],
  theme? : @core.Theme = @core.Theme::default(),
  spacing? : Double = @core.Theme::default().spacing_scale.xs,
) -> @core.View[Msg] {
  let children : Array[@core.View[Msg]] = []
  for index, item in items {
    if index > 0 {
      children.push(
        text("/", role=TextRole::Caption, theme~, width=14.0, height=28.0),
      )
    }
    let child : @core.View[Msg] = match item.message {
      Some(message) =>
        button(
          item.label,
          on_click=message,
          variant=ButtonVariant::Ghost,
          theme~,
          width=breadcrumb_item_width(item.label),
          height=30.0,
        )
      None =>
        text(
          item.label,
          role=TextRole::Control,
          theme~,
          width=breadcrumb_item_width(item.label),
          height=30.0,
        )
    }
    children.push(child.key("breadcrumb-item-" + item.id))
  }
  row(children, spacing~, align=CrossAlign::Center).semantics_role(
    @core.SemanticsRole::Group,
  )
}

///|
pub fn[Msg] split_view(
  primary~ : @core.View[Msg],
  detail~ : @core.View[Msg],
  primary_width? : Double = 240.0,
  detail_width? : Double = 480.0,
  height? : Double = 320.0,
  spacing? : Double = @core.Theme::default().spacing_scale.md,
) -> @core.View[Msg] {
  row(
    [
      primary.frame(width=primary_width, height~),
      detail.frame(width=detail_width, height~),
    ],
    spacing~,
    align=CrossAlign::Start,
  ).semantics_role(@core.SemanticsRole::Group)
}

///|
pub fn[Msg] master_detail(
  master~ : @core.View[Msg],
  detail~ : @core.View[Msg],
  master_width? : Double = 220.0,
  detail_width? : Double = 420.0,
  height? : Double = 300.0,
  spacing? : Double = @core.Theme::default().spacing_scale.md,
) -> @core.View[Msg] {
  split_view(
    primary=master,
    detail~,
    primary_width=master_width,
    detail_width~,
    height~,
    spacing~,
  )
}

///|
pub fn[Msg] wizard_step(step : WizardStep[Msg]) -> @core.View[Msg] {
  step.content
}

///|
pub fn[Msg] wizard(
  steps : Array[WizardStep[Msg]],
  current~ : String,
  on_select~ : (String) -> Msg,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 520.0,
  height? : Double = 260.0,
) -> @core.View[Msg] {
  let header_width = views_max_double(120.0, width - theme.spacing_scale.md * 2.0)
  let step_count = views_max_int(1, steps.length())
  let step_width = views_max_double(88.0, header_width / step_count.to_double() - 4.0)
  let step_buttons : Array[@core.View[Msg]] = []
  let mut content = empty()
  for step in steps {
    if step.id == current {
      content = wizard_step(step)
    }
    let variant = if step.id == current {
      ButtonVariant::Primary
    } else {
      ButtonVariant::Tonal
    }
    step_buttons.push(
      button(
        step.title,
        on_click=on_select(step.id),
        variant~,
        theme~,
        width=step_width,
        height=36.0,
      )
      .disabled(disabled=!step.enabled)
      .semantics_role(@core.SemanticsRole::Tab)
      .semantics_selected(selected=step.id == current),
    )
  }
  surface(
    column(
      [
        row(step_buttons, spacing=theme.spacing_scale.xs, align=CrossAlign::Center),
        content.frame(width=header_width, height=height - 74.0),
      ],
      spacing=theme.spacing_scale.md,
      align=CrossAlign::Start,
    ),
    width~,
    height~,
    variant=SurfaceVariant::Raised,
    theme~,
    padding=theme.spacing_scale.md,
  ).semantics_role(@core.SemanticsRole::Group)
}

///|
fn breadcrumb_item_width(label : String) -> Double {
  views_max_double(42.0, label.to_array().length().to_double() * 8.0 + 24.0)
}

///|
fn views_max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
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
