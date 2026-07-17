///|
priv struct WindowMetrics {
  width : Double
  height : Double
  compact : Bool
}

///|
fn window_metrics(
  model : DesktopModel,
  viewport_width : Double,
  viewport_height : Double,
) -> WindowMetrics {
  let compact = viewport_width < 760.0
  if model.window_maximized {
    {
      width: (viewport_width - 18.0).max(272.0),
      height: (viewport_height - 58.0).max(350.0),
      compact,
    }
  } else if compact {
    {
      width: (viewport_width - 20.0).max(272.0),
      height: (viewport_height - 118.0).max(350.0),
      compact,
    }
  } else {
    {
      width: (viewport_width * 0.74).min(980.0).max(720.0),
      height: (viewport_height * 0.74).min(620.0).max(480.0),
      compact,
    }
  }
}

///|
fn app_window(
  model : DesktopModel,
  title : String,
  body : @moui.View[Msg],
  metrics : WindowMetrics,
  palette : DesktopPalette,
  theme : @moui.Theme,
  viewport_width : Double,
  viewport_height : Double,
) -> @moui.View[Msg] {
  let titlebar = window_titlebar(title, metrics.width, palette, theme)
  // Soft rim + deeper shadow so floating windows separate from wallpaper.
  let rim = @graphics.BorderStyle::new(
    brush=@graphics.Brush::solid(
      if palette.dark {
        rgba8(255, 255, 255, a=0.14)
      } else {
        rgba8(0, 0, 0, a=0.10)
      },
    ),
    width=1.0,
  )
  let radius = if model.window_maximized { 10.0 } else { 12.0 }
  let window = @views.container(
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
    )
    .shadow(
      @graphics.ShadowStyle::new(
        color=palette.shadow.multiply_alpha(0.72),
        offset=@geometry.Point::new(x=0.0, y=18.0),
        blur_radius=42.0,
        spread=0.0,
      ),
    )
    .clip()
  window
  .align(alignment=@geometry.Alignment::center())
  .offset(dy=if model.window_maximized { 8.0 } else { -2.0 })
  .frame(width=viewport_width, height=viewport_height)
}

///|
fn window_titlebar(
  title : String,
  width : Double,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  // macOS traffic lights sit tight on the leading edge; title is centered in
  // the full titlebar width rather than squeezed between asymmetric spacers.
  let controls = @views.row(
    [
      traffic_light(rgba8(255, 95, 87), "Close window", CloseWindow),
      traffic_light(rgba8(255, 189, 46), "Minimize window", MinimizeWindow),
      traffic_light(rgba8(40, 200, 64), "Zoom window", ToggleMaximize),
    ],
    spacing=8.0,
    align=@views.CrossAlign::Center,
  )
  let title_label = @views.text(
      title,
      role=@views.TextRole::Label,
      theme~,
      width=(width * 0.42).max(140.0),
      height=22.0,
      align=@text.TextAlign::TextCenter,
    )
    .font(@text.FontSpec::new(size=13.0, weight=590))
    .foreground(palette.foreground)
  @views.stack([
    @views.container(
      @views.spacer(min_length=0.0, weight=0.0),
      width~,
      height=40.0,
      background=palette.glass_strong,
      border=Some(
        @graphics.BorderStyle::new(
          brush=@graphics.Brush::solid(palette.outline.multiply_alpha(0.72)),
          width=1.0,
        ),
      ),
      padding=0.0,
    ),
    @views.padding_edges(controls, left=14.0, top=13.0, bottom=13.0, right=0.0).align(
      alignment=@geometry.Alignment::top_leading(),
    ),
    title_label
    .align(alignment=@geometry.Alignment::center())
    .frame(width~, height=40.0),
  ]).frame(width~, height=40.0)
}

///|
fn traffic_light(
  color : @graphics.Color,
  label : String,
  message : Msg,
) -> @moui.View[Msg] {
  // Classic 12pt traffic lights with a subtle darker rim (no frosted outline).
  @views.container(
    @views.spacer(min_length=0.0, weight=0.0),
    width=12.0,
    height=12.0,
    background=color,
    corner_radius=6.0,
    border=Some(
      @graphics.BorderStyle::new(
        brush=@graphics.Brush::solid(rgba8(0, 0, 0, a=0.18)),
        width=0.8,
      ),
    ),
    padding=0.0,
  )
  .on_tap(message)
  .accessibility_label(label)
}
