///|
/// Content column of a Safari window (toolbar → page content). The shared
/// window shell (titlebar, shadow, grip) lives in `app_window` so multiple
/// windows share identical behavior.
fn safari_body(
  model : DesktopModel,
  metrics : WindowMetrics,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  let body_height = metrics.height - 48.0
  let toolbar_height = if metrics.compact { 94.0 } else { 98.0 }
  let content_height = body_height - toolbar_height
  let toolbar = safari_toolbar(model, metrics, palette, theme, toolbar_height)
  let content = safari_content(
    model,
    metrics.width,
    content_height,
    metrics.compact,
    palette,
    theme,
  )
  @views.column(
    [toolbar, content],
    spacing=0.0,
    align=@views.CrossAlign::Stretch,
  )
}

///|
fn safari_toolbar(
  model : DesktopModel,
  metrics : WindowMetrics,
  palette : DesktopPalette,
  theme : @moui.Theme,
  height : Double,
) -> @moui.View[Msg] {
  let address_width = if metrics.compact {
    (metrics.width - 28.0).max(220.0)
  } else {
    (metrics.width - 236.0).max(320.0)
  }
  let address = @views.container(
    @views.row(
      [
        // macOS Safari address bar: a lock glyph on the left signals the
        // current page is loaded over a secure (https) connection.
        desktop_icon(@views.IconName::Focus, 13.0, palette.muted),
        @views.text_field(
          model.browser_query,
          on_input=value => BrowserQueryChanged(value),
          on_submit=Some(SubmitBrowserQuery),
          placeholder="Search or enter website name",
          theme~,
          width=(address_width - 78.0).max(120.0),
          height=26.0,
        ),
        // Reload button on the right of the address capsule.
        toolbar_icon_button(
          @views.IconName::ArrowRight,
          "Reload current page",
          SubmitBrowserQuery,
          palette,
        ),
      ],
      spacing=6.0,
      align=@views.CrossAlign::Center,
    ),
    width=address_width,
    height=34.0,
    background=safari_address_surface(palette),
    corner_radius=9.0,
    border=Some(safari_control_border(palette)),
    padding=4.0,
  )
  let navigation = if metrics.compact {
    @views.row(
      [address],
      justify=@views.MainAlign::Center,
      align=@views.CrossAlign::Center,
    )
  } else {
    @views.row(
      [
        toolbar_icon_button(
          @views.IconName::ChevronLeft,
          "Back to start page",
          ShowBrowserStartPage,
          palette,
        ),
        toolbar_icon_button(
          @views.IconName::ArrowRight,
          "Go to address",
          SubmitBrowserQuery,
          palette,
        ),
        address,
        toolbar_icon_button(
          @views.IconName::Columns,
          "Open Apps",
          ToggleLauncher,
          palette,
        ),
      ],
      spacing=8.0,
      align=@views.CrossAlign::Center,
    )
  }
  @views.stack([
    @views.container(
      @views.column(
        [
          // macOS Safari multi-tab bar: each tab is a compact capsule with
          // the page title, a close button, and the active tab highlighted
          // with a white card. A trailing + button creates a new tab.
          @views.row(
            [
              safari_tab_bar(model, metrics, theme, palette),
              toolbar_icon_button(
                @views.IconName::Plus,
                "New browser tab",
                NewBrowserTab,
                palette,
              ),
            ],
            spacing=6.0,
            align=@views.CrossAlign::Center,
          ),
          navigation,
        ],
        spacing=8.0,
        align=@views.CrossAlign::Stretch,
      ),
      width=metrics.width,
      height~,
      background=safari_toolbar_surface(palette),
      padding=8.0,
    ),
    @views.container(
      @views.spacer(min_length=0.0, weight=0.0),
      width=metrics.width,
      height=1.0,
      background=safari_chrome_divider(palette),
      padding=0.0,
    ).align(alignment=@geometry.Alignment::bottom_leading()),
  ]).frame(width=metrics.width, height~)
}

///|
fn safari_toolbar_surface(palette : DesktopPalette) -> @graphics.Color {
  if palette.dark {
    rgba8(31, 37, 48, a=0.90)
  } else {
    rgba8(246, 248, 251, a=0.86)
  }
}

///|
fn safari_chrome_divider(palette : DesktopPalette) -> @graphics.Color {
  if palette.dark {
    rgba8(255, 255, 255, a=0.14)
  } else {
    rgba8(185, 192, 201, a=0.64)
  }
}

///|
fn safari_control_border(palette : DesktopPalette) -> @graphics.BorderStyle {
  @graphics.BorderStyle::new(
    brush=@graphics.Brush::solid(
      if palette.dark {
        rgba8(255, 255, 255, a=0.14)
      } else {
        rgba8(178, 186, 197, a=0.58)
      },
    ),
    width=1.0,
  )
}

///|
fn safari_address_surface(palette : DesktopPalette) -> @graphics.Color {
  if palette.dark {
    rgba8(59, 66, 78, a=0.88)
  } else {
    rgba8(255, 255, 255, a=0.72)
  }
}

///|
fn safari_tab_bar(
  model : DesktopModel,
  metrics : WindowMetrics,
  theme : @moui.Theme,
  palette : DesktopPalette,
) -> @moui.View[Msg] {
  let tabs = model.browser_tab_titles
  let active = model.browser_active_tab
  let tab_width = if metrics.compact { 80.0 } else { 120.0 }
  let children : Array[@moui.View[Msg]] = []
  for index in 0..<tabs.length() {
    children.push(
      safari_tab(index, tabs[index], active == index, tab_width, palette, theme),
    )
  }
  @views.row(children, spacing=4.0, align=@views.CrossAlign::Center)
}

///|
fn safari_tab(
  index : Int,
  title : String,
  selected : Bool,
  width : Double,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  let close_width = 16.0
  let inner = @views.row(
    [
      @views.text(
        title,
        role=@views.TextRole::Caption,
        theme~,
        width=width - close_width - 16.0,
        height=22.0,
      )
      .font(
        @text.FontSpec::new(size=11.5, weight=if selected { 560 } else { 480 }),
      )
      .foreground(palette.foreground),
      @views.container(
        @views.text(
          "×",
          role=@views.TextRole::Caption,
          theme~,
          width=close_width,
          height=22.0,
          align=@text.TextAlign::TextCenter,
        ).foreground(palette.muted),
        width=close_width,
        height=22.0,
        padding=0.0,
      )
      .on_tap(CloseBrowserTab(index))
      .accessibility_label("Close tab " + title),
    ],
    spacing=6.0,
    align=@views.CrossAlign::Center,
  )
  @views.container(
    inner,
    width~,
    height=30.0,
    background=if selected {
      safari_selected_tab_surface(palette)
    } else {
      rgba8(0, 0, 0, a=0.0)
    },
    corner_radius=8.0,
    border=Some(safari_control_border(palette)),
    padding=6.0,
  )
  .on_tap(SelectBrowserTab(index))
  .accessibility_label("Switch to tab " + title)
}

///|
fn safari_selected_tab_surface(palette : DesktopPalette) -> @graphics.Color {
  if palette.dark {
    rgba8(66, 73, 86, a=0.86)
  } else {
    rgba8(255, 255, 255, a=0.78)
  }
}

///|
fn safari_page_surface(palette : DesktopPalette) -> @graphics.Color {
  if palette.dark {
    rgba8(31, 38, 49)
  } else {
    rgba8(242, 245, 249)
  }
}

///|
fn safari_card_surface(palette : DesktopPalette) -> @graphics.Color {
  if palette.dark {
    rgba8(50, 57, 69, a=0.84)
  } else {
    rgba8(255, 255, 255, a=0.70)
  }
}

///|
fn safari_favorite_surface(
  color : @graphics.Color,
  palette : DesktopPalette,
) -> @graphics.Color {
  color.multiply_alpha(if palette.dark { 0.72 } else { 0.84 })
}

///|
fn safari_result_url_color(palette : DesktopPalette) -> @graphics.Color {
  if palette.dark {
    rgba8(133, 205, 168)
  } else {
    rgba8(31, 122, 90)
  }
}

///|
fn safari_content(
  model : DesktopModel,
  width : Double,
  height : Double,
  compact : Bool,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  let child = match model.browser_page {
    StartPage => safari_start_page(width, height, compact, palette, theme)
    SearchResults(query) =>
      safari_search_results(query, width, height, compact, palette, theme)
  }
  @views.container(
    child,
    width~,
    height~,
    background=safari_page_surface(palette),
    padding=if compact { 14.0 } else { 24.0 },
  )
}

///|
fn safari_start_page(
  width : Double,
  height : Double,
  compact : Bool,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  let inner_width = (width - (if compact { 28.0 } else { 48.0 })).max(220.0)
  let favorite_width = if compact { 104.0 } else { 128.0 }
  let favorites = @views.responsive_grid(
    [
      favorite_card(
        "MoUI",
        "https://wzzc-dev.github.io/MoUI",
        @views.IconName::Columns,
        rgba8(39, 110, 241),
        favorite_width,
        palette,
        theme,
      ),
      favorite_card(
        "MoonBit",
        "moonbitlang.com",
        @views.IconName::CodeInline,
        rgba8(113, 82, 228),
        favorite_width,
        palette,
        theme,
      ),
      favorite_card(
        "Docs",
        "docs.https://wzzc-dev.github.io/MoUI",
        @views.IconName::ListBullet,
        rgba8(24, 151, 132),
        favorite_width,
        palette,
        theme,
      ),
      favorite_card(
        "Tahoe",
        "Lake Tahoe",
        @views.IconName::FolderOpen,
        rgba8(232, 132, 48),
        favorite_width,
        palette,
        theme,
      ),
    ],
    width=inner_width,
    min_column_width=favorite_width,
    row_spacing=12.0,
    column_spacing=14.0,
  )
  let reports = if compact {
    browser_report_card(
      "Privacy Report",
      "17 trackers blocked this week",
      @views.IconName::Focus,
      inner_width,
      palette,
      theme,
    )
  } else {
    @views.row(
      [
        browser_report_card(
          "Privacy Report",
          "17 trackers blocked this week",
          @views.IconName::Focus,
          (inner_width - 14.0) / 2.0,
          palette,
          theme,
        ),
        browser_report_card(
          "Reading List",
          "Liquid Glass: Designing for Depth",
          @views.IconName::ListTask,
          (inner_width - 14.0) / 2.0,
          palette,
          theme,
        ),
      ],
      spacing=14.0,
      align=@views.CrossAlign::Stretch,
    )
  }
  @views.column(
    [
      @views.text(
        "Favorites",
        role=@views.TextRole::Title,
        theme~,
        width=inner_width,
        height=34.0,
      )
      .font(@text.FontSpec::new(size=22.0, weight=650))
      .foreground(palette.foreground),
      favorites,
      @views.text(
        "Frequently Visited",
        role=@views.TextRole::Title,
        theme~,
        width=inner_width,
        height=32.0,
      )
      .font(@text.FontSpec::new(size=18.0, weight=620))
      .foreground(palette.foreground),
      @views.row(
        [
          compact_site("m", "https://wzzc-dev.github.io/MoUI", "https://wzzc-dev.github.io/MoUI", palette, theme),
          compact_site("d", "docs", "docs.https://wzzc-dev.github.io/MoUI", palette, theme),
          compact_site("g", "github", "github.com", palette, theme),
        ],
        spacing=12.0,
        align=@views.CrossAlign::Start,
      ),
      reports,
    ],
    spacing=12.0,
    align=@views.CrossAlign::Start,
  ).frame(width=inner_width, height=height - 20.0)
}

///|
fn favorite_card(
  label : String,
  query : String,
  icon : @views.IconName,
  color : @graphics.Color,
  width : Double,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  @views.column(
    [
      @views.container(
        desktop_icon(icon, 30.0, @graphics.Color::white()),
        width~,
        height=70.0,
        background=safari_favorite_surface(color, palette),
        corner_radius=12.0,
        border=Some(safari_control_border(palette)),
        padding=18.0,
      ),
      @views.text(
        label,
        role=@views.TextRole::Caption,
        theme~,
        width~,
        height=20.0,
        align=@text.TextAlign::TextCenter,
      ).foreground(palette.foreground),
    ],
    spacing=5.0,
    align=@views.CrossAlign::Center,
  )
  .on_tap(OpenFavorite(query))
  .accessibility_label("Open " + label)
}

///|
fn compact_site(
  initial : String,
  label : String,
  query : String,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  @views.column(
    [
      @views.container(
        @views.text(
          initial,
          role=@views.TextRole::Title,
          theme~,
          width=48.0,
          height=38.0,
          align=@text.TextAlign::TextCenter,
        ).foreground(palette.foreground),
        width=52.0,
        height=48.0,
        background=safari_card_surface(palette),
        corner_radius=10.0,
        border=Some(safari_control_border(palette)),
        padding=5.0,
      ),
      @views.text(
        label,
        role=@views.TextRole::Caption,
        theme~,
        width=72.0,
        height=18.0,
        align=@text.TextAlign::TextCenter,
      ).foreground(palette.muted),
    ],
    spacing=4.0,
    align=@views.CrossAlign::Center,
  )
  .on_tap(OpenFavorite(query))
  .accessibility_label("Open " + label)
}

///|
fn browser_report_card(
  title : String,
  detail : String,
  icon : @views.IconName,
  width : Double,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  solid_panel(
    @views.column(
      [
        @views.row(
          [
            desktop_icon(icon, 18.0, palette.accent),
            @views.text(
              title,
              role=@views.TextRole::Label,
              theme~,
              width=(width - 66.0).max(100.0),
              height=24.0,
            ).foreground(palette.foreground),
          ],
          spacing=8.0,
          align=@views.CrossAlign::Center,
        ),
        @views.text(
          detail,
          role=@views.TextRole::Body,
          theme~,
          width=(width - 32.0).max(100.0),
          height=42.0,
        ).foreground(palette.muted),
      ],
      spacing=8.0,
      align=@views.CrossAlign::Start,
    ),
    width,
    94.0,
    palette,
    background=safari_card_surface(palette),
    radius=12.0,
    padding=14.0,
  )
}

///|
fn safari_search_results(
  query : String,
  width : Double,
  height : Double,
  compact : Bool,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  let inner_width = (width - (if compact { 28.0 } else { 64.0 })).max(220.0)
  @views.column(
    [
      @views.row(
        [
          @views.column(
            [
              @views.text(
                "Search results",
                role=@views.TextRole::Title,
                theme~,
                width=(inner_width - 140.0).max(140.0),
                height=32.0,
              )
              .font(@text.FontSpec::new(size=22.0, weight=650))
              .foreground(palette.foreground),
              @views.text(
                "Results for \"\{query}\"",
                role=@views.TextRole::Caption,
                theme~,
                width=(inner_width - 140.0).max(140.0),
                height=22.0,
              ).foreground(palette.muted),
            ],
            spacing=0.0,
            align=@views.CrossAlign::Start,
          ),
          @views.spacer(min_length=8.0),
          @views.button(
            "Start Page",
            on_click=ShowBrowserStartPage,
            variant=@views.ButtonVariant::Tonal,
            theme~,
            width=112.0,
            height=36.0,
          ),
        ],
        spacing=8.0,
        align=@views.CrossAlign::Center,
      ),
      browser_result(
        "MoUI desktop patterns", "https://wzzc-dev.github.io/MoUI/examples/mo-desktop", "Build platform-neutral desktop experiences with typed model, update, and view logic.",
        inner_width, palette, theme,
      ),
      browser_result(
        "MoonBit language guide", "moonbitlang.com/docs", "Explore the language, package model, tooling, and native/Web backends.",
        inner_width, palette, theme,
      ),
      browser_result(
        "Lake Tahoe field notes", "notes.local/tahoe", "A quiet collection of shoreline walks, weather, and photography plans.",
        inner_width, palette, theme,
      ),
    ],
    spacing=12.0,
    align=@views.CrossAlign::Stretch,
  ).frame(width=inner_width, height=height - 20.0)
}

///|
fn browser_result(
  title : String,
  url : String,
  detail : String,
  width : Double,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  solid_panel(
    @views.column(
      [
        @views.text(
          title,
          role=@views.TextRole::Title,
          theme~,
          width=width - 32.0,
          height=28.0,
        )
        .font(@text.FontSpec::new(size=17.0, weight=620))
        .foreground(palette.accent),
        @views.text(
          url,
          role=@views.TextRole::Caption,
          theme~,
          width=width - 32.0,
          height=20.0,
        ).foreground(safari_result_url_color(palette)),
        @views.text(
          detail,
          role=@views.TextRole::Body,
          theme~,
          width=width - 32.0,
          height=34.0,
        ).foreground(palette.muted),
      ],
      spacing=3.0,
      align=@views.CrossAlign::Start,
    ),
    width,
    98.0,
    palette,
    background=safari_card_surface(palette),
    radius=12.0,
    padding=14.0,
  )
  .on_tap(OpenFavorite(url))
  .accessibility_label("Open " + title + " in Safari")
}
