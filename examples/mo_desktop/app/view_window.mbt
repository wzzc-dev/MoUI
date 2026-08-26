///|
priv struct WindowMetrics {
  width : Double
  height : Double
  compact : Bool
}

///|
/// Resolve the on-screen size of one window. Explicitly resized windows keep
/// the user-chosen size (clamped to stay on screen); otherwise the legacy
/// responsive defaults apply. Zoomed windows fill the viewport minus chrome.
fn window_metrics(
  record : WindowRecord,
  viewport_width : Double,
  viewport_height : Double,
) -> WindowMetrics {
  let compact = viewport_width < 760.0
  if record.state == MaximizedWindow {
    {
      width: (viewport_width - 18.0).max(272.0),
      height: (viewport_height - 58.0).max(350.0),
      compact,
    }
  } else if compact {
    let width = if record.bounds.width > 0.0 {
      record.bounds.width.max(272.0)
    } else {
      (viewport_width - 20.0).max(272.0)
    }
    let height = if record.bounds.height > 0.0 {
      record.bounds.height.max(350.0)
    } else {
      (viewport_height - 118.0).max(350.0)
    }
    { width, height, compact }
  } else {
    let width = if record.bounds.width > 0.0 {
      record.bounds.width.min(viewport_width - 24.0).max(272.0)
    } else {
      (viewport_width * 0.74).min(980.0).max(720.0)
    }
    let height = if record.bounds.height > 0.0 {
      record.bounds.height.min(viewport_height - 58.0).max(350.0)
    } else {
      (viewport_height * 0.74).min(620.0).max(480.0)
    }
    { width, height, compact }
  }
}

///|
/// Live title for a window: Finder tracks the current location and Safari
/// tracks the active page, matching single-instance macOS apps whose
/// titlebar mirrors document state.
fn window_title(model : DesktopModel, record : WindowRecord) -> String {
  match record.id.app {
    FinderApp => model.finder_location.label()
    SafariApp =>
      match model.browser_page {
        StartPage => "Start Page"
        SearchResults(_) => "Mo Browser"
      }
    NotesApp =>
      if model.notes.is_empty() {
        "Notes"
      } else {
        model.note_title(model.active_note)
      }
    TerminalApp => "Terminal"
  }
}

///|
fn app_window(
  model : DesktopModel,
  record : WindowRecord,
  body : @moui.View[Msg],
  palette : DesktopPalette,
  theme : @moui.Theme,
  viewport_width : Double,
  viewport_height : Double,
) -> @moui.View[Msg] {
  let focused = match model.focused_id() {
    Some(id) => id == record.id
    None => false
  }
  let maximized = record.state == MaximizedWindow
  let metrics = window_metrics(record, viewport_width, viewport_height)
  let titlebar = window_titlebar(
      model,
      record,
      focused,
      metrics.width,
      palette,
      theme,
    )
    .on_drag(event => MoveWindowBy(event.delta.x, event.delta.y))
    // Double-clicking a macOS title bar zooms/restores that window.
    .on_double_tap(ToggleZoomAt(record.id))
    // Clicking any window chrome brings that window to the front.
    .on_tap(FocusWindow(record.id))
  // Focused windows get the deeper macOS key-window shadow; background
  // windows sit back with a lighter one and a dimmer rim. Shadows stay tight
  // so they do not smear across the dock below.
  let rim_alpha = if focused {
    if palette.dark {
      0.14
    } else {
      0.10
    }
  } else if palette.dark {
    0.08
  } else {
    0.06
  }
  let rim = @graphics.BorderStyle::new(
    brush=@graphics.Brush::solid(
      if palette.dark {
        rgba8(255, 255, 255, a=rim_alpha)
      } else {
        rgba8(0, 0, 0, a=rim_alpha)
      },
    ),
    width=1.0,
  )
  let radius = if maximized { 10.0 } else { 12.0 }
  let window = @views.stack([
      @views.container(
        @views.column(
          [titlebar, body],
          spacing=0.0,
          align=@views.CrossAlign::Stretch,
        ),
        width=metrics.width,
        height=metrics.height,
        background=palette.glass_strong,
        corner_radius=radius,
        border=Some(rim),
        padding=0.0,
      ),
      // macOS bottom-right resize grip: hidden while maximized.
      if maximized {
        @views.spacer(min_length=0.0, weight=0.0)
      } else {
        resize_grip(model, record, metrics, palette)
      },
    ])
    .frame(width=metrics.width, height=metrics.height)
    .clip()
  window
  .align(alignment=@geometry.Alignment::center())
  .offset(
    dx=if maximized { 0.0 } else { record.bounds.offset_x },
    dy=if maximized { 8.0 } else { record.bounds.offset_y - 2.0 },
  )
  .frame(width=viewport_width, height=viewport_height)
}

///|
/// The bottom-right resize grip: a small canvas cell (26x26) anchored to the
/// window's bottom-trailing corner that both paints the diagonal affordance
/// and carries the resize drag.
///
/// It is deliberately SMALL: `canvas` and gesture nodes intercept pointer
/// events across their entire paint bounds, so an oversized grip layer would
/// deafen every other interaction in the window (close buttons, titlebar
/// drags). Keeping the surface corner-sized scopes interception to exactly
/// the resize zone.
fn resize_grip(
  model : DesktopModel,
  record : WindowRecord,
  metrics : WindowMetrics,
  palette : DesktopPalette,
) -> @moui.View[Msg] {
  let line_color = if palette.dark {
    rgba8(255, 255, 255, a=0.38)
  } else {
    rgba8(60, 70, 84, a=0.42)
  }
  let cell = 26.0
  let inset = 6.0
  let inner = cell - inset * 2.0
  let stroke = @graphics.Brush::solid(line_color)
  let id = record.id
  @views.canvas(
    measure=_ => @geometry.Size::new(width=cell, height=cell),
    draw=fn(ctx, _rect) {
      for index in 0..<3 {
        let offset = index.to_double() * 4.0
        let x0 = inset + offset
        let y1 = inset + inner - offset
        @views.draw_path(
          ctx,
          @graphics.PathSpec::new(
            verbs=[
              @graphics.PathVerb::MoveTo(
                @geometry.Point::new(x=x0, y=inset + inner),
              ),
              @graphics.PathVerb::LineTo(
                @geometry.Point::new(x=inset + inner, y=y1),
              ),
            ],
            stroke=Some(stroke),
            stroke_width=1.6,
          ),
        )
      }
    },
    semantics_label="Resize window",
  )
  .frame(width=cell, height=cell)
  // CRITICAL ORDER: bind the drag to the small sized node BEFORE align.
  // `on_drag` outside `align` inherits the parent slot as its hit area, so
  // it swallows every press in the window (resize instead of move, dead
  // traffic lights).
  .on_drag(event => {
    ResizeWindowBy(
      id,
      clamp_window_width(metrics.width + event.delta.x),
      clamp_window_height(metrics.height + event.delta.y),
    )
  })
  .align(alignment=@geometry.Alignment::bottom_trailing())
  .accessibility_label("Resize " + window_title(model, record) + " window")
}

///|
fn window_titlebar(
  model : DesktopModel,
  record : WindowRecord,
  focused : Bool,
  width : Double,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  let id = record.id
  // macOS traffic lights: 12pt circles, 8pt apart, 20pt from the leading edge.
  let controls = @views.row(
    [
      traffic_light(
        rgba8(255, 95, 87),
        "×",
        "Close window",
        CloseWindowAt(id),
        focused,
      ),
      traffic_light(
        rgba8(255, 189, 46),
        "−",
        "Minimize window",
        MinimizeWindowAt(id),
        focused,
      ),
      traffic_light(
        rgba8(40, 200, 64),
        "+",
        "Zoom window",
        ToggleZoomAt(id),
        focused,
      ),
    ],
    spacing=8.0,
    align=@views.CrossAlign::Center,
  )
  // Background windows dim their titles like macOS non-key windows.
  let foreground = if focused {
    palette.foreground
  } else {
    palette.foreground.multiply_alpha(0.55)
  }
  let title_label = @views.text(
      window_title(model, record),
      role=@views.TextRole::Label,
      theme~,
      width=(width * 0.42).max(140.0),
      height=22.0,
      align=@text.TextAlign::TextCenter,
    )
    .font(@text.FontSpec::new(size=13.0, weight=590))
    .foreground(foreground)
  // Unified titlebar: the same frosted material as the window body so the
  // toolbar reads as a seamless continuation of the document surface.
  @views.stack([
    @views.container(
      @views.spacer(min_length=0.0, weight=0.0),
      width~,
      height=40.0,
      background=palette.glass_strong,
      padding=0.0,
    ),
    @views.padding_edges(controls, left=20.0, top=13.0, bottom=13.0, right=0.0).align(
      alignment=@geometry.Alignment::top_leading(),
    ),
    // The label carries the same gestures: text nodes handle pointer events
    // across their bounds, so dragging must work when grabbing the title too.
    title_label
    .on_drag(event => MoveWindowBy(event.delta.x, event.delta.y))
    .on_double_tap(ToggleZoomAt(record.id))
    .on_tap(FocusWindow(record.id))
    .align(alignment=@geometry.Alignment::center())
    .frame(width~, height=40.0),
  ])
  .frame(width~, height=40.0)
  .accessibility_label(
    "Move or zoom " + window_title(model, record) + " window",
  )
}

///|
fn traffic_light(
  color : @graphics.Color,
  symbol : String,
  label : String,
  message : Msg,
  focused : Bool,
) -> @moui.View[Msg] {
  // 12pt traffic light with a darker rim, matching the macOS inset look.
  // Background windows mute their lights until clicked. Note: no hover-glyph
  // overlay here — stacked text over the dot swallows its tap.
  ignore(symbol)
  let fill = if focused { color } else { color.multiply_alpha(0.45) }
  @views.container(
    @views.spacer(min_length=0.0, weight=0.0),
    width=12.0,
    height=12.0,
    background=fill,
    corner_radius=6.0,
    border=Some(
      @graphics.BorderStyle::new(
        brush=@graphics.Brush::solid(rgba8(0, 0, 0, a=0.16)),
        width=0.8,
      ),
    ),
    padding=0.0,
  )
  .on_tap(message)
  .accessibility_label(label)
}
