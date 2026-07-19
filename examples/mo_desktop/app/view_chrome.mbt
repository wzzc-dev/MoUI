///|
fn menu_bar(
  model : DesktopModel,
  palette : DesktopPalette,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[Msg] {
  let compact = width < 760.0
  // macOS menu bar: menus hug the left edge, status items hug the right.
  let left = if compact {
    @views.row(
      [
        menu_button("Mo", 34.0, SystemMenu, palette, theme, true),
        menu_button(
          model.active_app_label(),
          88.0,
          AppMenu,
          palette,
          theme,
          true,
        ),
      ],
      spacing=2.0,
      align=@views.CrossAlign::Center,
    )
  } else {
    @views.row(
      [
        menu_button("Mo", 30.0, SystemMenu, palette, theme, true),
        menu_button(
          model.active_app_label(),
          70.0,
          AppMenu,
          palette,
          theme,
          true,
        ),
        menu_button("File", 36.0, FileMenu, palette, theme, false),
        menu_button("Edit", 36.0, EditMenu, palette, theme, false),
        menu_button("View", 40.0, ViewMenu, palette, theme, false),
        menu_button("Go", 30.0, GoMenu, palette, theme, false),
        menu_button("Window", 60.0, WindowMenu, palette, theme, false),
        menu_button("Help", 40.0, HelpMenu, palette, theme, false),
      ],
      spacing=0.0,
      align=@views.CrossAlign::Center,
    )
  }
  let clock_width = if compact { 52.0 } else { 128.0 }
  let status_items = if compact {
    [
      menu_icon(
        @views.IconName::Search,
        "Open app launcher",
        ToggleLauncher,
        palette,
      ),
      menu_icon(
        @views.IconName::Settings,
        "Open Control Center",
        ToggleControlCenter,
        palette,
      ),
    ]
  } else {
    [
      menu_icon(
        @views.IconName::Search,
        "Open app launcher",
        ToggleLauncher,
        palette,
      ),
      menu_icon(
        @views.IconName::Link,
        "Wi-Fi connected",
        ToggleControlCenter,
        palette,
      ),
      menu_icon(
        @views.IconName::Focus,
        "Sound controls",
        ToggleControlCenter,
        palette,
      ),
      menu_icon(
        @views.IconName::Settings,
        "Open Control Center",
        ToggleControlCenter,
        palette,
      ),
    ]
  }
  let right = @views.row(
    [
      @views.row(status_items, spacing=2.0, align=@views.CrossAlign::Center),
      @views.container(
        @views.text(
          if compact {
            desktop_clock_time(model.clock)
          } else {
            desktop_clock_menu_label(model.clock)
          },
          role=@views.TextRole::Label,
          theme~,
          width=clock_width,
          height=20.0,
          align=@text.TextAlign::TextEnd,
        )
        .font(@text.FontSpec::new(size=12.5, weight=480))
        .foreground(palette.foreground),
        width=clock_width,
        height=24.0,
        background=rgba8(0, 0, 0, a=0.0),
        corner_radius=6.0,
        padding=0.0,
      )
      .on_tap(ToggleNotificationCenter)
      .accessibility_label("Open Notification Center"),
    ],
    spacing=2.0,
    align=@views.CrossAlign::Center,
  )
  // Translucent strip across the top, matching macOS menu bar chrome.
  // Menus and status items are absolutely pinned so the bar never centers as a
  // single content cluster (the previous flex spacer still measured as tight).
  let bar_fill = if model.dark_mode {
    rgba8(18, 22, 30, a=0.42)
  } else {
    rgba8(248, 250, 252, a=0.48)
  }
  let left_width = if compact { 150.0 } else { 390.0 }
  let right_width = if compact { 150.0 } else { 284.0 }
  @views.stack([
    @views.container(
      @views.spacer(min_length=0.0, weight=0.0),
      width~,
      height=28.0,
      background=bar_fill,
      padding=0.0,
    ),
    @views.padding_edges(
      left.frame(width=left_width, height=28.0),
      left=12.0,
      top=4.0,
      bottom=4.0,
      right=0.0,
    ).align(alignment=@geometry.Alignment::top_leading()),
    @views.padding_edges(
      right.frame(width=right_width, height=28.0),
      left=0.0,
      top=2.0,
      bottom=2.0,
      right=12.0,
    ).align(alignment=@geometry.Alignment::top_trailing()),
  ])
  .frame(width~, height=28.0)
  .align(alignment=@geometry.Alignment::top_leading())
}

///|
fn menu_text(
  label : String,
  width : Double,
  palette : DesktopPalette,
  theme : @moui.Theme,
  strong : Bool,
) -> @moui.View[Msg] {
  @views.text(
    label,
    role=@views.TextRole::Label,
    theme~,
    width~,
    height=20.0,
    align=@text.TextAlign::TextCenter,
  )
  .font(@text.FontSpec::new(size=13.0, weight=if strong { 620 } else { 430 }))
  .foreground(palette.foreground)
}

///|
fn menu_button(
  label : String,
  width : Double,
  menu : DesktopMenu,
  palette : DesktopPalette,
  theme : @moui.Theme,
  strong : Bool,
) -> @moui.View[Msg] {
  menu_text(label, width, palette, theme, strong)
  .on_tap(ToggleMenu(menu))
  .accessibility_label("Open " + label + " menu")
}

///|
fn menu_icon(
  icon : @views.IconName,
  label : String,
  message : Msg,
  palette : DesktopPalette,
) -> @moui.View[Msg] {
  @views.container(
    desktop_icon(icon, 16.0, palette.foreground),
    width=28.0,
    height=26.0,
    background=rgba8(0, 0, 0, a=0.0),
    corner_radius=8.0,
    padding=5.0,
  )
  .on_tap(message)
  .accessibility_label(label)
}

///|
fn toolbar_icon_button(
  icon : @views.IconName,
  label : String,
  message : Msg,
  palette : DesktopPalette,
) -> @moui.View[Msg] {
  @views.container(
    desktop_icon(icon, 16.0, palette.foreground),
    width=34.0,
    height=34.0,
    background=rgba8(0, 0, 0, a=0.0),
    corner_radius=8.0,
    padding=8.0,
  )
  .on_tap(message)
  .accessibility_label(label)
}

///|
fn dock(
  model : DesktopModel,
  palette : DesktopPalette,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  let compact = width < 560.0
  // Slightly larger tiles + tighter radius read closer to macOS Dock icons.
  let icon_size = if compact { 46.0 } else { 58.0 }
  let item_gap = if compact { 10.0 } else { 12.0 }
  let side_pad = if compact { 12.0 } else { 16.0 }
  let dock_height = if compact { 74.0 } else { 84.0 }
  let items = [
    dock_item(
      "Finder",
      OpenFinder,
      model.active_window == Finder,
      icon_size,
      palette,
      dock_finder_glyph,
    ),
    dock_item(
      "Apps",
      ToggleLauncher,
      model.overlay == Launcher,
      icon_size,
      palette,
      dock_apps_glyph,
    ),
    dock_item(
      "Safari",
      OpenSafari,
      model.active_window == Safari,
      icon_size,
      palette,
      dock_safari_glyph,
    ),
    dock_item(
      "Inbox",
      ToggleNotificationCenter,
      model.overlay == NotificationCenter,
      icon_size,
      palette,
      dock_inbox_glyph,
    ),
    dock_item(
      "Controls",
      ToggleControlCenter,
      model.overlay == ControlCenter,
      icon_size,
      palette,
      dock_controls_glyph,
    ),
  ]
  let content_width = icon_size * items.length().to_double() +
    item_gap * (items.length() - 1).to_double() +
    side_pad * 2.0
  let dock_width = if compact {
    content_width.min(width - 16.0).max(300.0)
  } else {
    content_width
  }
  let rim = @graphics.BorderStyle::new(
    brush=@graphics.Brush::solid(
      if palette.dark {
        rgba8(255, 255, 255, a=0.34)
      } else {
        rgba8(255, 255, 255, a=0.55)
      },
    ),
    width=1.0,
  )
  @views.container(
    @views.row(
      items,
      spacing=item_gap,
      justify=@views.MainAlign::Center,
      align=@views.CrossAlign::End,
    ),
    width=dock_width,
    height=dock_height,
    background=palette.dock,
    corner_radius=dock_height * 0.36,
    border=Some(rim),
    padding=side_pad * 0.55,
  )
  .shadow(dock_shadow(palette))
  .align(alignment=@geometry.Alignment::bottom_leading())
  .offset(dx=(width - dock_width) / 2.0, dy=-10.0)
  .frame(width~, height~)
}

///|
fn dock_item(
  label : String,
  message : Msg,
  active : Bool,
  icon_size : Double,
  palette : DesktopPalette,
  glyph : (Double, DesktopPalette) -> @moui.View[Msg],
) -> @moui.View[Msg] {
  // Multi-layer colored glyphs on a pale squircle read closer to macOS Dock
  // apps than monochrome white icons on flat solid tiles.
  let tile = glyph(icon_size, palette)
    .shadow(dock_tile_shadow(palette))
    .on_tap(message)
    .accessibility_label(label)
  let indicator = @views.container(
    @views.spacer(min_length=0.0, weight=0.0),
    width=4.0,
    height=4.0,
    background=if active {
      if palette.dark {
        rgba8(255, 255, 255, a=0.88)
      } else {
        rgba8(28, 34, 42, a=0.88)
      }
    } else {
      rgba8(0, 0, 0, a=0.0)
    },
    corner_radius=2.0,
    padding=0.0,
  )
  @views.column([tile, indicator], spacing=4.0, align=@views.CrossAlign::Center)
}

///|
fn dock_tile_shell(
  size : Double,
  base : @graphics.Color,
  child : @moui.View[Msg],
) -> @moui.View[Msg] {
  @views.stack([
    @views.container(
      @views.spacer(min_length=0.0, weight=0.0),
      width=size,
      height=size,
      background=base,
      corner_radius=size * 0.24,
      border=Some(
        @graphics.BorderStyle::new(
          brush=@graphics.Brush::solid(rgba8(255, 255, 255, a=0.42)),
          width=1.0,
        ),
      ),
      padding=0.0,
    ),
    // Top sheen strip to fake a glossy macOS icon surface.
    @views.container(
      @views.spacer(min_length=0.0, weight=0.0),
      width=size - 6.0,
      height=size * 0.34,
      background=rgba8(255, 255, 255, a=0.20),
      corner_radius=size * 0.18,
      padding=0.0,
    )
    .align(alignment=@geometry.Alignment::top_leading())
    .offset(dx=3.0, dy=3.0),
    child.align(alignment=@geometry.Alignment::center()),
  ]).frame(width=size, height=size)
}

///|
fn dock_finder_glyph(
  size : Double,
  _palette : DesktopPalette,
) -> @moui.View[Msg] {
  let face = @views.stack([
    @views.container(
      @views.spacer(min_length=0.0, weight=0.0),
      width=size * 0.52,
      height=size * 0.36,
      background=rgba8(92, 180, 255),
      corner_radius=size * 0.08,
      padding=0.0,
    )
    .align(alignment=@geometry.Alignment::top_leading())
    .offset(dx=size * 0.08, dy=size * 0.18),
    @views.container(
      @views.spacer(min_length=0.0, weight=0.0),
      width=size * 0.56,
      height=size * 0.34,
      background=rgba8(34, 132, 242),
      corner_radius=size * 0.08,
      padding=0.0,
    )
    .align(alignment=@geometry.Alignment::top_leading())
    .offset(dx=size * 0.12, dy=size * 0.30),
  ]).frame(width=size * 0.72, height=size * 0.62)
  dock_tile_shell(size, rgba8(236, 244, 255), face)
}

///|
fn dock_apps_glyph(size : Double, _palette : DesktopPalette) -> @moui.View[Msg] {
  let cell = size * 0.16
  let gap = size * 0.06
  let colors = [
    rgba8(255, 95, 87),
    rgba8(255, 189, 46),
    rgba8(40, 200, 64),
    rgba8(52, 148, 246),
  ]
  let dots = colors.map(color => {
    @views.container(
      @views.spacer(min_length=0.0, weight=0.0),
      width=cell,
      height=cell,
      background=color,
      corner_radius=cell * 0.28,
      padding=0.0,
    )
  })
  let grid = @views.column(
    [
      @views.row(
        [dots[0], dots[1]],
        spacing=gap,
        align=@views.CrossAlign::Center,
      ),
      @views.row(
        [dots[2], dots[3]],
        spacing=gap,
        align=@views.CrossAlign::Center,
      ),
    ],
    spacing=gap,
    align=@views.CrossAlign::Center,
  )
  dock_tile_shell(size, rgba8(56, 60, 68), grid)
}

///|
fn dock_safari_glyph(
  size : Double,
  _palette : DesktopPalette,
) -> @moui.View[Msg] {
  let face = @views.stack([
    @views.container(
      @views.spacer(min_length=0.0, weight=0.0),
      width=size * 0.54,
      height=size * 0.54,
      background=rgba8(74, 188, 255),
      corner_radius=size * 0.27,
      border=Some(
        @graphics.BorderStyle::new(
          brush=@graphics.Brush::solid(rgba8(255, 255, 255, a=0.55)),
          width=2.0,
        ),
      ),
      padding=0.0,
    ),
    @views.container(
      @views.spacer(min_length=0.0, weight=0.0),
      width=size * 0.10,
      height=size * 0.34,
      background=rgba8(255, 90, 90),
      corner_radius=size * 0.04,
      padding=0.0,
    )
    .align(alignment=@geometry.Alignment::center())
    .offset(dx=size * 0.04, dy=-size * 0.04),
    @views.container(
      @views.spacer(min_length=0.0, weight=0.0),
      width=size * 0.10,
      height=size * 0.22,
      background=@graphics.Color::white(),
      corner_radius=size * 0.04,
      padding=0.0,
    )
    .align(alignment=@geometry.Alignment::center())
    .offset(dx=-size * 0.04, dy=size * 0.08),
  ]).frame(width=size * 0.62, height=size * 0.62)
  dock_tile_shell(size, rgba8(232, 246, 255), face)
}

///|
fn dock_inbox_glyph(
  size : Double,
  _palette : DesktopPalette,
) -> @moui.View[Msg] {
  let face = @views.stack([
    @views.container(
      @views.spacer(min_length=0.0, weight=0.0),
      width=size * 0.56,
      height=size * 0.40,
      background=rgba8(255, 120, 150),
      corner_radius=size * 0.08,
      padding=0.0,
    ),
    @views.container(
      @views.spacer(min_length=0.0, weight=0.0),
      width=size * 0.56,
      height=size * 0.16,
      background=rgba8(255, 70, 110),
      corner_radius=size * 0.05,
      padding=0.0,
    ).align(alignment=@geometry.Alignment::bottom_leading()),
    desktop_icon(@views.IconName::Info, size * 0.22, @graphics.Color::white()).align(
      alignment=@geometry.Alignment::center(),
    ),
  ]).frame(width=size * 0.56, height=size * 0.46)
  dock_tile_shell(size, rgba8(255, 236, 242), face)
}

///|
fn dock_controls_glyph(
  size : Double,
  _palette : DesktopPalette,
) -> @moui.View[Msg] {
  let face = @views.stack([
    @views.container(
      @views.spacer(min_length=0.0, weight=0.0),
      width=size * 0.42,
      height=size * 0.42,
      background=rgba8(140, 148, 160),
      corner_radius=size * 0.21,
      border=Some(
        @graphics.BorderStyle::new(
          brush=@graphics.Brush::solid(rgba8(255, 255, 255, a=0.40)),
          width=2.0,
        ),
      ),
      padding=0.0,
    ),
    @views.container(
      @views.spacer(min_length=0.0, weight=0.0),
      width=size * 0.16,
      height=size * 0.16,
      background=rgba8(70, 76, 88),
      corner_radius=size * 0.08,
      padding=0.0,
    ).align(alignment=@geometry.Alignment::center()),
  ]).frame(width=size * 0.48, height=size * 0.48)
  dock_tile_shell(size, rgba8(236, 238, 242), face)
}
