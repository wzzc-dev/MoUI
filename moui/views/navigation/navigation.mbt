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
  /// Whether the tab offers a close affordance. Apps that own closing pass a
  /// `on_close` handler to `tab_strip`; the flag lets a tab opt out (a pinned
  /// or permanent tab) without changing the handler.
  closable : Bool
  /// Unsaved marker: draws a dot in place of the close glyph while the tab's
  /// document has unsaved edits, the way editor tabs do.
  dirty : Bool
  /// Optional leading glyph (file kind, document icon) before the label.
  icon : @style.IconName?
  /// Pinned tabs render the pin glyph and never a close button.
  pinned : Bool
}

///|
pub fn[Msg] navigation_destination(
  route~ : String,
  view~ : @core.View[Msg],
) -> NavigationDestination[Msg] {
  { route, view, }
}

///|
pub fn[Msg] tab_item(
  route~ : String,
  label~ : String,
  view~ : @core.View[Msg],
  closable~ : Bool = false,
  dirty~ : Bool = false,
  icon~ : @style.IconName? = None,
  pinned~ : Bool = false,
) -> TabItem[Msg] {
  { route, label, view, closable, dirty, icon, pinned, }
}

///|
pub fn[Msg] navigation_stack_selected(
  selected : String,
  destinations : Array[NavigationDestination[Msg]],
  fallback~ : @core.View[Msg] = @container.empty(),
  transition~ : RouteTransition = route_transition_none(),
) -> @core.View[Msg] {
  let mut matched = fallback
  let mut matched_route = "@fallback"
  for destination in destinations {
    if destination.route == selected {
      matched = destination.view
      matched_route = destination.route
    }
  }
  if transition.duration_ms <= 0.0 {
    matched
  } else {
    route_stack_transition_view(
      matched,
      top_route=matched_route,
      route_count=destinations.length(),
      transition~,
    )
  }
}

///|
pub fn[Msg] router_stack(
  router : RouterState,
  destinations : Array[NavigationDestination[Msg]],
  fallback~ : @core.View[Msg] = @container.empty(),
  transition~ : RouteTransition = route_transition_none(),
) -> @core.View[Msg] {
  let location = router.current()
  let mut matched = fallback
  let mut matched_route = "@fallback"
  for destination in destinations {
    if destination.route == location.path ||
      destination.route == location.to_route() {
      matched = destination.view
      matched_route = destination.route
    }
  }
  if transition.duration_ms <= 0.0 {
    matched
  } else {
    route_stack_transition_view(
      matched,
      top_route=matched_route,
      route_count=router.routes.length(),
      transition~,
    )
  }
}

///|
/// A tab strip on its own: the app places its own content below.
///
/// `selected` is the route whose content is showing, `active` the route that
/// holds keyboard focus (they differ while the user is cycling tabs with the
/// keyboard). `trailing` reserves the strip's end for an overflow button or a
/// pair of paging arrows, so an app that measures its own overflow never has
/// to re-implement the tabs themselves.
pub fn[Msg] tab_strip(
  selected : String,
  tabs : Array[TabItem[Msg]],
  on_select~ : (String) -> Msg,
  on_close~ : ((String) -> Msg)? = None,
  on_secondary_tap_with_frame~ : ((String, @core.Point, @core.Rect) -> Msg)? = None,
  active~ : String = "",
  trailing~ : @core.View[Msg]? = None,
  spacing~ : Double = 8.0,
  height~ : Double = 36.0,
  theme? : @core.Theme,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  let chips : Array[@core.View[Msg]] = []
  for tab in tabs {
    chips.push(
      tab_chip(
        tab,
        selected=tab.route == selected,
        active=tab.route == active,
        on_select~,
        on_close~,
        on_secondary_tap_with_frame~,
        height~,
        theme=resolved_theme,
      ),
    )
  }
  let strip = @layout.row(chips, spacing~, align=Center)
  let strip = match trailing {
    Some(extra) =>
      @layout.row(
        [strip, @container.spacer(min_length=0.0, weight=1.0), extra],
        spacing~,
        align=Center,
      )
    None => strip
  }
  strip.semantics_role(Tab)
}

///|
fn[Msg] tab_chip(
  tab : TabItem[Msg],
  selected~ : Bool,
  active~ : Bool,
  on_select~ : (String) -> Msg,
  on_close~ : ((String) -> Msg)?,
  on_secondary_tap_with_frame~ : ((String, @core.Point, @core.Rect) -> Msg)?,
  height~ : Double,
  theme~ : @core.Theme,
) -> @core.View[Msg] {
  let children : Array[@core.View[Msg]] = []
  // A pinned tab leads with the pin glyph; otherwise the tab's own icon, and
  // neither when the app passes none.
  if tab.pinned {
    children.push(@icon.icon(Pin, size=12.0, color=theme.palette.muted))
  } else {
    match tab.icon {
      Some(name) =>
        children.push(@icon.icon(name, size=12.0, color=theme.palette.muted))
      None => ()
    }
  }
  let label_color = if selected {
    theme.palette.on_surface
  } else {
    theme.palette.muted
  }
  children.push(
    @text.text(tab.label, role=Body, theme~).foreground(label_color),
  )
  // The trailing slot carries exactly one marker: pinned tabs show none, a
  // dirty tab shows the unsaved dot (it wins over the close glyph, as in an
  // editor, so an accidental click cannot close unsaved work), and a closable
  // tab with a handler shows the close glyph.
  if !tab.pinned {
    if tab.dirty {
      children.push(
        @text.text("●", role=Caption, theme~).foreground(
          theme.palette.primary,
        ),
      )
    } else if tab.closable {
      match on_close {
        Some(handler) =>
          children.push(
            @layout.padding_xy(
              @icon.icon(Close, size=10.0, color=theme.palette.muted),
              horizontal=2.0,
              vertical=2.0,
            ).on_tap(handler(tab.route)),
          )
        None => ()
      }
    }
  }
  let inner = @layout.padding_xy(
    @layout.row(children, spacing=6.0, align=Center),
    horizontal=10.0,
    vertical=5.0,
  )
  let background = @core.Brush::solid(
    if selected {
      theme.palette.surface
    } else {
      theme.palette.background
    },
  )
  let chip = @layout.container_box(
      child=Some(inner),
      background=Some(background),
      corner_radius=6.0,
    )
    .frame(height~)
    .on_tap(on_select(tab.route))
  let chip = match on_secondary_tap_with_frame {
    Some(handler) =>
      chip.on_secondary_tap_with_frame((point, frame) => {
        handler(tab.route, point, frame)
      })
    None => chip
  }
  let chip = if active {
    chip.border(
      @core.BorderStyle::new(
        brush=@core.Brush::solid(theme.palette.primary),
        width=1.0,
      ),
    )
  } else {
    chip
  }
  chip
  .cursor(@core.CursorStyle::Icon(@core.CursorIcon::CursorPointer))
  .key("tab-" + tab.route)
  .semantics_role(Tab)
  .semantics_selected(selected~)
  .accessibility_label(tab.label)
}

///|
pub fn[Msg] tab_view(
  selected : String,
  tabs : Array[TabItem[Msg]],
  spacing~ : Double = 8.0,
  on_select~ : (String) -> Msg,
) -> @core.View[Msg] {
  let mut content = @container.empty()
  for tab in tabs {
    if tab.route == selected {
      content = tab.view
    }
  }
  @layout.column(
    [tab_strip(selected, tabs, on_select~, spacing~), content],
    spacing~,
  )
}
