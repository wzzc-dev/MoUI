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
        // Deeper cool wash so the lock screen reads like a blurred login field.
        rgba8(4, 30, 48, a=0.46)
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
  model : DesktopModel,
  width : Double,
  height : Double,
  _palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  // macOS login: large thin clock high on the field, single avatar user below.
  // Keep the "Enter Mo Desktop" label for runtime unlock tests and keyboard.
  let compact = width < 620.0
  let clock_size = if compact { 64.0 } else { 96.0 }
  let avatar_size = if compact { 68.0 } else { 78.0 }
  let clock = @views.column(
    [
      @views.text(
        desktop_clock_lock_date(model.clock),
        role=@views.TextRole::Title,
        theme~,
        width=320.0,
        height=30.0,
        align=@text.TextAlign::TextCenter,
      )
      .font(
        @text.FontSpec::new(size=if compact { 18.0 } else { 22.0 }, weight=500),
      )
      .foreground(@graphics.Color::white()),
      @views.text(
        desktop_clock_time(model.clock),
        role=@views.TextRole::Display,
        theme~,
        width=460.0,
        height=clock_size + 10.0,
        align=@text.TextAlign::TextCenter,
      )
      .font(@text.FontSpec::new(size=clock_size, weight=180))
      .foreground(@graphics.Color::white()),
    ],
    spacing=2.0,
    align=@views.CrossAlign::Center,
  )
  let avatar = @views.container(
    @views.text(
      "M",
      role=@views.TextRole::Display,
      theme~,
      width=avatar_size - 8.0,
      height=avatar_size - 14.0,
      align=@text.TextAlign::TextCenter,
    )
    .font(@text.FontSpec::new(size=avatar_size * 0.48, weight=560))
    .foreground(@graphics.Color::white()),
    width=avatar_size,
    height=avatar_size,
    background=rgba8(52, 148, 246),
    corner_radius=avatar_size * 0.5,
    border=Some(
      @graphics.BorderStyle::new(
        brush=@graphics.Brush::solid(rgba8(255, 255, 255, a=0.35)),
        width=1.0,
      ),
    ),
    padding=avatar_size * 0.08,
  ).shadow(
    @graphics.ShadowStyle::new(
      color=rgba8(0, 0, 0, a=0.28),
      offset=@geometry.Point::new(x=0.0, y=6.0),
      blur_radius=16.0,
      spread=0.0,
    ),
  )
  let entry_border = @graphics.BorderStyle::new(
    brush=@graphics.Brush::solid(rgba8(255, 255, 255, a=0.46)),
    width=1.0,
  )
  let entry_normal = @views.new_control_state_style(
    foreground=rgba8(255, 255, 255, a=0.96),
    background=@graphics.Brush::solid(rgba8(255, 255, 255, a=0.16)),
    border=entry_border,
    radius=14.0,
    shadow=@graphics.ShadowStyle::new(
      color=rgba8(0, 0, 0, a=0.22),
      offset=@geometry.Point::new(x=0.0, y=4.0),
      blur_radius=10.0,
      spread=0.0,
    ),
  )
  let entry_hovered = @views.new_control_state_style(
    foreground=rgba8(255, 255, 255, a=1.0),
    background=@graphics.Brush::solid(rgba8(255, 255, 255, a=0.28)),
    border=@graphics.BorderStyle::new(
      brush=@graphics.Brush::solid(rgba8(255, 255, 255, a=0.66)),
      width=1.0,
    ),
    radius=14.0,
    shadow=@graphics.ShadowStyle::new(
      color=rgba8(0, 0, 0, a=0.28),
      offset=@geometry.Point::new(x=0.0, y=5.0),
      blur_radius=12.0,
      spread=0.0,
    ),
  )
  let entry_pressed = @views.new_control_state_style(
    foreground=rgba8(255, 255, 255, a=1.0),
    background=@graphics.Brush::solid(rgba8(255, 255, 255, a=0.36)),
    border=entry_border,
    radius=14.0,
  )
  let entry_style = @views.ButtonStyle::new(
    normal=entry_normal,
    hovered=entry_hovered,
    pressed=entry_pressed,
    disabled=entry_normal,
  )
  let identity = @views.column(
    [
      avatar,
      @views.text(
        "mo",
        role=@views.TextRole::Title,
        theme~,
        width=160.0,
        height=24.0,
        align=@text.TextAlign::TextCenter,
      )
      .font(@text.FontSpec::new(size=16.0, weight=500))
      .foreground(@graphics.Color::white()),
      // A visible glass button makes the unlock route immediately discoverable.
      @views.button(
        "Enter Mo Desktop",
        on_click=UnlockDesktop,
        variant=@views.ButtonVariant::Ghost,
        theme~,
        style=entry_style,
        width=184.0,
        height=38.0,
      )
      .keyboard_shortcut(@views.KeyboardShortcut::new(key="Enter"))
      .on_tap(UnlockDesktop),
    ],
    spacing=8.0,
    align=@views.CrossAlign::Center,
  )
  // Stack clock near the top third and identity near the lower third.
  @views.stack([
    clock
    .align(alignment=@geometry.Alignment::top_leading())
    .offset(dx=(width - 460.0) / 2.0, dy=height * 0.16)
    .frame(width~, height~),
    identity
    .align(alignment=@geometry.Alignment::top_leading())
    .offset(dx=(width - 184.0) / 2.0, dy=height * 0.62)
    .frame(width~, height~),
  ]).frame(width~, height~)
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
  // `stack` paints and hit-tests later children on top. Keep desktop content
  // beneath windows and chrome, then put transient overlays above everything.
  if !compact && !model.window_maximized {
    layers.push(desktop_widgets(model, palette, theme, width, height))
    layers.push(desktop_files(palette, theme, width))
  }
  match model.active_window {
    NoWindow => ()
    Finder => layers.push(finder_window(model, palette, theme, width, height))
    Safari => layers.push(safari_window(model, palette, theme, width, height))
  }
  layers.push(dock(model, palette, width, height))
  layers.push(menu_bar(model, palette, theme, width))
  match model.overlay {
    OverlayNone => ()
    MenuBarMenu(menu) =>
      layers.push(menu_bar_popup(model, menu, palette, theme, width, height))
    Launcher => layers.push(app_launcher(model, palette, theme, width, height))
    Spotlight => layers.push(spotlight(model, palette, theme, width, height))
    ControlCenter =>
      layers.push(control_center(model, palette, theme, width, height))
    NotificationCenter =>
      layers.push(notification_center(model, palette, theme, width, height))
    AboutThisMac => layers.push(about_this_mac(palette, theme, width, height))
    SystemSettings =>
      layers.push(system_settings(model, palette, theme, width, height))
    AppStore => layers.push(app_store(palette, theme, width, height))
  }
  @views.stack(layers).frame(width~, height~)
}
