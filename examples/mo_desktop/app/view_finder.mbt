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
  let body_height = metrics.height - 48.0
  let toolbar_height = if metrics.compact { 94.0 } else { 58.0 }
  let status_height = 26.0
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
  let mode = @views.segmented_control(
    [@views.choice_item("icons", "Icons"), @views.choice_item("list", "List")],
    selected=model.finder_view_mode.id(),
    on_select=value => SelectFinderView(value),
    theme~,
    width=164.0,
  )
  let search_width = if metrics.compact {
    (metrics.width - 28.0).max(220.0)
  } else {
    220.0
  }
  let search = @views.text_field(
    model.finder_query,
    on_input=value => FinderQueryChanged(value),
    placeholder="Search files",
    theme~,
    width=search_width,
    height=36.0,
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
        @views.container(
          desktop_icon(@views.IconName::ChevronLeft, 16.0, palette.muted),
          width=34.0,
          height=34.0,
          background=rgba8(0, 0, 0, a=0.0),
          corner_radius=8.0,
          padding=8.0,
        ).accessibility_label("Back (unavailable)"),
        @views.container(
          desktop_icon(@views.IconName::ChevronRight, 16.0, palette.muted),
          width=34.0,
          height=34.0,
          background=rgba8(0, 0, 0, a=0.0),
          corner_radius=8.0,
          padding=8.0,
        ).accessibility_label("Forward (unavailable)"),
        mode,
        @views.spacer(min_length=10.0),
        toolbar_icon_button(
          @views.IconName::Settings,
          "Finder actions",
          ToggleControlCenter,
          palette,
        ),
        search,
      ],
      spacing=8.0,
      align=@views.CrossAlign::Center,
    )
  }
  @views.container(
    content,
    width=metrics.width,
    height~,
    background=palette.glass_strong,
    padding=12.0,
  )
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
          height=20.0,
        ).foreground(palette.muted),
        finder_sidebar_button(
          "Documents",
          Documents,
          model,
          width - 24.0,
          theme,
        ),
        finder_sidebar_button(
          "Applications",
          Applications,
          model,
          width - 24.0,
          theme,
        ),
        finder_sidebar_button(
          "Downloads",
          Downloads,
          model,
          width - 24.0,
          theme,
        ),
        @views.spacer(min_length=14.0, weight=0.0),
        @views.text(
          "Locations",
          role=@views.TextRole::Caption,
          theme~,
          width=width - 28.0,
          height=20.0,
        ).foreground(palette.muted),
        sidebar_static_row("MacBook", palette, theme, width - 24.0),
        sidebar_static_row("Cloud Drive", palette, theme, width - 24.0),
        sidebar_static_row("Network", palette, theme, width - 24.0),
      ],
      spacing=4.0,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height~,
    background=palette.sidebar,
    padding=12.0,
  )
}

///|
fn finder_sidebar_button(
  label : String,
  location : FinderLocation,
  model : DesktopModel,
  width : Double,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  @views.button(
    label,
    on_click=SelectFinderLocation(location),
    variant=if model.finder_location == location {
      @views.ButtonVariant::Tonal
    } else {
      @views.ButtonVariant::Ghost
    },
    theme~,
    width~,
    height=36.0,
  )
}

///|
fn sidebar_static_row(
  label : String,
  palette : DesktopPalette,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[Msg] {
  @views.text(label, role=@views.TextRole::Body, theme~, width~, height=30.0).foreground(
    palette.foreground,
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
    background=palette.glass_strong,
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
  @views.container(
    @views.column(
      [
        @views.container(
          desktop_icon(entry.icon, 28.0, @graphics.Color::white()),
          width=62.0,
          height=62.0,
          background=entry.color,
          corner_radius=14.0,
          padding=16.0,
        ),
        @views.text(
          entry.name,
          role=@views.TextRole::Caption,
          theme~,
          width=112.0,
          height=34.0,
          align=@text.TextAlign::TextCenter,
        )
        .font(@text.FontSpec::new(size=12.0, weight=520))
        .foreground(palette.foreground),
      ],
      spacing=6.0,
      align=@views.CrossAlign::Center,
    ),
    width=118.0,
    height=112.0,
    background=if selected { palette.accent_soft } else { palette.content },
    corner_radius=10.0,
    padding=6.0,
  )
  .on_tap(SelectFinderItem(entry.name))
  .accessibility_label("Select " + entry.name)
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
    background=if selected { palette.accent_soft } else { palette.content },
    corner_radius=8.0,
    padding=6.0,
  )
  .on_tap(SelectFinderItem(entry.name))
  .accessibility_label("Select " + entry.name)
}
