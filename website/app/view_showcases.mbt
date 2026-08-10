///|
priv struct WebsiteShowcaseEntry {
  slug : String
  title_key : String
  subtitle_key : String
  status_key : String
  source_url : String
}

///|
fn website_showcase_entries() -> Array[WebsiteShowcaseEntry] {
  [
    {
      slug: "showcase",
      title_key: "showcase.showcase.title",
      subtitle_key: "showcase.showcase.subtitle",
      status_key: "showcase.status.archived",
      source_url: "https://github.com/wzzc-dev/MoUI/tree/main/examples/showcase/app",
    },
    {
      slug: "ios-componentgallery",
      title_key: "showcase.ios.title",
      subtitle_key: "showcase.ios.subtitle",
      status_key: "showcase.status.pending",
      source_url: "https://github.com/wzzc-dev/MoUI/tree/main/examples/showcase/ios_window_hosted",
    },
    {
      slug: "harmonyos-componentgallery",
      title_key: "showcase.harmonyos.title",
      subtitle_key: "showcase.harmonyos.subtitle",
      status_key: "showcase.status.pending",
      source_url: "https://github.com/wzzc-dev/MoUI/tree/main/examples/showcase/harmonyos_window_hosted",
    },
    {
      slug: "markdown_editor",
      title_key: "showcase.markdown.title",
      subtitle_key: "showcase.markdown.subtitle",
      status_key: "showcase.status.source",
      source_url: "https://github.com/wzzc-dev/MoUI/tree/main/examples/markdown_editor/app",
    },
    {
      slug: "mo_workbench",
      title_key: "showcase.workbench.title",
      subtitle_key: "showcase.workbench.subtitle",
      status_key: "showcase.status.source",
      source_url: "https://github.com/wzzc-dev/MoUI/tree/main/examples/mo_workbench/app",
    },
    {
      slug: "excel",
      title_key: "showcase.excel.title",
      subtitle_key: "showcase.excel.subtitle",
      status_key: "showcase.status.source",
      source_url: "https://github.com/wzzc-dev/MoUI/tree/main/examples/excel/app",
    },
    {
      slug: "webview",
      title_key: "showcase.webview.title",
      subtitle_key: "showcase.webview.subtitle",
      status_key: "showcase.status.source",
      source_url: "https://github.com/wzzc-dev/MoUI/tree/main/examples/webview_demo/app",
    },
    {
      slug: "android-componentgallery",
      title_key: "showcase.android.title",
      subtitle_key: "showcase.android.subtitle",
      status_key: "showcase.status.pending",
      source_url: "https://github.com/wzzc-dev/MoUI/tree/main/examples/showcase/android_window_hosted",
    },
  ]
}

///|
fn website_live_demo_urls() -> Array[String] {
  [
    "https://wzzc-dev.github.io/MoUI/showcase/", "https://wzzc-dev.github.io/MoUI/markdown-editor/",
    "https://wzzc-dev.github.io/MoUI/playground",
  ]
}

///|
fn Model::showcases_content(
  self : Model,
  theme : @moui.Theme,
  metrics : Metrics,
) -> @moui.View[Msg] {
  let message = key => website_message(self.locale, key)
  let card_width = if metrics.compact {
    metrics.content_width
  } else {
    clamp_website_double((metrics.content_width - 32.0) / 2.0, 360.0, 540.0)
  }
  let thumb_height = card_width * 0.56
  let entries = website_showcase_entries()
  let columns = if metrics.compact { 1 } else { 2 }
  let card_height = thumb_height + 134.0
  // The top navigation already identifies this route. Retain the concise
  // explanatory copy, without duplicating that title above the grid.
  let section_inset = if metrics.compact { 24.0 } else { 32.0 }
  let intro_height = 64.0
  let link_height = 30.0
  let links_height = link_height * 3.0 + 6.0 * 2.0
  let grid_height = max_website_double(
    60.0,
    metrics.body_height -
    section_inset * 2.0 -
    intro_height -
    16.0 -
    links_height -
    16.0,
  )
  section_shell(
    theme,
    metrics,
    column(
      [
        column(
          [
            text(
              message("showcases.summary"),
              width=metrics.content_width,
              height=30.0,
            )
            .font(@text.FontSpec::new(size=15.0, weight=520))
            .foreground(theme.palette.muted),
            text(
              message("showcases.description"),
              width=metrics.content_width,
              height=30.0,
            )
            .font(theme.typography.caption)
            .foreground(theme.palette.muted),
          ],
          spacing=4.0,
          align=@views.CrossAlign::Start,
        ),
        lazy_grid(
          entries,
          entry => entry.slug,
          entry => {
            showcase_card(theme, entry, card_width, thumb_height, self.locale)
          },
          columns~,
          item_height=card_height,
          viewport_width=metrics.content_width,
          viewport_height=grid_height,
          row_spacing=20.0,
          column_spacing=16.0,
          offset=self.showcase_grid_scroll,
          on_scroll=Some(offset => ShowcaseGridScrolled(offset)),
          shows_indicator=true,
        ),
        column(
          website_live_demo_urls().map(url => {
            container(
              text(
                url,
                width=metrics.content_width,
                height=link_height,
                align=@core.TextAlign::TextStart,
              )
              .font(theme.typography.caption)
              .foreground(theme.palette.primary),
              width=metrics.content_width,
              height=link_height,
            )
            .on_tap(OpenLiveDemo(url))
            .semantics_role(@core.SemanticsRole::Link)
            .semantics_url(url)
            .accessibility_label(
              website_message_with(self.locale, "action.open_demo", [
                ("url", url),
              ]),
            )
          }),
          spacing=6.0,
          align=@views.CrossAlign::Start,
        ),
      ],
      spacing=16.0,
      align=@views.CrossAlign::Start,
    ),
    top=section_inset,
    bottom=section_inset,
    background=Some(showcase_section_background(theme)),
  )
}

///|
fn showcase_card(
  theme : @moui.Theme,
  entry : WebsiteShowcaseEntry,
  width : Double,
  thumb_height : Double,
  locale : String,
) -> @moui.View[Msg] {
  let source_url = entry.source_url
  let slug = entry.slug
  let title = website_message(locale, entry.title_key)
  let subtitle = website_message(locale, entry.subtitle_key)
  let status = website_message(locale, entry.status_key)
  container(
    column(
      [
        container(
          image(
            showcase_image_source(slug),
            width=width - 2.0,
            height=thumb_height,
            fit=@graphics.ImageFit::Contain,
          )
          .on_tap(OpenShowcaseSource(source_url))
          .semantics_role(@core.SemanticsRole::Link)
          .semantics_url(source_url)
          .accessibility_label(
            website_message_with(locale, "action.open_source_for", [
              ("title", title),
            ]),
          ),
          width~,
          height=thumb_height,
          corner_radius=8.0,
          theme~,
          padding=0.0,
        ),
        column(
          [
            text(title, width=width - 32.0, height=28.0)
            .font(theme.typography.control)
            .foreground(theme.palette.foreground),
            text(subtitle, width=width - 32.0, height=22.0)
            .font(theme.typography.caption)
            .foreground(theme.palette.muted),
            text(status, width=width - 32.0, height=18.0)
            .font(theme.typography.caption)
            .foreground(theme.palette.muted),
          ],
          spacing=4.0,
          align=@views.CrossAlign::Start,
        ),
        button(
          website_message(locale, "action.open_source"),
          on_click=OpenShowcaseSource(source_url),
          variant=@views.ButtonVariant::Outline,
          theme~,
          width=width - 32.0,
          height=36.0,
        ).accessibility_label(
          website_message_with(locale, "action.open_source_for", [
            ("title", title),
          ]),
        ),
      ],
      spacing=10.0,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height=thumb_height + 134.0,
    background=theme.palette.background,
    corner_radius=8.0,
    theme~,
    padding=1.0,
  ).border(website_border(theme))
}
