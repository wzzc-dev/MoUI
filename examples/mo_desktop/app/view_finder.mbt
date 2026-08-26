///|
priv struct FileEntry {
  name : String
  kind : String
  size : String
  date : String
  icon : @views.IconName
  color : @graphics.Color
}

///|
/// Content column of a Finder window (toolbar → content → path bar →
/// status). The shared window shell (titlebar, shadow, grip) lives in
/// `app_window` so multiple windows share identical behavior.
fn finder_body(
  model : DesktopModel,
  metrics : WindowMetrics,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  // Keep the Finder body aligned with the shared 40pt traffic-light titlebar.
  let body_height = metrics.height - 40.0
  let toolbar_height = if metrics.compact { 88.0 } else { 52.0 }
  let pathbar_height = 26.0
  let status_height = 24.0
  let content_height = body_height -
    toolbar_height -
    pathbar_height -
    status_height
  let toolbar = finder_toolbar(model, metrics, palette, theme, toolbar_height)
  let pathbar = finder_pathbar(
    model,
    metrics.width,
    pathbar_height,
    palette,
    theme,
  )
  let content = finder_main(
    model,
    metrics.width,
    content_height,
    metrics.compact,
    palette,
    theme,
  )
  let status = finder_status(
    model,
    metrics.width,
    status_height,
    palette,
    theme,
  )
  // macOS Finder stacks: toolbar → content → path bar (bottom) → status.
  // The path bar lives at the bottom of the content area, just above the
  // status strip, not under the toolbar.
  @views.column(
    [toolbar, content, pathbar, status],
    spacing=0.0,
    align=@views.CrossAlign::Stretch,
  )
}

///|
/// macOS Finder path bar: a horizontal breadcrumb under the toolbar showing
/// the current location, with a leading folder glyph and a divider above.
fn finder_pathbar(
  model : DesktopModel,
  width : Double,
  height : Double,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  let location = model.finder_location.label()
  @views.stack([
    @views.container(
      @views.spacer(min_length=0.0, weight=0.0),
      width~,
      height=1.0,
      background=finder_chrome_divider(model.dark_mode),
      padding=0.0,
    ).align(alignment=@geometry.Alignment::top_leading()),
    @views.padding_edges(
      @views.row(
        [
          desktop_icon(@views.IconName::FolderOpen, 13.0, palette.muted),
          @views.text(
            location,
            role=@views.TextRole::Caption,
            theme~,
            width=width - 60.0,
            height=18.0,
          )
          .font(@text.FontSpec::new(size=11.5, weight=520))
          .foreground(palette.foreground),
          desktop_icon(@views.IconName::ChevronDown, 10.0, palette.muted),
        ],
        spacing=6.0,
        align=@views.CrossAlign::Center,
      ),
      left=14.0,
      top=4.0,
      bottom=4.0,
      right=14.0,
    ),
  ]).frame(width~, height~)
}

///|
fn finder_toolbar(
  model : DesktopModel,
  metrics : WindowMetrics,
  palette : DesktopPalette,
  theme : @moui.Theme,
  height : Double,
) -> @moui.View[Msg] {
  // Avoid the stock black segmented control — macOS Finder uses a soft
  // capsule of icon-like view buttons instead of a high-contrast pill.
  let mode = finder_view_mode_control(model, palette, theme)
  let search_width = if metrics.compact {
    (metrics.width - 28.0).max(220.0)
  } else {
    196.0
  }
  let search = @views.container(
    @views.row(
      [
        desktop_icon(@views.IconName::Search, 13.0, palette.muted),
        @views.text_field(
          model.finder_query,
          on_input=value => FinderQueryChanged(value),
          placeholder="Search",
          theme~,
          width=search_width - 34.0,
          height=24.0,
        ),
      ],
      spacing=6.0,
      align=@views.CrossAlign::Center,
    ),
    width=search_width,
    height=28.0,
    background=finder_control_surface(model.dark_mode),
    corner_radius=8.0,
    border=Some(
      @graphics.BorderStyle::new(
        brush=@graphics.Brush::solid(finder_control_border(model.dark_mode)),
        width=1.0,
      ),
    ),
    padding=4.0,
  )
  let nav = @views.row(
    [
      toolbar_nav_button(
        @views.IconName::ChevronLeft,
        "Go back",
        GoFinderBack,
        model.can_go_finder_back(),
        palette,
      ),
      toolbar_nav_button(
        @views.IconName::ChevronRight,
        "Go forward",
        GoFinderForward,
        model.can_go_finder_forward(),
        palette,
      ),
    ],
    spacing=2.0,
    align=@views.CrossAlign::Center,
  )
  let content = if metrics.compact {
    @views.column(
      [
        finder_location_tabs(model, metrics.width - 24.0, theme),
        @views.row(
          [mode, @views.spacer(min_length=6.0), search],
          spacing=8.0,
          align=@views.CrossAlign::Center,
        ),
      ],
      spacing=8.0,
      align=@views.CrossAlign::Stretch,
    )
  } else {
    @views.row(
      [
        nav,
        mode,
        @views.spacer(min_length=8.0, weight=1.0),
        toolbar_icon_button(
          @views.IconName::ListBullet,
          "Sort by name",
          SelectFinderView(ListView),
          palette,
        ),
        toolbar_icon_button(
          @views.IconName::Link,
          "Share selected file",
          RequestFileImport,
          palette,
        ),
        toolbar_icon_button(
          @views.IconName::FileNew,
          "Import files into Finder",
          RequestFileImport,
          palette,
        ),
        toolbar_icon_button(
          @views.IconName::Settings,
          "Finder actions",
          ToggleControlCenter,
          palette,
        ),
        search,
      ],
      spacing=10.0,
      align=@views.CrossAlign::Center,
    )
  }
  @views.stack([
    @views.container(
      @views.spacer(min_length=0.0, weight=0.0),
      width=metrics.width,
      height~,
      // A distinct, low-contrast toolbar material keeps Finder's chrome
      // visually separate from the paper-white file area.
      background=finder_chrome_surface(model.dark_mode),
      padding=0.0,
    ),
    @views.padding_edges(content, left=12.0, top=8.0, bottom=8.0, right=12.0),
    @views.container(
      @views.spacer(min_length=0.0, weight=0.0),
      width=metrics.width,
      height=1.0,
      background=finder_chrome_divider(model.dark_mode),
      padding=0.0,
    ).align(alignment=@geometry.Alignment::bottom_leading()),
  ]).frame(width=metrics.width, height~)
}

///|
fn finder_chrome_surface(dark : Bool) -> @graphics.Color {
  if dark {
    rgba8(38, 43, 53, a=0.96)
  } else {
    rgba8(246, 248, 251, a=0.94)
  }
}

///|
fn finder_chrome_divider(dark : Bool) -> @graphics.Color {
  if dark {
    rgba8(255, 255, 255, a=0.14)
  } else {
    rgba8(187, 194, 204, a=0.72)
  }
}

///|
fn finder_control_surface(dark : Bool) -> @graphics.Color {
  if dark {
    rgba8(61, 68, 80, a=0.92)
  } else {
    rgba8(255, 255, 255, a=0.84)
  }
}

///|
fn finder_control_border(dark : Bool) -> @graphics.Color {
  if dark {
    rgba8(255, 255, 255, a=0.16)
  } else {
    rgba8(183, 191, 202, a=0.64)
  }
}

///|
fn toolbar_nav_button(
  icon : @views.IconName,
  label : String,
  message : Msg,
  enabled : Bool,
  palette : DesktopPalette,
) -> @moui.View[Msg] {
  @views.container(
    desktop_icon(
      icon,
      13.0,
      if enabled {
        palette.foreground
      } else {
        palette.muted.multiply_alpha(0.55)
      },
    ),
    width=26.0,
    height=26.0,
    background=rgba8(0, 0, 0, a=0.0),
    corner_radius=6.0,
    padding=6.0,
  )
  .on_tap(message)
  .disabled(disabled=!enabled)
  .accessibility_label(label)
}

///|
fn finder_view_mode_control(
  model : DesktopModel,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  @views.container(
    @views.row(
      [
        finder_view_mode_button(
          "Icons",
          @views.IconName::Columns,
          model.finder_view_mode == IconView,
          SelectFinderView(IconView),
          palette,
          theme,
          model.dark_mode,
        ),
        finder_view_mode_button(
          "List",
          @views.IconName::ListBullet,
          model.finder_view_mode == ListView,
          SelectFinderView(ListView),
          palette,
          theme,
          model.dark_mode,
        ),
      ],
      spacing=2.0,
      align=@views.CrossAlign::Center,
    ),
    width=76.0,
    height=28.0,
    background=finder_control_surface(model.dark_mode),
    corner_radius=8.0,
    border=Some(
      @graphics.BorderStyle::new(
        brush=@graphics.Brush::solid(finder_control_border(model.dark_mode)),
        width=1.0,
      ),
    ),
    padding=2.0,
  )
}

///|
fn finder_view_mode_button(
  label : String,
  icon : @views.IconName,
  selected : Bool,
  message : Msg,
  palette : DesktopPalette,
  _theme : @moui.Theme,
  dark : Bool,
) -> @moui.View[Msg] {
  @views.container(
    desktop_icon(
      icon,
      13.0,
      if selected {
        palette.foreground
      } else {
        palette.muted
      },
    ),
    width=34.0,
    height=24.0,
    background=if selected {
      finder_control_surface(dark)
    } else {
      rgba8(0, 0, 0, a=0.0)
    },
    corner_radius=6.0,
    border=if selected {
      Some(
        @graphics.BorderStyle::new(
          brush=@graphics.Brush::solid(finder_control_border(dark)),
          width=1.0,
        ),
      )
    } else {
      None
    },
    padding=5.0,
  )
  .on_tap(message)
  .accessibility_label(label)
}

///|
fn finder_location_tabs(
  model : DesktopModel,
  width : Double,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  @views.segmented_control(
    [
      @views.choice_item("documents", "Docs"),
      @views.choice_item("applications", "Apps"),
      @views.choice_item("downloads", "Downloads"),
    ],
    selected=model.finder_location.id(),
    on_select=value => {
      SelectFinderLocation(
        if value == "applications" {
          Applications
        } else if value == "downloads" {
          Downloads
        } else {
          Documents
        },
      )
    },
    theme~,
    width~,
  )
}

///|
fn finder_main(
  model : DesktopModel,
  width : Double,
  height : Double,
  compact : Bool,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  if compact {
    finder_content(model, width, height, palette, theme)
  } else {
    let sidebar_width = 196.0
    @views.row(
      [
        finder_sidebar(model, sidebar_width, palette, theme),
        finder_content(model, width - sidebar_width, height, palette, theme),
      ],
      spacing=0.0,
      align=@views.CrossAlign::Stretch,
    )
  }
}

///|
fn finder_sidebar(
  model : DesktopModel,
  width : Double,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  let panel = @views.container(
    @views.column(
      [
        sidebar_section_header("Favorites", width, palette, theme),
        finder_sidebar_button(
          "Documents",
          @views.IconName::FileNew,
          rgba8(91, 143, 249),
          Documents,
          model,
          width - 24.0,
          palette,
          theme,
        ),
        finder_sidebar_button(
          "Applications",
          @views.IconName::Columns,
          rgba8(156, 97, 222),
          Applications,
          model,
          width - 24.0,
          palette,
          theme,
        ),
        finder_sidebar_button(
          "Downloads",
          @views.IconName::ArrowRight,
          rgba8(38, 175, 129),
          Downloads,
          model,
          width - 24.0,
          palette,
          theme,
        ),
        @views.spacer(min_length=12.0, weight=0.0),
        sidebar_section_header("Locations", width, palette, theme),
        sidebar_static_row(
          "MacBook",
          @views.IconName::FileNew,
          rgba8(116, 128, 142),
          palette,
          theme,
          width - 24.0,
        ),
        sidebar_static_row(
          "Cloud Drive",
          @views.IconName::Focus,
          rgba8(53, 143, 242),
          palette,
          theme,
          width - 24.0,
        ),
        sidebar_static_row(
          "Network",
          @views.IconName::Link,
          rgba8(112, 132, 154),
          palette,
          theme,
          width - 24.0,
        ),
        @views.spacer(min_length=12.0, weight=0.0),
        sidebar_section_header("Tags", width, palette, theme),
        sidebar_tag_row(
          "Important",
          rgba8(255, 95, 87),
          width - 24.0,
          palette,
          theme,
        ),
        sidebar_tag_row(
          "Work",
          rgba8(255, 189, 46),
          width - 24.0,
          palette,
          theme,
        ),
        sidebar_tag_row(
          "Personal",
          rgba8(40, 200, 64),
          width - 24.0,
          palette,
          theme,
        ),
      ],
      spacing=2.0,
      align=@views.CrossAlign::Start,
    ),
    width~,
    padding=12.0,
  )
  // Sidebar fills the full stretched height by using a spacer(weight=1.0)
  // below the content, and the background sits on the outer frame.
  @views.column(
    [panel, @views.spacer(min_length=0.0, weight=1.0)],
    spacing=0.0,
    align=@views.CrossAlign::Stretch,
  )
  .frame(width~)
  .background(palette.sidebar)
}

///|
/// macOS Finder sidebar section headers are small uppercase muted labels
/// with generous top padding between groups.
fn sidebar_section_header(
  label : String,
  width : Double,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  @views.text(
    label,
    role=@views.TextRole::Caption,
    theme~,
    width=width - 28.0,
    height=18.0,
  )
  .font(@text.FontSpec::new(size=11.0, weight=700))
  .foreground(palette.muted)
}

///|
/// macOS Finder sidebar tag rows: a colored dot on the leading edge.
fn sidebar_tag_row(
  label : String,
  color : @graphics.Color,
  width : Double,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  @views.row(
    [
      @views.container(
        @views.spacer(min_length=0.0, weight=0.0),
        width=8.0,
        height=8.0,
        background=color,
        corner_radius=4.0,
        padding=0.0,
      ),
      @views.text(
        label,
        role=@views.TextRole::Body,
        theme~,
        width=width - 32.0,
        height=22.0,
      ).foreground(palette.foreground),
    ],
    spacing=10.0,
    align=@views.CrossAlign::Center,
  )
}

///|
fn finder_selection_surface(palette : DesktopPalette) -> @graphics.Color {
  if palette.dark {
    rgba8(57, 151, 255, a=0.34)
  } else {
    rgba8(90, 160, 255, a=0.24)
  }
}

///|
fn finder_sidebar_button(
  label : String,
  icon : @views.IconName,
  icon_color : @graphics.Color,
  location : FinderLocation,
  model : DesktopModel,
  width : Double,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  let selected = model.finder_location == location
  // Soft blue selection chip instead of a heavy tonal button fill.
  @views.container(
    @views.row(
      [
        desktop_icon(icon, 15.0, icon_color),
        @views.text(
          label,
          role=@views.TextRole::Body,
          theme~,
          width=width - 42.0,
          height=22.0,
        )
        .font(
          @text.FontSpec::new(
            size=13.0,
            weight=if selected { 600 } else { 470 },
          ),
        )
        .foreground(palette.foreground),
      ],
      spacing=8.0,
      align=@views.CrossAlign::Center,
    ),
    width~,
    height=30.0,
    background=if selected {
      finder_selection_surface(palette)
    } else {
      rgba8(0, 0, 0, a=0.0)
    },
    corner_radius=8.0,
    padding=4.0,
  )
  .on_tap(SelectFinderLocation(location))
  .accessibility_label("Open " + label)
}

///|
fn sidebar_static_row(
  label : String,
  icon : @views.IconName,
  icon_color : @graphics.Color,
  palette : DesktopPalette,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[Msg] {
  @views.row(
    [
      desktop_icon(icon, 15.0, icon_color),
      @views.text(
        label,
        role=@views.TextRole::Body,
        theme~,
        width=width - 30.0,
        height=30.0,
      ).foreground(palette.foreground),
    ],
    spacing=8.0,
    align=@views.CrossAlign::Center,
  )
}
