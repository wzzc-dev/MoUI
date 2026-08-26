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
        apple_menu_button(SystemMenu, model, palette, theme, 28.0),
        menu_button(
          model.active_app_label(),
          88.0,
          AppMenu,
          model,
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
        apple_menu_button(SystemMenu, model, palette, theme, 24.0),
        menu_button(
          model.active_app_label(),
          70.0,
          AppMenu,
          model,
          palette,
          theme,
          true,
        ),
        menu_button(
          model.language.text("menu.file"),
          36.0,
          FileMenu,
          model,
          palette,
          theme,
          false,
        ),
        menu_button(
          model.language.text("menu.edit"),
          36.0,
          EditMenu,
          model,
          palette,
          theme,
          false,
        ),
        menu_button(
          model.language.text("menu.view"),
          40.0,
          ViewMenu,
          model,
          palette,
          theme,
          false,
        ),
        menu_button(
          model.language.text("menu.go"),
          30.0,
          GoMenu,
          model,
          palette,
          theme,
          false,
        ),
        menu_button(
          model.language.text("menu.window"),
          60.0,
          WindowMenu,
          model,
          palette,
          theme,
          false,
        ),
        menu_button(
          model.language.text("menu.help"),
          40.0,
          HelpMenu,
          model,
          palette,
          theme,
          false,
        ),
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
      spotlight_button(palette, theme),
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
  model : DesktopModel,
  palette : DesktopPalette,
  theme : @moui.Theme,
  strong : Bool,
) -> @moui.View[Msg] {
  // macOS highlights the currently-open menu in the bar with a translucent
  // blue capsule behind its label.
  let active = match model.overlay {
    MenuBarMenu(opened) => opened == menu
    _ => false
  }
  let label_view = menu_text(label, width, palette, theme, strong)
  if active {
    @views.container(
      label_view,
      width~,
      height=22.0,
      background=palette.accent.multiply_alpha(0.78),
      corner_radius=4.0,
      padding=0.0,
    )
    .on_tap(ToggleMenu(menu))
    .accessibility_label("Open " + label + " menu")
  } else {
    label_view
    .on_tap(ToggleMenu(menu))
    .accessibility_label("Open " + label + " menu")
  }
}

///|
/// The leading Apple-menu button: a custom Apple-logo glyph (rendered via
/// `apple_logo_glyph`) centered in a tap target. Replaces the previous "Mo"
/// text label so the menu bar reads like a real macOS system menu bar.
fn apple_menu_button(
  menu : DesktopMenu,
  model : DesktopModel,
  palette : DesktopPalette,
  _theme : @moui.Theme,
  glyph_size : Double,
) -> @moui.View[Msg] {
  // The menu bar content area is 20px (28px bar − 4px padding × 2). Keep
  // the button exactly 20px to match sibling menu buttons and avoid overflow.
  let target = 20.0
  let actual_glyph = glyph_size.min(target)
  let active = match model.overlay {
    MenuBarMenu(opened) => opened == menu
    _ => false
  }
  let glyph = apple_logo_glyph(actual_glyph, palette.foreground)
  @views.container(
    glyph,
    width=target,
    height=target,
    background=if active {
      palette.accent.multiply_alpha(0.78)
    } else {
      rgba8(0, 0, 0, a=0.0)
    },
    corner_radius=if active { 4.0 } else { 0.0 },
    padding=(target - actual_glyph) / 2.0,
  )
  .on_tap(ToggleMenu(menu))
  .accessibility_label("Open Apple menu")
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
  // Tahoe liquid-glass: tight pill, icons sit flush with minimal bottom
  // shelf so the translucent plate does not read as a white base. Keep
  // metrics compact: plate height = icon + indicator(4) + vertical
  // padding, not a tall pre-set.
  let icon_size = if compact { 44.0 } else { 54.0 }
  let item_gap = if compact { 8.0 } else { 10.0 }
  let side_pad = if compact { 10.0 } else { 12.0 }
  let dock_height = if compact { 62.0 } else { 72.0 }
  // Real macOS Dock uses a translucent frosted plate with a subtle top sheen.
  // Each app tile is a "squircle" (continuous-curve rounded square) and the
  // running app gets a small dot beneath it.
  // App tiles come straight from the registry in dock-priority order, so a
  // new AppKind appears here without touching this view.
  let tiles = app_registry().map(entry => {
    dock_tile(
      entry.label,
      LaunchApp(entry.id),
      model.has_visible_window(entry.id),
      icon_size,
      palette,
      dock_glyph_for(entry.id),
    )
  })
  let utilities = [
    dock_tile(
      "Apps",
      ToggleLauncher,
      model.overlay == Launcher,
      icon_size,
      palette,
      dock_apps_glyph,
    ),
    dock_tile(
      "Inbox",
      ToggleNotificationCenter,
      model.overlay == NotificationCenter,
      icon_size,
      palette,
      dock_inbox_glyph,
    ),
    dock_tile(
      "Controls",
      ToggleControlCenter,
      model.overlay == ControlCenter,
      icon_size,
      palette,
      dock_controls_glyph,
    ),
  ]
  let separator = dock_separator(icon_size, palette)
  let dock_row = @views.row(
    tiles + [separator] + utilities,
    spacing=item_gap,
    justify=@views.MainAlign::Center,
    align=@views.CrossAlign::Center,
  )
  let content_width = icon_size *
    (tiles.length() + utilities.length()).to_double() +
    item_gap * (tiles.length() + utilities.length()).to_double() +
    side_pad * 2.0
  let dock_width = if compact {
    content_width.min(width - 16.0).max(300.0)
  } else {
    content_width
  }
  // Liquid-glass rim: hairline highlight only at the top edge. A
  // uniform white stroke around the whole pill read as a white base;
  // keep the stroke almost invisible on the sides/bottom.
  let rim = @graphics.BorderStyle::new(
    brush=@graphics.Brush::solid(
      if palette.dark {
        rgba8(255, 255, 255, a=0.08)
      } else {
        rgba8(255, 255, 255, a=0.22)
      },
    ),
    width=0.7,
  )
  // Tight pill: horizontal padding carries the capsule breathing room,
  // vertical padding is only enough for the indicator dot. The previous
  // 8.8px uniform padding plus the 7px slot created a white shelf
  // below every icon on the dark lake.
  let h_pad = side_pad * 0.5
  let dock_content = @views.padding_edges(
    dock_row,
    left=h_pad,
    right=h_pad,
    top=5.0,
    bottom=4.0,
  )
  @views.container(
    dock_content,
    width=dock_width,
    height=dock_height,
    background=palette.dock,
    corner_radius=dock_height * 0.42,
    border=Some(rim),
    padding=0.0,
  )
  .clip()
  .shadow(dock_shadow(palette))
  .align(alignment=@geometry.Alignment::bottom_leading())
  .offset(dx=(width - dock_width) / 2.0, dy=-10.0)
  .frame(width~, height~)
}

///|
/// A thin translucent vertical rule separating pinned apps from utilities,
/// matching the divider seen in the macOS Dock.
fn dock_separator(
  icon_size : Double,
  palette : DesktopPalette,
) -> @moui.View[Msg] {
  let divider = if palette.dark {
    rgba8(255, 255, 255, a=0.18)
  } else {
    rgba8(255, 255, 255, a=0.55)
  }
  @views.container(
    @views.spacer(min_length=1.0, weight=0.0),
    width=2.0,
    height=icon_size * 0.62,
    background=divider,
    corner_radius=1.0,
    padding=0.0,
  )
}

///|
/// One Dock tile: squircle glyph with a subtle highlight plus the running
/// indicator dot under the active app. The active tile is rendered slightly
/// larger with a stronger shadow so the running app reads as "lifted" toward
/// the user, echoing macOS Dock's hover/active emphasis (MoUI does not expose
/// pointer-enter events to app code, so we key the lift off the running state
/// instead of a hover).
fn dock_tile(
  label : String,
  message : Msg,
  active : Bool,
  icon_size : Double,
  palette : DesktopPalette,
  glyph : (Double, DesktopPalette) -> @moui.View[Msg],
) -> @moui.View[Msg] {
  // Active tile: 8% larger glyph + a slightly deeper shadow so it lifts
  // off the plate. Use neutral black rather than the palette's bluish
  // shadow so the lift does not tint the dock plate.
  let scaled_size = if active { icon_size * 1.08 } else { icon_size }
  let tile = glyph(scaled_size, palette)
    .shadow(
      if active {
        if palette.dark {
          @graphics.ShadowStyle::new(
            color=rgba8(0, 0, 0, a=0.34),
            offset=@geometry.Point::new(x=0.0, y=5.0),
            blur_radius=12.0,
            spread=0.0,
          )
        } else {
          @graphics.ShadowStyle::new(
            color=rgba8(0, 0, 0, a=0.16),
            offset=@geometry.Point::new(x=0.0, y=5.0),
            blur_radius=12.0,
            spread=0.0,
          )
        }
      } else {
        dock_tile_shadow(palette)
      },
    )
    .on_tap(message)
    .accessibility_label(label)
  // macOS running indicator: a 4pt dot centered under the tile.
  let indicator_color = if palette.dark {
    rgba8(255, 255, 255, a=0.92)
  } else {
    rgba8(28, 34, 42, a=0.85)
  }
  let indicator = @views.container(
    @views.spacer(min_length=0.0, weight=0.0),
    width=4.0,
    height=4.0,
    background=if active { indicator_color } else { rgba8(0, 0, 0, a=0.0) },
    corner_radius=2.0,
    padding=0.0,
  )
  // Keep the overall tile slot height stable so the active tile's larger glyph
  // does not push the dock row around; the glyph grows inside a fixed frame.
  // Spacing is minimal (2px) so the gap between the squircle bottom and
  // the indicator does not read as a white shelf.
  @views.container(
    @views.column(
      [
        @views.container(tile, width=icon_size, height=icon_size, padding=0.0),
        indicator,
      ],
      spacing=2.0,
      align=@views.CrossAlign::Center,
    ),
    width=icon_size,
    height=icon_size + 6.0,
    padding=0.0,
  )
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
/// Labeled Spotlight trigger in the menu bar. Spotlight existed as an
/// overlay but had no entry point before; a text control keeps it reachable
/// for pointer and assistive-tech users alike.
fn spotlight_button(
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  @views.container(
    @views.text(
      "Spotlight",
      role=@views.TextRole::Caption,
      theme~,
      width=58.0,
      height=18.0,
    ).foreground(palette.foreground),
    width=64.0,
    height=22.0,
    background=rgba8(0, 0, 0, a=0.0),
    corner_radius=6.0,
    padding=0.0,
  )
  .on_tap(ToggleSpotlight)
  .accessibility_label("Open Spotlight search")
}

///|
fn dock_glyph_for(app : AppKind) -> (Double, DesktopPalette) -> @moui.View[Msg] {
  match app {
    FinderApp => dock_finder_glyph
    SafariApp => dock_safari_glyph
    NotesApp => dock_notes_glyph
    TerminalApp => dock_terminal_glyph
  }
}

///|
fn dock_notes_glyph(
  size : Double,
  _palette : DesktopPalette,
) -> @moui.View[Msg] {
  @views.stack([
    @views.container(
      @views.spacer(min_length=0.0, weight=0.0),
      width=size * 0.56,
      height=size * 0.68,
      background=rgba8(252, 253, 255),
      corner_radius=size * 0.08,
      border=Some(
        @graphics.BorderStyle::new(
          brush=@graphics.Brush::solid(rgba8(210, 218, 228)),
          width=1.0,
        ),
      ),
      padding=0.0,
    ),
    @views.column(
      [
        @views.container(
          @views.spacer(min_length=0.0, weight=0.0),
          width=size * 0.56,
          height=size * 0.14,
          background=rgba8(244, 170, 53),
          padding=0.0,
        ),
        @views.spacer(min_length=0.0, weight=1.0),
      ],
      spacing=0.0,
    ).frame(width=size * 0.56, height=size * 0.68),
  ]).frame(width=size * 0.56, height=size * 0.68)
}

///|
fn dock_terminal_glyph(
  size : Double,
  _palette : DesktopPalette,
) -> @moui.View[Msg] {
  @views.container(
    @views.text(
      ">_",
      role=@views.TextRole::Caption,
      width=size * 0.6,
      height=size * 0.5,
    )
    .font(@text.FontSpec::new(size=size * 0.26, weight=700))
    .foreground(rgba8(158, 226, 158)),
    width=size * 0.64,
    height=size * 0.54,
    background=rgba8(16, 20, 26),
    corner_radius=size * 0.1,
    padding=size * 0.06,
  )
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
