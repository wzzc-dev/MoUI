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
    Boot => boot_screen(model.language, width, height, theme)
    Locked => lock_screen(model, width, height, palette, theme)
    Login => login_screen(model, width, height, palette, theme)
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
  let entry_style = session_entry_style()
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
      // A visible glass button makes the sign-in route discoverable; Enter
      // does the same for keyboard users.
      @views.button(
        model.language.text("lock.sign_in"),
        on_click=ShowLogin,
        variant=@views.ButtonVariant::Ghost,
        theme~,
        style=entry_style,
        width=184.0,
        height=38.0,
      )
      .keyboard_shortcut(@views.KeyboardShortcut::new(key="Enter"))
      .on_tap(ShowLogin),
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
/// Shared frosted-glass button style for the lock/login flow.
fn session_entry_style() -> @views.ButtonStyle {
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
  @views.ButtonStyle::new(
    normal=entry_normal,
    hovered=entry_hovered,
    pressed=entry_pressed,
    disabled=entry_normal,
  )
}

///|
/// Boot splash: logo, product name, and an indeterminate progress strip.
/// Advances automatically via the clock subscription; tapping skips ahead
/// so headless environments (and impatient humans) are never stuck.
fn boot_screen(
  language : AppLanguage,
  width : Double,
  height : Double,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  let t = language
  let logo_size = if width < 620.0 { 64.0 } else { 88.0 }
  let bar_width = if width < 620.0 { 180.0 } else { 240.0 }
  let column = @views.column(
    [
      @views.container(
        @views.text(
          "Mo",
          role=@views.TextRole::Display,
          theme~,
          width=logo_size,
          height=logo_size - 14.0,
          align=@text.TextAlign::TextCenter,
        )
        .font(@text.FontSpec::new(size=logo_size * 0.48, weight=560))
        .foreground(@graphics.Color::white()),
        width=logo_size,
        height=logo_size,
        background=rgba8(52, 148, 246),
        corner_radius=logo_size * 0.5,
        padding=logo_size * 0.08,
      ).shadow(
        @graphics.ShadowStyle::new(
          color=rgba8(0, 0, 0, a=0.3),
          offset=@geometry.Point::new(x=0.0, y=6.0),
          blur_radius=18.0,
          spread=0.0,
        ),
      ),
      @views.text(
        t.text("boot.title"),
        role=@views.TextRole::Title,
        theme~,
        width=280.0,
        height=30.0,
        align=@text.TextAlign::TextCenter,
      )
      .font(@text.FontSpec::new(size=17.0, weight=500))
      .foreground(@graphics.Color::white()),
      @views.stack([
        @views.container(
          @views.spacer(min_length=0.0, weight=0.0),
          width=bar_width,
          height=6.0,
          background=rgba8(255, 255, 255, a=0.18),
          corner_radius=3.0,
          padding=0.0,
        ),
        @views.container(
          @views.spacer(min_length=0.0, weight=0.0),
          width=bar_width * 0.62,
          height=6.0,
          background=rgba8(52, 148, 246),
          corner_radius=3.0,
          padding=0.0,
        ).align(alignment=@geometry.Alignment::top_leading()),
      ])
      .frame(width=bar_width, height=6.0)
      .accessibility_label("Boot progress"),
      @views.text(
        t.text("boot.skip"),
        role=@views.TextRole::Caption,
        theme~,
        width=220.0,
        height=20.0,
        align=@text.TextAlign::TextCenter,
      ).foreground(rgba8(255, 255, 255, a=0.72)),
    ],
    spacing=14.0,
    align=@views.CrossAlign::Center,
  )
  @views.container(
    column.align(alignment=@geometry.Alignment::center()).frame(width~, height~),
    width~,
    height~,
    background=rgba8(0, 0, 0, a=0.0),
    padding=0.0,
  )
  .on_tap(AdvanceBoot)
  .accessibility_label("Boot screen")
}

///|
/// Login screen: same avatar identity as the lock screen plus a password
/// field. The demo account accepts anything, mirroring a real login form.
fn login_screen(
  model : DesktopModel,
  width : Double,
  height : Double,
  _palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  let compact = width < 620.0
  let avatar_size = if compact { 68.0 } else { 78.0 }
  let field_width = if compact { 220.0 } else { 260.0 }
  let entry_style = session_entry_style()
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
      @views.text_field(
        model.login_password,
        on_input=value => LoginPasswordChanged(value),
        on_submit=Some(SubmitLogin(model.login_password)),
        placeholder=model.language.text("login.password"),
        variant=@views.TextFieldVariant::Outline,
        theme~,
        width=field_width,
        height=38.0,
      ).accessibility_label("Login password"),
      @views.button(
        model.language.text("login.unlock"),
        on_click=SubmitLogin(model.login_password),
        variant=@views.ButtonVariant::Ghost,
        theme~,
        style=entry_style,
        width=field_width,
        height=38.0,
      ).keyboard_shortcut(@views.KeyboardShortcut::new(key="Enter")),
      @views.text(
        model.language.text("login.hint"),
        role=@views.TextRole::Caption,
        theme~,
        width=240.0,
        height=18.0,
        align=@text.TextAlign::TextCenter,
      ).foreground(rgba8(255, 255, 255, a=0.72)),
    ],
    spacing=10.0,
    align=@views.CrossAlign::Center,
  )
  identity
  .align(alignment=@geometry.Alignment::top_leading())
  .offset(dx=(width - field_width) / 2.0, dy=height * 0.34)
  .frame(width~, height~)
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
  // Desktop widgets hide while the key window is zoomed, matching macOS
  // where a maximized window takes over the desktop.
  let desktop_cleared = match model.focused_window() {
    Some(record) => record.state == MaximizedWindow
    None => false
  }
  let layers : Array[@moui.View[Msg]] = []
  // `stack` paints and hit-tests later children on top. Keep desktop content
  // beneath windows and chrome, then put transient overlays above everything.
  // Windows paint in z-order so the focused (highest z) window is last.
  if !compact && !desktop_cleared {
    layers.push(desktop_widgets(model, palette, theme, width, height))
    layers.push(desktop_files(model, palette, theme, width))
  }
  for record in model.visible_windows() {
    layers.push(
      app_window(
        model,
        record,
        window_body(model, record, width, height, palette, theme),
        palette,
        theme,
        width,
        height,
      ),
    )
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

///|
/// Build the content column for one window. Each app keeps its own typed
/// body builder; the shared shell (titlebar, shadow, grip) lives in
/// `app_window` so every window behaves identically.
fn window_body(
  model : DesktopModel,
  record : WindowRecord,
  viewport_width : Double,
  viewport_height : Double,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  match record.id.app {
    FinderApp =>
      finder_body(
        model,
        window_metrics(record, viewport_width, viewport_height),
        palette,
        theme,
      )
    SafariApp =>
      safari_body(
        model,
        window_metrics(record, viewport_width, viewport_height),
        palette,
        theme,
      )
    NotesApp =>
      notes_body(
        model,
        window_metrics(record, viewport_width, viewport_height),
        palette,
        theme,
      )
    TerminalApp =>
      terminal_body(
        model,
        window_metrics(record, viewport_width, viewport_height),
        palette,
        theme,
      )
  }
}
