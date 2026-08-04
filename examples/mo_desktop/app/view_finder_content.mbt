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
          [
            file_list_header(inner_width, palette, theme),
            @views.column(
              entries.map(entry => {
                file_list_row(entry, model, inner_width, palette, theme)
              }),
              spacing=2.0,
              align=@views.CrossAlign::Stretch,
            ),
          ],
          spacing=4.0,
          align=@views.CrossAlign::Stretch,
        )
    }
  }
  let inner = @views.padding_edges(
    content,
    left=14.0,
    top=14.0,
    bottom=14.0,
    right=14.0,
  )
  @views.column([inner], spacing=0.0, align=@views.CrossAlign::Start)
  .frame(width~, height~)
  .background(palette.content)
}

///|
fn finder_status(
  model : DesktopModel,
  width : Double,
  height : Double,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  // macOS Finder bottom status bar: item count on the left, available space
  // on the right, separated by a hairline divider above.
  let count = visible_finder_entries(model).length()
  let left_label = if model.selected_file == "" {
    "\{count} items"
  } else {
    "Selected: \{model.selected_file}"
  }
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
          @views.text(
            left_label,
            role=@views.TextRole::Caption,
            theme~,
            width=(width * 0.5).max(120.0),
            height=18.0,
          )
          .font(@text.FontSpec::new(size=11.0, weight=520))
          .foreground(palette.muted),
          @views.spacer(min_length=8.0, weight=1.0),
          @views.text(
            "214.3 GB available",
            role=@views.TextRole::Caption,
            theme~,
            width=140.0,
            height=18.0,
            align=@text.TextAlign::TextEnd,
          )
          .font(@text.FontSpec::new(size=11.0, weight=520))
          .foreground(palette.muted),
        ],
        spacing=8.0,
        align=@views.CrossAlign::Center,
      ),
      left=14.0,
      top=3.0,
      bottom=3.0,
      right=14.0,
    ),
  ]).frame(width~, height~)
}

///|
fn visible_finder_entries(model : DesktopModel) -> Array[FileEntry] {
  let entries = finder_entries(model.finder_location)
  if model.finder_location == Documents {
    for path in model.imported_files {
      entries.push({
        name: path,
        kind: "Imported from host",
        size: "External",
        date: "Today",
        icon: @views.IconName::FileNew,
        color: rgba8(91, 143, 249),
      })
    }
  }
  entries.filter(entry => {
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
          date: "Jul 22, 2026",
          icon: @views.IconName::FileNew,
          color: rgba8(91, 143, 249),
        },
        {
          name: "Q3 Plan.txt",
          kind: "Text Document",
          size: "22 KB",
          date: "Jul 19, 2026",
          icon: @views.IconName::FileNew,
          color: rgba8(121, 103, 238),
        },
        {
          name: "Reading List.md",
          kind: "Markdown",
          size: "8 KB",
          date: "Jul 12, 2026",
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
          date: "Jul 24, 2026",
          icon: @views.IconName::Link,
          color: rgba8(36, 177, 216),
        },
        {
          name: "Notes",
          kind: "Application",
          size: "31 MB",
          date: "Jul 18, 2026",
          icon: @views.IconName::ListTask,
          color: rgba8(250, 194, 55),
        },
        {
          name: "Settings",
          kind: "Application",
          size: "26 MB",
          date: "Jul 21, 2026",
          icon: @views.IconName::Settings,
          color: rgba8(104, 112, 124),
        },
        {
          name: "Terminal",
          kind: "Application",
          size: "19 MB",
          date: "Jul 15, 2026",
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
          date: "Jul 26, 2026",
          icon: @views.IconName::FileNew,
          color: rgba8(238, 82, 83),
        },
        {
          name: "Tahoe Photos",
          kind: "Folder",
          size: "184 MB",
          date: "Jul 23, 2026",
          icon: @views.IconName::FolderOpen,
          color: rgba8(33, 150, 243),
        },
        {
          name: "Design Assets.zip",
          kind: "Archive",
          size: "72 MB",
          date: "Jul 20, 2026",
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
fn file_list_header(
  width : Double,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  // macOS Finder list-view header: small uppercase muted column labels with a
  // bottom rule. Column widths mirror `file_list_row` so labels align.
  let name_w = (width * 0.40).max(120.0)
  let date_w = (width * 0.22).max(96.0)
  let kind_w = (width * 0.20).max(72.0)
  let size_w = 66.0
  @views.column(
    [
      @views.row(
        [
          @views.text(
            "Name",
            role=@views.TextRole::Caption,
            theme~,
            width=name_w,
            height=18.0,
          )
          .font(@text.FontSpec::new(size=10.0, weight=700))
          .foreground(palette.muted),
          @views.text(
            "Date Modified",
            role=@views.TextRole::Caption,
            theme~,
            width=date_w,
            height=18.0,
          )
          .font(@text.FontSpec::new(size=10.0, weight=700))
          .foreground(palette.muted),
          @views.text(
            "Kind",
            role=@views.TextRole::Caption,
            theme~,
            width=kind_w,
            height=18.0,
          )
          .font(@text.FontSpec::new(size=10.0, weight=700))
          .foreground(palette.muted),
          @views.spacer(min_length=4.0, weight=1.0),
          @views.text(
            "Size",
            role=@views.TextRole::Caption,
            theme~,
            width=size_w,
            height=18.0,
            align=@text.TextAlign::TextEnd,
          )
          .font(@text.FontSpec::new(size=10.0, weight=700))
          .foreground(palette.muted),
        ],
        spacing=10.0,
        align=@views.CrossAlign::Center,
      ),
      @views.container(
        @views.spacer(min_length=0.0, weight=0.0),
        width~,
        height=1.0,
        background=palette.outline.multiply_alpha(0.55),
        padding=0.0,
      ),
    ],
    spacing=4.0,
    align=@views.CrossAlign::Stretch,
  )
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
          width=(width * 0.40).max(120.0),
          height=30.0,
        ).foreground(palette.foreground),
        @views.text(
          entry.date,
          role=@views.TextRole::Caption,
          theme~,
          width=(width * 0.22).max(96.0),
          height=30.0,
        ).foreground(palette.muted),
        @views.text(
          entry.kind,
          role=@views.TextRole::Caption,
          theme~,
          width=(width * 0.20).max(72.0),
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
