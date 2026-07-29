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
    .on_drag(event => MoveWindowBy(event.delta.x, event.delta.y))
    // Double-clicking a macOS title bar zooms/restores the focused window.
    .on_double_tap(ToggleMaximize)
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
      // macOS bottom-right resize grip: a subtle layered set of lines that
      // read as a diagonal "grab" affordance. Hidden when maximized.
      if model.window_maximized {
        @views.spacer(min_length=0.0, weight=0.0)
      } else {
        resize_grip(metrics.width, metrics.height, palette)
      },
    ])
    .frame(width=metrics.width, height=metrics.height)
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
  .offset(
    dx=if model.window_maximized { 0.0 } else { model.window_offset_x },
    dy=if model.window_maximized { 8.0 } else { model.window_offset_y - 2.0 },
  )
  .frame(width=viewport_width, height=viewport_height)
}

///|
/// The bottom-right resize grip: three short translucent diagonal lines
/// inset from the corner, drawn via the public `canvas` paint hook so they
/// read as a true macOS resize affordance (not stacked horizontal strips).
/// On light mode they are dark-tinted; on dark mode they are light-tinted,
/// so the grip reads on either wallpaper.
fn resize_grip(
  window_width : Double,
  window_height : Double,
  palette : DesktopPalette,
) -> @moui.View[Msg] {
  let line_color = if palette.dark {
    rgba8(255, 255, 255, a=0.38)
  } else {
    rgba8(60, 70, 84, a=0.42)
  }
  // A 14x14 grip cell anchored 8pt in from the bottom-right corner. Each of
  // the three diagonal strokes runs from the cell's bottom-left toward its
  // top-right, offset by 4pt so the bundle reads as a single "grab" mark.
  let cell = 14.0
  let inset = 8.0
  let origin_x = window_width - inset - cell
  let origin_y = window_height - inset - cell
  let stroke = @graphics.Brush::solid(line_color)
  @views.canvas(
    measure=_ => @geometry.Size::new(width=window_width, height=window_height),
    draw=fn(ctx, _rect) {
      for index in 0..<3 {
        let offset = index.to_double() * 4.0
        let x0 = origin_x + offset
        let y1 = origin_y + cell - offset
        // The stroke endpoints are clipped to the grip cell so the line never
        // escapes the corner; this keeps the visual tight and diagonal.
        @views.draw_path(
          ctx,
          @graphics.PathSpec::new(
            verbs=[
              @graphics.PathVerb::MoveTo(
                @geometry.Point::new(x=x0, y=origin_y + cell),
              ),
              @graphics.PathVerb::LineTo(
                @geometry.Point::new(x=origin_x + cell, y=y1),
              ),
            ],
            stroke=Some(stroke),
            stroke_width=1.6,
          ),
        )
      }
    },
    semantics_label="Resize window",
  ).frame(width=window_width, height=window_height)
}

///|
fn window_titlebar(
  title : String,
  width : Double,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  // macOS traffic lights: 12pt circles, 8pt apart, 20pt from the leading edge.
  let controls = @views.row(
    [
      traffic_light(rgba8(255, 95, 87), "×", "Close window", CloseWindow),
      traffic_light(
        rgba8(255, 189, 46),
        "−",
        "Minimize window",
        MinimizeWindow,
      ),
      traffic_light(rgba8(40, 200, 64), "+", "Zoom window", ToggleMaximize),
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
    title_label
    .align(alignment=@geometry.Alignment::center())
    .frame(width~, height=40.0),
  ])
  .frame(width~, height=40.0)
  .accessibility_label("Move or zoom " + title + " window")
}

///|
/// The glyph each traffic light reveals on hover, drawn as a low-opacity
/// overlay so it reads as the always-there-but-faint mark seen on macOS when
/// the title bar is not hovered. MoUI does not expose pointer-enter events to
/// app code, so we keep the symbol faintly visible at all times instead of
/// swapping it on hover.
fn traffic_light_glyph(symbol : String) -> @moui.View[Msg] {
  @views.text(
    symbol,
    role=@views.TextRole::Caption,
    width=12.0,
    height=12.0,
    align=@text.TextAlign::TextCenter,
  )
  .font(@text.FontSpec::new(size=8.0, weight=700))
  .foreground(rgba8(0, 0, 0, a=0.42))
}

///|
fn traffic_light(
  color : @graphics.Color,
  symbol : String,
  label : String,
  message : Msg,
) -> @moui.View[Msg] {
  // 12pt traffic light with a darker rim around the whole circle, matching
  // the macOS Big Sur/Sonoma inset appearance. The faint glyph centered in
  // the dot evokes the hover-revealed close/minimize/zoom symbols.
  @views.stack([
    @views.container(
      @views.spacer(min_length=0.0, weight=0.0),
      width=12.0,
      height=12.0,
      background=color,
      corner_radius=6.0,
      border=Some(
        @graphics.BorderStyle::new(
          brush=@graphics.Brush::solid(rgba8(0, 0, 0, a=0.16)),
          width=0.8,
        ),
      ),
      padding=0.0,
    ),
    traffic_light_glyph(symbol)
    .align(alignment=@geometry.Alignment::center())
    .frame(width=12.0, height=12.0),
  ])
  .frame(width=12.0, height=12.0)
  .on_tap(message)
  .accessibility_label(label)
}
