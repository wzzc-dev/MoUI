///|
priv struct LauncherEntry {
  label : String
  detail : String
  icon : @views.IconName
  color : @graphics.Color
  message : Msg
}

///|
fn app_launcher(
  model : DesktopModel,
  palette : DesktopPalette,
  theme : @moui.Theme,
  viewport_width : Double,
  viewport_height : Double,
) -> @moui.View[Msg] {
  let compact = viewport_width < 620.0
  let width = if compact {
    (viewport_width - 20.0).max(272.0)
  } else {
    (viewport_width - 120.0).min(760.0)
  }
  let height = if compact {
    (viewport_height - 112.0).max(360.0)
  } else {
    (viewport_height - 170.0).min(500.0).max(410.0)
  }
  let inner_width = width - 32.0
  let entries = launcher_entries(model).filter(entry => {
    model.launcher_query == "" ||
    entry.label.contains(model.launcher_query) ||
    entry.detail.contains(model.launcher_query)
  })
  let results = if entries.is_empty() {
    @views.column(
      [
        @views.text(
          "No apps or actions found",
          role=@views.TextRole::Title,
          theme~,
          width=inner_width,
          height=34.0,
          align=@text.TextAlign::TextCenter,
        ).foreground(palette.foreground),
        @views.button(
          "Clear Search",
          on_click=LauncherQueryChanged(""),
          variant=@views.ButtonVariant::Tonal,
          theme~,
          width=126.0,
          height=38.0,
        ),
      ],
      spacing=12.0,
      align=@views.CrossAlign::Center,
    )
  } else {
    @views.responsive_grid(
      entries.map(entry => {
        launcher_tile(
          entry,
          if compact {
            112.0
          } else {
            142.0
          },
          palette,
          theme,
        )
      }),
      width=inner_width,
      min_column_width=if compact { 112.0 } else { 142.0 },
      row_spacing=16.0,
      column_spacing=16.0,
    )
  }
  let panel = glass_panel(
    @views.column(
      [
        overlay_header("Apps", DismissOverlay, inner_width, palette, theme),
        @views.text_field(
          model.launcher_query,
          on_input=value => LauncherQueryChanged(value),
          placeholder="Search apps and actions",
          theme~,
          width=inner_width,
          height=40.0,
        ),
        @views.segmented_control(
          [
            @views.choice_item("apps", "Apps"),
            @views.choice_item("actions", "Actions"),
          ],
          selected=model.launcher_tab.id(),
          on_select=value => {
            LauncherTabSelected(if value == "actions" { Actions } else { Apps })
          },
          theme~,
          width=inner_width,
        ),
        results,
      ],
      spacing=14.0,
      align=@views.CrossAlign::Stretch,
    ),
    width,
    height,
    palette,
    radius=20.0,
    padding=16.0,
  )
  @views.stack([
    color_layer(viewport_width, viewport_height, palette.scrim).on_tap(
      DismissOverlay,
    ),
    panel
    .align(alignment=@geometry.Alignment::center())
    .offset(dy=-8.0)
    .frame(width=viewport_width, height=viewport_height),
  ])
}

///|
fn spotlight(
  model : DesktopModel,
  palette : DesktopPalette,
  theme : @moui.Theme,
  viewport_width : Double,
  viewport_height : Double,
) -> @moui.View[Msg] {
  // macOS Spotlight: a compact centered capsule with a leading search glyph,
  // a live result list below, and a click-away scrim for dismissal.
  let compact = viewport_width < 620.0
  let width = if compact {
    (viewport_width - 20.0).max(272.0)
  } else {
    520.0.min(viewport_width - 40.0)
  }
  let inner_width = width - 32.0
  let query = model.spotlight_query
  let results = spotlight_results(model, query, inner_width, palette, theme)
  let panel = glass_panel(
    @views.column(
      [
        @views.row(
          [
            desktop_icon(@views.IconName::Search, 18.0, palette.muted),
            @views.text_field(
              query,
              on_input=value => SpotlightQueryChanged(value),
              on_submit=Some(SpotlightQueryChanged(query)),
              placeholder="Spotlight Search",
              theme~,
              width=inner_width - 28.0,
              height=40.0,
            ),
          ],
          spacing=10.0,
          align=@views.CrossAlign::Center,
        ),
        @views.divider(theme~, color=palette.outline.multiply_alpha(0.55)),
        results,
      ],
      spacing=12.0,
      align=@views.CrossAlign::Stretch,
    ),
    width,
    360.0,
    palette,
    radius=20.0,
    padding=16.0,
  )
  @views.stack([
    color_layer(viewport_width, viewport_height, palette.scrim).on_tap(
      DismissOverlay,
    ),
    panel
    .align(alignment=@geometry.Alignment::center())
    .offset(dy=if compact { 0.0 } else { -40.0 })
    .frame(width=viewport_width, height=viewport_height),
  ])
}

///|
/// Spotlight aggregates apps, files, and a few quick actions into one ranked
/// result list. The list is intentionally short — real Spotlight keeps the
/// top hits glanceable rather than dumping every match.
priv struct SpotlightResult {
  title : String
  subtitle : String
  category : String
  icon : @views.IconName
  color : @graphics.Color
  message : Msg
}

///|
fn spotlight_results(
  _model : DesktopModel,
  query : String,
  width : Double,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  let entries = spotlight_entries().filter(entry => {
    query == "" || entry.title.contains(query) || entry.subtitle.contains(query)
  })
  if entries.is_empty() {
    @views.column(
      [
        @views.text(
          "No results for \"\{query}\"",
          role=@views.TextRole::Body,
          theme~,
          width~,
          height=28.0,
          align=@text.TextAlign::TextCenter,
        ).foreground(palette.muted),
      ],
      spacing=0.0,
      align=@views.CrossAlign::Center,
    )
  } else {
    // Group hits by category in Spotlight's canonical order, then render each
    // group with a small grey header like real Spotlight (Applications /
    // Folders / System).
    let categories = ["Applications", "Folders", "System"]
    let children : Array[@moui.View[Msg]] = []
    for category in categories {
      let group = entries.filter(entry => entry.category == category)
      if !group.is_empty() {
        children.push(
          spotlight_category_header(category, width, palette, theme),
        )
        for entry in group {
          children.push(spotlight_row(entry, width, palette, theme))
        }
      }
    }
    @views.column(children, spacing=2.0, align=@views.CrossAlign::Stretch)
  }
}

///|
/// A small grey uppercase-style category label that introduces a Spotlight
/// result group. Lower weight than the result rows beneath it.
fn spotlight_category_header(
  category : String,
  width : Double,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  @views.text(
    category,
    role=@views.TextRole::Caption,
    theme~,
    width~,
    height=16.0,
  )
  .font(@text.FontSpec::new(size=11.0, weight=700))
  .foreground(palette.muted)
}

///|
fn spotlight_entries() -> Array[SpotlightResult] {
  let entries : Array[SpotlightResult] = []
  for descriptor in app_registry() {
    entries.push({
      title: descriptor.label,
      subtitle: "Application",
      category: "Applications",
      icon: descriptor.icon,
      color: descriptor.color,
      message: LaunchApp(descriptor.id),
    })
  }
  let rest : Array[SpotlightResult] = [
    {
      title: "System Settings",
      subtitle: "Application",
      category: "Applications",
      icon: @views.IconName::Settings,
      color: rgba8(104, 112, 124),
      message: RunMenuCommand(ShowSystemSettings),
    },
    {
      title: "Documents",
      subtitle: "Folder",
      category: "Folders",
      icon: @views.IconName::FileNew,
      color: rgba8(91, 143, 249),
      message: RunMenuCommand(OpenDocuments),
    },
    {
      title: "Downloads",
      subtitle: "Folder",
      category: "Folders",
      icon: @views.IconName::ArrowRight,
      color: rgba8(38, 175, 129),
      message: RunMenuCommand(OpenDownloads),
    },
    {
      title: "About This Mac",
      subtitle: "System",
      category: "System",
      icon: @views.IconName::Info,
      color: rgba8(48, 132, 255),
      message: RunMenuCommand(ShowAboutThisMac),
    },
    {
      title: "Lock Screen",
      subtitle: "Session",
      category: "System",
      icon: @views.IconName::Focus,
      color: rgba8(45, 166, 153),
      message: RunMenuCommand(LockSession),
    },
  ]
  for entry in rest {
    entries.push(entry)
  }
  entries
}

///|
fn spotlight_row(
  entry : SpotlightResult,
  width : Double,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  @views.container(
    @views.row(
      [
        @views.container(
          desktop_icon(entry.icon, 16.0, @graphics.Color::white()),
          width=28.0,
          height=28.0,
          background=entry.color,
          corner_radius=7.0,
          padding=6.0,
        ),
        @views.column(
          [
            @views.text(
              entry.title,
              role=@views.TextRole::Body,
              theme~,
              width=(width - 56.0).max(80.0),
              height=20.0,
            )
            .font(@text.FontSpec::new(size=13.0, weight=560))
            .foreground(palette.foreground),
            @views.text(
              entry.subtitle,
              role=@views.TextRole::Caption,
              theme~,
              width=(width - 56.0).max(80.0),
              height=16.0,
            ).foreground(palette.muted),
          ],
          spacing=1.0,
          align=@views.CrossAlign::Start,
        ),
      ],
      spacing=10.0,
      align=@views.CrossAlign::Center,
    ),
    width~,
    height=44.0,
    corner_radius=8.0,
    padding=6.0,
  )
  .on_tap(entry.message)
  .accessibility_label(entry.title)
}

///|
fn about_this_mac(
  palette : DesktopPalette,
  theme : @moui.Theme,
  viewport_width : Double,
  viewport_height : Double,
) -> @moui.View[Msg] {
  desktop_dialog(
    "About This Mac",
    "Mo Desktop",
    "Version 1.0 · MoonBit UI demo",
    @views.IconName::Info,
    rgba8(48, 132, 255),
    palette,
    theme,
    viewport_width,
    viewport_height,
  )
}

///|
fn app_store(
  palette : DesktopPalette,
  theme : @moui.Theme,
  viewport_width : Double,
  viewport_height : Double,
) -> @moui.View[Msg] {
  desktop_dialog(
    "App Store",
    "Discover apps for Mo Desktop",
    "The demo catalog is ready for you to explore.",
    @views.IconName::Link,
    rgba8(40, 172, 224),
    palette,
    theme,
    viewport_width,
    viewport_height,
  )
}

///|
fn system_settings(
  model : DesktopModel,
  palette : DesktopPalette,
  theme : @moui.Theme,
  viewport_width : Double,
  viewport_height : Double,
) -> @moui.View[Msg] {
  let width = (viewport_width - 32.0).min(420.0).max(272.0)
  let panel = glass_panel(
    @views.column(
      [
        overlay_header(
          "System Settings",
          DismissOverlay,
          width - 32.0,
          palette,
          theme,
        ),
        @views.text(
          "Appearance",
          role=@views.TextRole::Title,
          theme~,
          width=width - 32.0,
          height=28.0,
        )
        .font(@text.FontSpec::new(size=17.0, weight=620))
        .foreground(palette.foreground),
        @views.text(
          if model.dark_mode {
            "Dark appearance is active."
          } else {
            "Light appearance is active."
          },
          role=@views.TextRole::Body,
          theme~,
          width=width - 32.0,
          height=22.0,
        ).foreground(palette.muted),
        @views.button(
          if model.dark_mode {
            "Use Light Appearance"
          } else {
            "Use Dark Appearance"
          },
          on_click=ToggleDarkMode,
          variant=@views.ButtonVariant::Tonal,
          theme~,
          width=width - 32.0,
          height=38.0,
        ),
        @views.button(
          "Use System Appearance",
          on_click=UseSystemAppearance,
          variant=@views.ButtonVariant::Ghost,
          theme~,
          width=width - 32.0,
          height=34.0,
        ),
      ],
      spacing=12.0,
      align=@views.CrossAlign::Stretch,
    ),
    width,
    242.0,
    palette,
    radius=18.0,
    padding=16.0,
  )
  desktop_modal(panel, viewport_width, viewport_height)
}

///|
fn desktop_dialog(
  title : String,
  heading : String,
  detail : String,
  icon : @views.IconName,
  icon_color : @graphics.Color,
  palette : DesktopPalette,
  theme : @moui.Theme,
  viewport_width : Double,
  viewport_height : Double,
) -> @moui.View[Msg] {
  let width = (viewport_width - 32.0).min(420.0).max(272.0)
  let panel = glass_panel(
    @views.column(
      [
        overlay_header(title, DismissOverlay, width - 32.0, palette, theme),
        @views.container(
          desktop_icon(icon, 30.0, @graphics.Color::white()),
          width=56.0,
          height=56.0,
          background=icon_color,
          corner_radius=14.0,
          padding=13.0,
        ),
        @views.text(
          heading,
          role=@views.TextRole::Title,
          theme~,
          width=width - 32.0,
          height=28.0,
          align=@text.TextAlign::TextCenter,
        )
        .font(@text.FontSpec::new(size=18.0, weight=650))
        .foreground(palette.foreground),
        @views.text(
          detail,
          role=@views.TextRole::Body,
          theme~,
          width=width - 32.0,
          height=40.0,
          align=@text.TextAlign::TextCenter,
        ).foreground(palette.muted),
      ],
      spacing=10.0,
      align=@views.CrossAlign::Center,
    ),
    width,
    230.0,
    palette,
    radius=18.0,
    padding=16.0,
  )
  desktop_modal(panel, viewport_width, viewport_height)
}

///|
fn desktop_modal(
  panel : @moui.View[Msg],
  viewport_width : Double,
  viewport_height : Double,
) -> @moui.View[Msg] {
  @views.stack([
    color_layer(viewport_width, viewport_height, rgba8(0, 0, 0, a=0.24)).on_tap(
      DismissOverlay,
    ),
    panel
    .align(alignment=@geometry.Alignment::center())
    .frame(width=viewport_width, height=viewport_height),
  ])
}

///|
fn launcher_entries(model : DesktopModel) -> Array[LauncherEntry] {
  if model.launcher_tab == Actions {
    [
      {
        label: if model.dark_mode {
          "Light Mode"
        } else {
          "Dark Mode"
        },
        detail: "Appearance",
        icon: @views.IconName::Eye,
        color: rgba8(104, 87, 214),
        message: ToggleDarkMode,
      },
      {
        label: "Lock Screen",
        detail: "Secure this session",
        icon: @views.IconName::Focus,
        color: rgba8(45, 166, 153),
        message: LockDesktop,
      },
      {
        label: "Close Window",
        detail: "Return to desktop",
        icon: @views.IconName::Close,
        color: rgba8(238, 82, 83),
        message: CloseWindow,
      },
      {
        label: "Mark Read",
        detail: "Clear inbox badge",
        icon: @views.IconName::Check,
        color: rgba8(244, 137, 53),
        message: MarkNotificationsRead,
      },
    ]
  } else {
    // Registry-driven app tiles plus the two shell shortcuts.
    let entries : Array[LauncherEntry] = []
    for descriptor in app_registry() {
      entries.push({
        label: descriptor.label,
        detail: descriptor.detail,
        icon: descriptor.icon,
        color: descriptor.color,
        message: LaunchApp(descriptor.id),
      })
    }
    entries.push({
      label: "Control Center",
      detail: "Display and sound",
      icon: @views.IconName::Settings,
      color: rgba8(91, 99, 112),
      message: ToggleControlCenter,
    })
    entries.push({
      label: "Notifications",
      detail: "Messages and tasks",
      icon: @views.IconName::Info,
      color: rgba8(236, 72, 118),
      message: ToggleNotificationCenter,
    })
    entries
  }
}

///|
fn launcher_tile(
  entry : LauncherEntry,
  width : Double,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  @views.container(
    @views.column(
      [
        @views.container(
          desktop_icon(entry.icon, 30.0, @graphics.Color::white()),
          width=64.0,
          height=64.0,
          background=entry.color,
          corner_radius=15.0,
          border=Some(desktop_hairline(palette)),
          padding=16.0,
        ),
        @views.text(
          entry.label,
          role=@views.TextRole::Label,
          theme~,
          width=width - 12.0,
          height=24.0,
          align=@text.TextAlign::TextCenter,
        ).foreground(palette.foreground),
        @views.text(
          entry.detail,
          role=@views.TextRole::Caption,
          theme~,
          width=width - 12.0,
          height=20.0,
          align=@text.TextAlign::TextCenter,
        ).foreground(palette.muted),
      ],
      spacing=5.0,
      align=@views.CrossAlign::Center,
    ),
    width~,
    height=132.0,
    background=palette.glass_strong,
    corner_radius=14.0,
    border=Some(desktop_hairline(palette)),
    padding=10.0,
  )
  .on_tap(entry.message)
  .accessibility_label(entry.label)
}

///|
fn control_center(
  model : DesktopModel,
  palette : DesktopPalette,
  theme : @moui.Theme,
  viewport_width : Double,
  viewport_height : Double,
) -> @moui.View[Msg] {
  // macOS Control Center is a compact frosted stack of nested cards under the
  // menu-bar status cluster — not a titled settings form with full-width CTAs.
  let compact = viewport_width < 520.0
  let width = if compact { (viewport_width - 20.0).max(272.0) } else { 320.0 }
  let available_height = (viewport_height - 48.0).max(300.0)
  let height = if compact {
    available_height.min(520.0)
  } else {
    470.0.min(available_height)
  }
  let inner_width = width - 24.0
  let tile_w = (inner_width - 8.0) / 2.0
  let connectivity_height = if compact { 136.0 } else { 64.0 }
  let connectivity_content = if compact {
    @views.column(
      [
        connectivity_tile(
          "Wi-Fi",
          "Connected",
          @views.IconName::Link,
          model.wifi_enabled,
          WifiChanged(!model.wifi_enabled),
          inner_width,
          palette,
          theme,
        ),
        connectivity_tile(
          "Bluetooth",
          "On",
          @views.IconName::Focus,
          model.bluetooth_enabled,
          BluetoothChanged(!model.bluetooth_enabled),
          inner_width,
          palette,
          theme,
        ),
      ],
      spacing=8.0,
      align=@views.CrossAlign::Stretch,
    )
  } else {
    @views.row(
      [
        connectivity_tile(
          "Wi-Fi",
          "Connected",
          @views.IconName::Link,
          model.wifi_enabled,
          WifiChanged(!model.wifi_enabled),
          tile_w,
          palette,
          theme,
        ),
        connectivity_tile(
          "Bluetooth",
          "On",
          @views.IconName::Focus,
          model.bluetooth_enabled,
          BluetoothChanged(!model.bluetooth_enabled),
          tile_w,
          palette,
          theme,
        ),
      ],
      spacing=8.0,
      align=@views.CrossAlign::Stretch,
    )
  }
  let connectivity = overlay_group(
    connectivity_content,
    inner_width,
    connectivity_height,
    palette,
    padding=0.0,
  )
  let appearance = overlay_group(
    @views.row(
      [
        control_action_tile(
          if model.dark_mode {
            "Light Mode"
          } else {
            "Dark Mode"
          },
          @views.IconName::Eye,
          model.dark_mode,
          ToggleDarkMode,
          tile_w,
          palette,
          theme,
        ),
        control_action_tile(
          "Low Power",
          @views.IconName::Settings,
          model.low_power_mode,
          LowPowerModeChanged(!model.low_power_mode),
          tile_w,
          palette,
          theme,
        ),
      ],
      spacing=8.0,
      align=@views.CrossAlign::Stretch,
    ),
    inner_width,
    78.0,
    palette,
    padding=0.0,
  )
  let body = @views.column(
    [
      connectivity,
      control_slider_section(
        "Display",
        model.brightness,
        value => BrightnessChanged(value),
        inner_width,
        palette,
        theme,
      ),
      appearance,
      control_slider_section(
        "Sound",
        model.volume,
        value => VolumeChanged(value),
        inner_width,
        palette,
        theme,
      ),
      control_system_status(model, inner_width, palette, theme),
      @views.container(
        @views.text(
          "Lock Screen",
          role=@views.TextRole::Caption,
          theme~,
          width=inner_width - 16.0,
          height=18.0,
          align=@text.TextAlign::TextCenter,
        ).foreground(palette.muted),
        width=inner_width,
        height=28.0,
        background=rgba8(0, 0, 0, a=0.0),
        padding=4.0,
      )
      .on_tap(LockDesktop)
      .accessibility_label("Lock Screen"),
    ],
    spacing=10.0,
    align=@views.CrossAlign::Stretch,
  )
  let panel = @views.container(
    @views.scroll_view(
      body,
      width=inner_width,
      height=height - 24.0,
      shows_indicator=true,
    ),
    width~,
    height~,
    background=overlay_panel_background(palette),
    corner_radius=22.0,
    border=Some(desktop_hairline(palette)),
    padding=12.0,
  ).shadow(
    @graphics.ShadowStyle::new(
      color=rgba8(0, 0, 0, a=0.28),
      offset=@geometry.Point::new(x=0.0, y=16.0),
      blur_radius=36.0,
      spread=0.0,
    ),
  )
  let aligned = if compact {
    panel
    .align(alignment=@geometry.Alignment::top_leading())
    .offset(dx=10.0, dy=38.0)
  } else {
    panel
    .align(alignment=@geometry.Alignment::top_trailing())
    .offset(dx=-14.0, dy=38.0)
  }
  @views.stack([
    color_layer(viewport_width, viewport_height, rgba8(0, 0, 0, a=0.0)).on_tap(
      DismissOverlay,
    ),
    aligned.frame(width=viewport_width, height=viewport_height),
  ])
}

///|
fn overlay_group(
  child : @moui.View[Msg],
  width : Double,
  height : Double,
  palette : DesktopPalette,
  padding? : Double = 8.0,
) -> @moui.View[Msg] {
  @views.container(
    child,
    width~,
    height~,
    background=overlay_group_background(palette),
    corner_radius=18.0,
    padding~,
  )
}

///|
fn control_card_background(palette : DesktopPalette) -> @graphics.Color {
  overlay_card_background(palette)
}

///|
fn connectivity_tile(
  label : String,
  detail : String,
  icon : @views.IconName,
  enabled : Bool,
  message : Msg,
  width : Double,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  let glyph_bg = if enabled { palette.accent } else { rgba8(150, 158, 170) }
  @views.container(
    @views.row(
      [
        @views.container(
          desktop_icon(icon, 16.0, @graphics.Color::white()),
          width=34.0,
          height=34.0,
          background=glyph_bg,
          corner_radius=17.0,
          padding=9.0,
        ),
        @views.column(
          [
            @views.text(
              label,
              role=@views.TextRole::Label,
              theme~,
              width=(width - 58.0).max(70.0),
              height=18.0,
            )
            .font(@text.FontSpec::new(size=13.0, weight=600))
            .foreground(palette.foreground),
            @views.text(
              if enabled {
                detail
              } else {
                "Off"
              },
              role=@views.TextRole::Caption,
              theme~,
              width=(width - 58.0).max(70.0),
              height=16.0,
            ).foreground(palette.muted),
          ],
          spacing=1.0,
          align=@views.CrossAlign::Start,
        ),
      ],
      spacing=10.0,
      align=@views.CrossAlign::Center,
    ),
    width~,
    height=64.0,
    background=control_card_background(palette),
    corner_radius=16.0,
    border=Some(overlay_card_outline(palette)),
    padding=12.0,
  )
  .on_tap(message)
  .accessibility_label(label)
}

///|
fn control_action_tile(
  label : String,
  icon : @views.IconName,
  active : Bool,
  message : Msg,
  width : Double,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  @views.container(
    @views.column(
      [
        @views.container(
          desktop_icon(
            icon,
            15.0,
            if active {
              @graphics.Color::white()
            } else {
              palette.foreground
            },
          ),
          width=30.0,
          height=30.0,
          background=if active {
            palette.accent
          } else {
            overlay_neutral_icon_background(palette)
          },
          corner_radius=15.0,
          padding=7.0,
        ),
        @views.text(
          label,
          role=@views.TextRole::Caption,
          theme~,
          width=width - 20.0,
          height=18.0,
          align=@text.TextAlign::TextCenter,
        )
        .font(@text.FontSpec::new(size=12.0, weight=560))
        .foreground(palette.foreground),
      ],
      spacing=8.0,
      align=@views.CrossAlign::Center,
    ),
    width~,
    height=78.0,
    background=control_card_background(palette),
    corner_radius=16.0,
    border=Some(overlay_card_outline(palette)),
    padding=12.0,
  )
  .on_tap(message)
  .accessibility_label(label)
}

///|
fn control_system_status(
  model : DesktopModel,
  width : Double,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  @views.container(
    @views.row(
      [
        @views.container(
          @views.text(
            desktop_clock_time(model.clock),
            role=@views.TextRole::Caption,
            theme~,
            width=50.0,
            height=16.0,
            align=@text.TextAlign::TextCenter,
          )
          .font(@text.FontSpec::new(size=10.0, weight=700))
          .foreground(palette.foreground),
          width=58.0,
          height=40.0,
          background=palette.accent_soft,
          corner_radius=20.0,
          border=Some(
            @graphics.BorderStyle::new(
              brush=@graphics.Brush::solid(palette.accent.multiply_alpha(0.70)),
              width=2.0,
            ),
          ),
          padding=10.0,
        ),
        @views.column(
          [
            @views.text(
              "System status",
              role=@views.TextRole::Label,
              theme~,
              width=(width - 88.0).max(100.0),
              height=18.0,
            )
            .font(@text.FontSpec::new(size=13.0, weight=600))
            .foreground(palette.foreground),
            @views.text(
              if model.appearance == SystemAppearance {
                "Following system appearance"
              } else if model.dark_mode {
                "Manual dark appearance"
              } else {
                "Manual light appearance"
              },
              role=@views.TextRole::Caption,
              theme~,
              width=(width - 88.0).max(100.0),
              height=16.0,
            ).foreground(palette.muted),
          ],
          spacing=1.0,
          align=@views.CrossAlign::Start,
        ),
      ],
      spacing=12.0,
      align=@views.CrossAlign::Center,
    ),
    width~,
    height=68.0,
    background=control_card_background(palette),
    corner_radius=16.0,
    border=Some(overlay_card_outline(palette)),
    padding=12.0,
  )
}

///|
fn control_slider_section(
  label : String,
  value : Double,
  on_change : (Double) -> Msg,
  width : Double,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  @views.container(
    @views.column(
      [
        @views.row(
          [
            @views.text(
              label,
              role=@views.TextRole::Label,
              theme~,
              width=width - 86.0,
              height=20.0,
            )
            .font(@text.FontSpec::new(size=12.5, weight=600))
            .foreground(palette.foreground),
            @views.text(
              "\{(value * 100.0).to_int()}%",
              role=@views.TextRole::Caption,
              theme~,
              width=44.0,
              height=20.0,
              align=@text.TextAlign::TextEnd,
            ).foreground(palette.muted),
          ],
          spacing=6.0,
          align=@views.CrossAlign::Center,
        ),
        @views.slider(
          value,
          min=0.0,
          max=1.0,
          width=width - 24.0,
          theme~,
          foreground=palette.accent,
          on_change=Some(on_change),
        ),
      ],
      spacing=8.0,
      align=@views.CrossAlign::Stretch,
    ),
    width~,
    height=72.0,
    background=control_card_background(palette),
    corner_radius=16.0,
    border=Some(overlay_card_outline(palette)),
    padding=12.0,
  )
}
