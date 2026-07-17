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
  let window = @views.container(
      @views.column(
        [titlebar, body],
        spacing=0.0,
        align=@views.CrossAlign::Stretch,
      ),
      width=metrics.width,
      height=metrics.height,
      background=palette.glass_strong,
      corner_radius=if model.window_maximized { 10.0 } else { 18.0 },
      border=Some(desktop_hairline(palette)),
      padding=0.0,
    )
    .shadow(desktop_shadow(palette))
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
  let controls = @views.row(
    [
      traffic_light(rgba8(255, 95, 87), "Close window", CloseWindow, palette),
      traffic_light(
        rgba8(255, 189, 46),
        "Minimize window",
        MinimizeWindow,
        palette,
      ),
      traffic_light(rgba8(40, 200, 64), "Zoom window", ToggleMaximize, palette),
    ],
    spacing=8.0,
    align=@views.CrossAlign::Center,
  )
  @views.container(
    @views.row(
      [
        @views.container(
          controls,
          width=84.0,
          height=30.0,
          background=rgba8(0, 0, 0, a=0.0),
          padding=4.0,
        ),
        @views.spacer(min_length=4.0),
        @views.text(
          title,
          role=@views.TextRole::Label,
          theme~,
          width=(width * 0.36).max(120.0),
          height=28.0,
          align=@text.TextAlign::TextCenter,
        )
        .font(@text.FontSpec::new(size=15.0, weight=650))
        .foreground(palette.foreground),
        @views.spacer(min_length=88.0),
      ],
      spacing=0.0,
      align=@views.CrossAlign::Center,
    ),
    width~,
    height=48.0,
    background=palette.glass_strong,
    padding=8.0,
  )
}

///|
fn traffic_light(
  color : @graphics.Color,
  label : String,
  message : Msg,
  palette : DesktopPalette,
) -> @moui.View[Msg] {
  @views.container(
    @views.spacer(min_length=0.0, weight=0.0),
    width=14.0,
    height=14.0,
    background=color,
    corner_radius=7.0,
    border=Some(desktop_hairline(palette)),
    padding=0.0,
  )
  .on_tap(message)
  .accessibility_label(label)
}
