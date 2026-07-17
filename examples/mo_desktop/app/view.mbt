///|
pub fn view(
  model : DesktopModel,
  environment : @moui.ViewEnvironment,
) -> @moui.View[Msg] {
  let viewport = environment.viewport_size()
  let width = viewport.width.max(280.0)
  let height = viewport.height.max(420.0)
  let palette = desktop_palette(model.dark_mode)
  let theme = desktop_theme(model.dark_mode)
  let background_layers : Array[@moui.View[Msg]] = [
    color_layer(
      width,
      height,
      if model.wallpaper_source == "" {
        rgba8(0, 0, 0, a=0.0)
      } else {
        rgba8(10, 72, 96)
      },
    ),
  ]
  if model.wallpaper_source != "" {
    background_layers.push(
      @views.image(
        model.wallpaper_source,
        width~,
        height~,
        fit=@graphics.ImageFit::Cover,
      ),
    )
  }
  background_layers.push(
    color_layer(
      width,
      height,
      if model.phase == Locked {
        rgba8(0, 28, 40, a=0.34)
      } else if model.dark_mode {
        rgba8(0, 8, 18, a=0.22)
      } else {
        rgba8(255, 255, 255, a=0.03)
      },
    ),
  )
  let base = @views.stack(background_layers)
  let content = match model.phase {
    Locked => lock_screen(model, width, height, palette, theme)
    Unlocked => desktop_screen(model, width, height, palette, theme)
  }
  @views.stack([base, content]).frame(width~, height~).theme(theme).clip()
}

///|
fn color_layer(
  width : Double,
  height : Double,
  color : @graphics.Color,
) -> @moui.View[Msg] {
  @views.container(
    @views.spacer(min_length=0.0, weight=0.0),
    width~,
    height~,
    background=color,
    padding=0.0,
  )
}

///|
fn lock_screen(
  _model : DesktopModel,
  width : Double,
  height : Double,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  let compact = width < 620.0
  let clock_size = if compact { 58.0 } else { 88.0 }
  let identity = @views.column(
    [
      @views.container(
        @views.text(
          "M",
          role=@views.TextRole::Display,
          theme~,
          width=72.0,
          height=60.0,
          align=@text.TextAlign::TextCenter,
        )
        .font(@text.FontSpec::new(size=42.0, weight=620))
        .foreground(@graphics.Color::white()),
        width=76.0,
        height=76.0,
        background=palette.accent,
        corner_radius=38.0,
        border=Some(desktop_hairline(palette)),
        padding=6.0,
      ),
      @views.text(
        "mo",
        role=@views.TextRole::Title,
        theme~,
        width=160.0,
        height=26.0,
        align=@text.TextAlign::TextCenter,
      ).foreground(@graphics.Color::white()),
      @views.button(
        "Enter Mo Desktop",
        on_click=UnlockDesktop,
        variant=@views.ButtonVariant::Tonal,
        theme~,
        width=156.0,
        height=36.0,
      ).keyboard_shortcut(@views.KeyboardShortcut::new(key="Enter")),
    ],
    spacing=10.0,
    align=@views.CrossAlign::Center,
  )
  let clock = @views.column(
    [
      @views.text(
        "Friday, July 17",
        role=@views.TextRole::Title,
        theme~,
        width=300.0,
        height=36.0,
        align=@text.TextAlign::TextCenter,
      )
      .font(@text.FontSpec::new(size=22.0, weight=560))
      .foreground(@graphics.Color::white()),
      @views.text(
        "09:41",
        role=@views.TextRole::Display,
        theme~,
        width=420.0,
        height=clock_size + 16.0,
        align=@text.TextAlign::TextCenter,
      )
      .font(@text.FontSpec::new(size=clock_size, weight=220))
      .foreground(@graphics.Color::white()),
    ],
    spacing=0.0,
    align=@views.CrossAlign::Center,
  )
  @views.container(
    @views.column(
      [
        clock,
        @views.spacer(min_length=(height * 0.30).max(84.0), weight=0.0),
        identity,
      ],
      spacing=0.0,
      align=@views.CrossAlign::Center,
    ),
    width~,
    height~,
    background=rgba8(0, 0, 0, a=0.0),
    padding=0.0,
  )
}

///|
fn desktop_screen(
  model : DesktopModel,
  width : Double,
  height : Double,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  let compact = width < 760.0
  let layers : Array[@moui.View[Msg]] = []
  if !compact && !model.window_maximized {
    layers.push(desktop_widgets(model, palette, theme, width, height))
    layers.push(desktop_files(palette, theme, width))
  }
  match model.active_window {
    NoWindow => ()
    Finder => layers.push(finder_window(model, palette, theme, width, height))
    Safari => layers.push(safari_window(model, palette, theme, width, height))
  }
  layers.push(menu_bar(model, palette, theme, width))
  layers.push(dock(model, palette, width, height))
  match model.overlay {
    OverlayNone => ()
    Launcher => layers.push(app_launcher(model, palette, theme, width, height))
    ControlCenter =>
      layers.push(control_center(model, palette, theme, width, height))
    NotificationCenter =>
      layers.push(notification_center(model, palette, theme, width, height))
  }
  @views.stack(layers).frame(width~, height~)
}
