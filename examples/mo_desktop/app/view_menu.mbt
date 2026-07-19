///|
priv struct MenuBarItem {
  label : String
  shortcut : String
  command : MenuCommand
}

///|
fn menu_bar_popup(
  model : DesktopModel,
  menu : DesktopMenu,
  palette : DesktopPalette,
  theme : @moui.Theme,
  viewport_width : Double,
  viewport_height : Double,
) -> @moui.View[Msg] {
  let compact = viewport_width < 760.0
  let width = if compact { 224.0 } else { 238.0 }
  let items = menu_bar_items(model, menu)
  let height = 18.0 + items.length().to_double() * 34.0
  let panel = @views.container(
    @views.column(
      items.map(item => menu_bar_item(item, width - 16.0, palette, theme)),
      spacing=0.0,
      align=@views.CrossAlign::Stretch,
    ),
    width~,
    height~,
    background=overlay_panel_background(palette),
    corner_radius=12.0,
    border=Some(desktop_hairline(palette)),
    padding=8.0,
  ).shadow(
    @graphics.ShadowStyle::new(
      color=rgba8(0, 0, 0, a=0.26),
      offset=@geometry.Point::new(x=0.0, y=8.0),
      blur_radius=20.0,
      spread=0.0,
    ),
  )
  let left = if compact {
    match menu {
      SystemMenu => 8.0
      _ => 44.0
    }
  } else {
    match menu {
      SystemMenu => 8.0
      AppMenu => 42.0
      FileMenu => 112.0
      EditMenu => 148.0
      ViewMenu => 184.0
      GoMenu => 224.0
      WindowMenu => 254.0
      HelpMenu => 314.0
    }
  }
  // Click-away dismissal starts below the menu bar so another menu can be
  // selected directly instead of first requiring a separate dismissal tap.
  @views.stack([
    color_layer(viewport_width, viewport_height - 32.0, rgba8(0, 0, 0, a=0.0))
    .on_tap(DismissOverlay)
    .offset(dy=32.0),
    panel
    .align(alignment=@geometry.Alignment::top_leading())
    .offset(dx=left, dy=32.0)
    .frame(width=viewport_width, height=viewport_height),
  ])
}

///|
fn menu_bar_items(
  model : DesktopModel,
  menu : DesktopMenu,
) -> Array[MenuBarItem] {
  match menu {
    SystemMenu =>
      [
        { label: "About This Mac", shortcut: "", command: ShowAboutThisMac },
        {
          label: "System Settings…",
          shortcut: "",
          command: ShowSystemSettings,
        },
        { label: "App Store…", shortcut: "", command: ShowAppStore },
        { label: "Lock Screen", shortcut: "⌃⌘Q", command: LockSession },
      ]
    AppMenu =>
      [
        {
          label: "New Finder Window",
          shortcut: "⌘N",
          command: OpenFinderWindow,
        },
        {
          label: "New Safari Window",
          shortcut: "⌘⌥N",
          command: OpenSafariWindow,
        },
        {
          label: "Close " + model.active_app_label(),
          shortcut: "⌘W",
          command: CloseFocusedWindow,
        },
      ]
    FileMenu =>
      [
        { label: "Documents", shortcut: "⌘1", command: OpenDocuments },
        { label: "Downloads", shortcut: "⌘2", command: OpenDownloads },
        {
          label: "New Safari Window",
          shortcut: "⌘N",
          command: OpenSafariWindow,
        },
      ]
    EditMenu =>
      [
        { label: "Undo", shortcut: "⌘Z", command: ShowFinderIconView },
        { label: "Redo", shortcut: "⇧⌘Z", command: ShowFinderListView },
        { label: "Select All", shortcut: "⌘A", command: ShowFinderIconView },
      ]
    ViewMenu =>
      [
        { label: "as Icons", shortcut: "⌘1", command: ShowFinderIconView },
        { label: "as List", shortcut: "⌘2", command: ShowFinderListView },
        {
          label: "Enter Full Screen",
          shortcut: "⌃⌘F",
          command: ZoomFocusedWindow,
        },
      ]
    GoMenu =>
      [
        { label: "Documents", shortcut: "⇧⌘O", command: OpenDocuments },
        { label: "Downloads", shortcut: "⌥⌘L", command: OpenDownloads },
        { label: "Applications", shortcut: "⇧⌘A", command: OpenLauncher },
      ]
    WindowMenu =>
      [
        { label: "Minimize", shortcut: "⌘M", command: MinimizeFocusedWindow },
        { label: "Zoom", shortcut: "", command: ZoomFocusedWindow },
        {
          label: "Bring Finder Forward",
          shortcut: "",
          command: OpenFinderWindow,
        },
        {
          label: "Bring Safari Forward",
          shortcut: "",
          command: OpenSafariWindow,
        },
      ]
    HelpMenu =>
      [
        {
          label: "Mo Desktop Help",
          shortcut: "",
          command: OpenNotificationCenter,
        },
        {
          label: "Show Notifications",
          shortcut: "",
          command: OpenNotificationCenter,
        },
      ]
  }
}

///|
fn menu_bar_item(
  item : MenuBarItem,
  width : Double,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  @views.container(
    @views.row(
      [
        @views.text(
          item.label,
          role=@views.TextRole::Label,
          theme~,
          width=width - 54.0,
          height=24.0,
        )
        .font(@text.FontSpec::new(size=13.0, weight=460))
        .foreground(palette.foreground),
        @views.text(
          item.shortcut,
          role=@views.TextRole::Caption,
          theme~,
          width=48.0,
          height=24.0,
          align=@text.TextAlign::TextEnd,
        )
        .font(@text.FontSpec::new(size=11.5, weight=460))
        .foreground(palette.muted),
      ],
      spacing=6.0,
      align=@views.CrossAlign::Center,
    ),
    width~,
    height=34.0,
    background=rgba8(0, 0, 0, a=0.0),
    corner_radius=7.0,
    padding=5.0,
  )
  .on_tap(RunMenuCommand(item.command))
  .accessibility_label(item.label)
}
