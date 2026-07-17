///|
priv struct FileEntry {
  name : String
  kind : String
  size : String
  icon : @views.IconName
  color : @graphics.Color
}

///|
fn finder_window(
  model : DesktopModel,
  palette : DesktopPalette,
  theme : @moui.Theme,
  viewport_width : Double,
  viewport_height : Double,
) -> @moui.View[Msg] {
  let metrics = window_metrics(model, viewport_width, viewport_height)
  // Keep the Finder body aligned with the shared 40pt traffic-light titlebar.
  let body_height = metrics.height - 40.0
  let toolbar_height = if metrics.compact { 88.0 } else { 52.0 }
  let status_height = 24.0
  let content_height = body_height - toolbar_height - status_height
  let toolbar = finder_toolbar(model, metrics, palette, theme, toolbar_height)
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
  app_window(
    model,
    model.finder_location.label(),
    @views.column(
      [toolbar, content, status],
      spacing=0.0,
      align=@views.CrossAlign::Stretch,
    ),
    metrics,
    palette,
    theme,
    viewport_width,
    viewport_height,
  )
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
        "Back (unavailable)",
        palette,
      ),
      toolbar_nav_button(
        @views.IconName::ChevronRight,
        "Forward (unavailable)",
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
  palette : DesktopPalette,
) -> @moui.View[Msg] {
  @views.container(
    desktop_icon(icon, 13.0, palette.muted),
    width=26.0,
    height=26.0,
    background=rgba8(0, 0, 0, a=0.0),
    corner_radius=6.0,
    padding=6.0,
  ).accessibility_label(label)
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
          SelectFinderView("icons"),
          palette,
          theme,
          model.dark_mode,
        ),
        finder_view_mode_button(
          "List",
          @views.IconName::ListBullet,
          model.finder_view_mode == ListView,
          SelectFinderView("list"),
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
        finder_sidebar(model, sidebar_width, height, palette, theme),
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
  height : Double,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  @views.container(
    @views.column(
      [
        @views.text(
          "Favorites",
          role=@views.TextRole::Caption,
          theme~,
          width=width - 28.0,
          height=18.0,
        )
        .font(@text.FontSpec::new(size=11.0, weight=600))
        .foreground(palette.muted),
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
        @views.spacer(min_length=14.0, weight=0.0),
        @views.text(
          "Locations",
          role=@views.TextRole::Caption,
          theme~,
          width=width - 28.0,
          height=18.0,
        )
        .font(@text.FontSpec::new(size=11.0, weight=600))
        .foreground(palette.muted),
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
      ],
      spacing=2.0,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height~,
    background=palette.sidebar,
    padding=12.0,
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

///|
fn finder_content(
  model : DesktopModel,
  width : Double,
  height : Double,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  let entries = visible_finder_entries(model)
  let inner_width = (width - 28.0).max(220.0)
  let content = if entries.is_empty() {
    @views.column(
      [
        @views.text(
          "No files match \"\{model.finder_query}\"",
          role=@views.TextRole::Title,
          theme~,
          width=inner_width,
          height=36.0,
          align=@text.TextAlign::TextCenter,
        ).foreground(palette.foreground),
        @views.button(
          "Clear Search",
          on_click=FinderQueryChanged(""),
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
    match model.finder_view_mode {
      IconView =>
        @views.responsive_grid(
          entries.map(entry => file_icon(entry, model, palette, theme)),
          width=inner_width,
          min_column_width=118.0,
          row_spacing=18.0,
          column_spacing=14.0,
        )
      ListView =>
        @views.column(
          entries.map(entry => {
            file_list_row(entry, model, inner_width, palette, theme)
          }),
          spacing=4.0,
          align=@views.CrossAlign::Stretch,
        )
    }
  }
  @views.container(
    content,
    width~,
    height~,
    background=palette.content,
    padding=14.0,
  )
}

///|
fn finder_status(
  model : DesktopModel,
  width : Double,
  height : Double,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  let count = visible_finder_entries(model).length()
  let label = if model.selected_file == "" {
    "\{count} items  |  214.3 GB available"
  } else {
    "Selected: \{model.selected_file}"
  }
  @views.container(
    @views.text(
      label,
      role=@views.TextRole::Caption,
      theme~,
      width=width - 24.0,
      height=18.0,
    ).foreground(palette.muted),
    width~,
    height~,
    background=finder_chrome_surface(model.dark_mode),
    padding=5.0,
  )
}

///|
fn visible_finder_entries(model : DesktopModel) -> Array[FileEntry] {
  finder_entries(model.finder_location).filter(entry => {
    model.finder_query == "" || entry.name.contains(model.finder_query)
  })
}

///|
fn finder_entries(location : FinderLocation) -> Array[FileEntry] {
  match location {
    Documents =>
      [
        {
          name: "Project Notes.txt",
          kind: "Text Document",
          size: "14 KB",
          icon: @views.IconName::FileNew,
          color: rgba8(91, 143, 249),
        },
        {
          name: "Q3 Plan.txt",
          kind: "Text Document",
          size: "22 KB",
          icon: @views.IconName::FileNew,
          color: rgba8(121, 103, 238),
        },
        {
          name: "Reading List.md",
          kind: "Markdown",
          size: "8 KB",
          icon: @views.IconName::ListBullet,
          color: rgba8(45, 166, 153),
        },
      ]
    Applications =>
      [
        {
          name: "Mo Browser",
          kind: "Application",
          size: "48 MB",
          icon: @views.IconName::Link,
          color: rgba8(36, 177, 216),
        },
        {
          name: "Notes",
          kind: "Application",
          size: "31 MB",
          icon: @views.IconName::ListTask,
          color: rgba8(250, 194, 55),
        },
        {
          name: "Settings",
          kind: "Application",
          size: "26 MB",
          icon: @views.IconName::Settings,
          color: rgba8(104, 112, 124),
        },
        {
          name: "Terminal",
          kind: "Application",
          size: "19 MB",
          icon: @views.IconName::CodeInline,
          color: rgba8(35, 39, 47),
        },
      ]
    Downloads =>
      [
        {
          name: "MoUI-Handbook.pdf",
          kind: "PDF Document",
          size: "4.8 MB",
          icon: @views.IconName::FileNew,
          color: rgba8(238, 82, 83),
        },
        {
          name: "Tahoe Photos",
          kind: "Folder",
          size: "184 MB",
          icon: @views.IconName::FolderOpen,
          color: rgba8(33, 150, 243),
        },
        {
          name: "Design Assets.zip",
          kind: "Archive",
          size: "72 MB",
          icon: @views.IconName::Save,
          color: rgba8(244, 137, 53),
        },
      ]
  }
}

///|
fn file_icon(
  entry : FileEntry,
  model : DesktopModel,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  let selected = model.selected_file == entry.name
  // Document-style white paper glyph with a small type badge — closer to
  // Finder icon view than solid app-tile squares.
  let glyph = document_glyph(entry, palette)
  @views.container(
    @views.column(
      [
        glyph,
        @views.text(
          entry.name,
          role=@views.TextRole::Caption,
          theme~,
          width=112.0,
          height=34.0,
          align=@text.TextAlign::TextCenter,
        )
        .font(@text.FontSpec::new(size=12.0, weight=500))
        .foreground(palette.foreground),
      ],
      spacing=8.0,
      align=@views.CrossAlign::Center,
    ),
    width=118.0,
    height=118.0,
    background=if selected {
      finder_selection_surface(palette)
    } else {
      rgba8(0, 0, 0, a=0.0)
    },
    corner_radius=10.0,
    padding=6.0,
  )
  .on_tap(SelectFinderItem(entry.name))
  .accessibility_label("Select " + entry.name)
}

///|
fn document_glyph(
  entry : FileEntry,
  palette : DesktopPalette,
) -> @moui.View[Msg] {
  let is_folder = entry.kind == "Folder" || entry.kind == "Application"
  if is_folder {
    @views.container(
      desktop_icon(entry.icon, 30.0, @graphics.Color::white()),
      width=58.0,
      height=50.0,
      background=entry.color,
      corner_radius=12.0,
      border=Some(
        @graphics.BorderStyle::new(
          brush=@graphics.Brush::solid(rgba8(255, 255, 255, a=0.35)),
          width=1.0,
        ),
      ),
      padding=12.0,
    ).shadow(
      @graphics.ShadowStyle::new(
        color=palette.shadow.multiply_alpha(0.35),
        offset=@geometry.Point::new(x=0.0, y=2.0),
        blur_radius=6.0,
        spread=0.0,
      ),
    )
  } else {
    let badge = file_type_badge(entry)
    @views.stack([
      @views.container(
        @views.spacer(min_length=0.0, weight=0.0),
        width=50.0,
        height=62.0,
        background=rgba8(252, 253, 255),
        corner_radius=8.0,
        border=Some(
          @graphics.BorderStyle::new(
            brush=@graphics.Brush::solid(rgba8(190, 198, 210, a=0.90)),
            width=1.0,
          ),
        ),
        padding=0.0,
      ).shadow(
        @graphics.ShadowStyle::new(
          color=palette.shadow.multiply_alpha(0.28),
          offset=@geometry.Point::new(x=0.0, y=2.0),
          blur_radius=5.0,
          spread=0.0,
        ),
      ),
      @views.container(
        @views.text(
          badge,
          role=@views.TextRole::Caption,
          theme=@views.light_theme(),
          width=34.0,
          height=14.0,
          align=@text.TextAlign::TextCenter,
        )
        .font(@text.FontSpec::new(size=9.0, weight=700))
        .foreground(@graphics.Color::white()),
        width=34.0,
        height=16.0,
        background=entry.color,
        corner_radius=3.0,
        padding=1.0,
      )
      .align(alignment=@geometry.Alignment::bottom_leading())
      .offset(dx=8.0, dy=-18.0),
    ]).frame(width=50.0, height=62.0)
  }
}

///|
fn file_type_badge(entry : FileEntry) -> String {
  if entry.name.has_suffix(".md") {
    "MD"
  } else if entry.name.has_suffix(".pdf") {
    "PDF"
  } else if entry.name.has_suffix(".zip") {
    "ZIP"
  } else if entry.name.has_suffix(".txt") {
    "TXT"
  } else if entry.kind == "Application" {
    "APP"
  } else {
    "DOC"
  }
}

///|
fn file_list_row(
  entry : FileEntry,
  model : DesktopModel,
  width : Double,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  let selected = model.selected_file == entry.name
  @views.container(
    @views.row(
      [
        @views.container(
          desktop_icon(entry.icon, 18.0, @graphics.Color::white()),
          width=30.0,
          height=30.0,
          background=entry.color,
          corner_radius=7.0,
          padding=6.0,
        ),
        @views.text(
          entry.name,
          role=@views.TextRole::Body,
          theme~,
          width=(width * 0.48).max(120.0),
          height=30.0,
        ).foreground(palette.foreground),
        @views.text(
          entry.kind,
          role=@views.TextRole::Caption,
          theme~,
          width=(width * 0.25).max(80.0),
          height=30.0,
        ).foreground(palette.muted),
        @views.spacer(min_length=4.0),
        @views.text(
          entry.size,
          role=@views.TextRole::Caption,
          theme~,
          width=66.0,
          height=30.0,
          align=@text.TextAlign::TextEnd,
        ).foreground(palette.muted),
      ],
      spacing=10.0,
      align=@views.CrossAlign::Center,
    ),
    width~,
    height=42.0,
    background=if selected {
      finder_selection_surface(palette)
    } else {
      palette.content
    },
    corner_radius=8.0,
    padding=6.0,
  )
  .on_tap(SelectFinderItem(entry.name))
  .accessibility_label("Select " + entry.name)
}
