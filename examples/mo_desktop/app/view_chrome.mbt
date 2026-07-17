///|
fn menu_bar(
  model : DesktopModel,
  palette : DesktopPalette,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[Msg] {
  let compact = width < 760.0
  let left = if compact {
    @views.row(
      [
        menu_text("Mo", 36.0, palette, theme, true),
        menu_text(model.active_app_label(), 90.0, palette, theme, true),
      ],
      spacing=4.0,
      align=@views.CrossAlign::Center,
    )
  } else {
    @views.row(
      [
        menu_text("Mo", 36.0, palette, theme, true),
        menu_text(model.active_app_label(), 82.0, palette, theme, true),
        menu_text("File", 42.0, palette, theme, false),
        menu_text("Edit", 42.0, palette, theme, false),
        menu_text("View", 46.0, palette, theme, false),
        menu_text("Go", 34.0, palette, theme, false),
        menu_text("Window", 68.0, palette, theme, false),
        menu_text("Help", 48.0, palette, theme, false),
      ],
      spacing=2.0,
      align=@views.CrossAlign::Center,
    )
  }
  let clock_width = if compact { 64.0 } else { 166.0 }
  let right = @views.row(
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
      @views.container(
        @views.text(
          if compact {
            "09:41"
          } else {
            "Fri Jul 17  09:41"
          },
          role=@views.TextRole::Label,
          theme~,
          width=clock_width,
          height=22.0,
          align=@text.TextAlign::TextCenter,
        ).foreground(palette.foreground),
        width=clock_width,
        height=26.0,
        background=rgba8(0, 0, 0, a=0.0),
        corner_radius=8.0,
        padding=2.0,
      )
      .on_tap(ToggleNotificationCenter)
      .accessibility_label("Open Notification Center"),
    ],
    spacing=4.0,
    align=@views.CrossAlign::Center,
  )
  @views.container(
    @views.row(
      [left, @views.spacer(min_length=6.0), right],
      spacing=6.0,
      align=@views.CrossAlign::Center,
    ),
    width~,
    height=26.0,
    background=palette.glass,
    padding=2.0,
  ).align(alignment=@geometry.Alignment::top_leading())
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
    height=22.0,
    align=@text.TextAlign::TextCenter,
  )
  .font(@text.FontSpec::new(size=13.0, weight=if strong { 650 } else { 430 }))
  .foreground(palette.foreground)
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
  let icon_size = if compact { 42.0 } else { 54.0 }
  let dock_width = if compact { (width - 20.0).max(280.0) } else { 394.0 }
  let items = [
    dock_item(
      "Finder",
      @views.IconName::FolderOpen,
      rgba8(33, 150, 243),
      OpenFinder,
      model.active_window == Finder,
      icon_size,
      palette,
    ),
    dock_item(
      "Apps",
      @views.IconName::Columns,
      rgba8(72, 78, 88),
      ToggleLauncher,
      model.overlay == Launcher,
      icon_size,
      palette,
    ),
    dock_item(
      "Safari",
      @views.IconName::Link,
      rgba8(36, 177, 216),
      OpenSafari,
      model.active_window == Safari,
      icon_size,
      palette,
    ),
    dock_item(
      "Inbox",
      @views.IconName::Info,
      rgba8(236, 72, 118),
      ToggleNotificationCenter,
      model.overlay == NotificationCenter,
      icon_size,
      palette,
    ),
    dock_item(
      "Controls",
      @views.IconName::Settings,
      rgba8(91, 99, 112),
      ToggleControlCenter,
      model.overlay == ControlCenter,
      icon_size,
      palette,
    ),
  ]
  @views.container(
    @views.row(
      items,
      spacing=if compact { 8.0 } else { 14.0 },
      justify=@views.MainAlign::Center,
      align=@views.CrossAlign::End,
    ),
    width=dock_width,
    height=if compact { 62.0 } else { 70.0 },
    background=palette.dock,
    corner_radius=22.0,
    border=Some(desktop_hairline(palette)),
    padding=7.0,
  )
  .shadow(desktop_shadow(palette))
  .align(alignment=@geometry.Alignment::bottom_leading())
  .offset(dx=(width - dock_width) / 2.0, dy=-12.0)
  .frame(width~, height~)
}

///|
fn dock_item(
  label : String,
  icon : @views.IconName,
  color : @graphics.Color,
  message : Msg,
  active : Bool,
  icon_size : Double,
  palette : DesktopPalette,
) -> @moui.View[Msg] {
  let tile = @views.container(
      desktop_icon(icon, icon_size * 0.48, @graphics.Color::white()),
      width=icon_size,
      height=icon_size,
      background=color,
      corner_radius=icon_size * 0.23,
      border=Some(desktop_hairline(palette)),
      padding=icon_size * 0.20,
    )
    .on_tap(message)
    .accessibility_label(label)
  let indicator = @views.container(
    @views.spacer(min_length=0.0, weight=0.0),
    width=5.0,
    height=5.0,
    background=if active { palette.foreground } else { rgba8(0, 0, 0, a=0.0) },
    corner_radius=3.0,
    padding=0.0,
  )
  @views.column([tile, indicator], spacing=3.0, align=@views.CrossAlign::Center)
}
