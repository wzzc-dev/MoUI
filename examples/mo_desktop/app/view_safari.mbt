///|
fn safari_window(
  model : DesktopModel,
  palette : DesktopPalette,
  theme : @moui.Theme,
  viewport_width : Double,
  viewport_height : Double,
) -> @moui.View[Msg] {
  let metrics = window_metrics(model, viewport_width, viewport_height)
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
  app_window(
    model,
    match model.browser_page {
      StartPage => "Start Page"
      SearchResults(_) => "Mo Browser"
    },
    @views.column(
      [toolbar, content],
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
  let address = @views.text_field(
    model.browser_query,
    on_input=value => BrowserQueryChanged(value),
    on_submit=Some(SubmitBrowserQuery),
    placeholder="Search or enter website name",
    theme~,
    width=address_width,
    height=38.0,
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
          "Reload page",
          SubmitBrowserQuery,
          palette,
        ),
        address,
        toolbar_icon_button(
          @views.IconName::Columns,
          "Show tabs",
          ToggleLauncher,
          palette,
        ),
      ],
      spacing=8.0,
      align=@views.CrossAlign::Center,
    )
  }
  @views.container(
    @views.column(
      [
        @views.row(
          [
            @views.container(
              @views.row(
                [
                  desktop_icon(@views.IconName::Link, 14.0, palette.accent),
                  @views.text(
                    match model.browser_page {
                      StartPage => "Start Page"
                      SearchResults(value) => value
                    },
                    role=@views.TextRole::Caption,
                    theme~,
                    width=if metrics.compact { 180.0 } else { 250.0 },
                    height=24.0,
                  ).foreground(palette.foreground),
                ],
                spacing=8.0,
                align=@views.CrossAlign::Center,
              ),
              width=if metrics.compact { 220.0 } else { 292.0 },
              height=30.0,
              background=palette.content,
              corner_radius=9.0,
              padding=6.0,
            ),
            @views.spacer(min_length=8.0),
            toolbar_icon_button(
              @views.IconName::Plus,
              "New start page",
              ShowBrowserStartPage,
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
    background=palette.glass_strong,
    padding=8.0,
  )
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
    background=if model.dark_mode {
      rgba8(31, 39, 50)
    } else {
      rgba8(227, 240, 245)
    },
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
        "moui.dev",
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
        "docs.moui.dev",
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
          compact_site("m", "moui.dev", palette, theme),
          compact_site("d", "docs", palette, theme),
          compact_site("g", "github", palette, theme),
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
        background=color,
        corner_radius=14.0,
        border=Some(desktop_hairline(palette)),
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
        background=palette.glass_strong,
        corner_radius=11.0,
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
    radius=14.0,
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
        "MoUI desktop patterns", "moui.dev/examples/mo-desktop", "Build platform-neutral desktop experiences with typed model, update, and view logic.",
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
        ).foreground(rgba8(25, 150, 94)),
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
    radius=12.0,
    padding=14.0,
  )
}
