///|
fn Model::docs_content(
  self : Model,
  theme : @moui.Theme,
  metrics : Metrics,
) -> @moui.View[Msg] {
  let message = key => website_message(self.locale, key)
  let doc_width = if metrics.docs_compact {
    metrics.content_width
  } else {
    metrics.content_width - metrics.docs_sidebar_width - 24.0
  }
  let content = if metrics.docs_compact {
    let summary_height = website_doc_wrap_lines(
        docs_header_summary(self.locale),
        metrics.content_width,
        13.0,
      )
      .length()
      .to_double() *
      20.0
    let workspace_height = max_website_double(
      280.0,
      metrics.body_height - 210.0 - summary_height,
    )
    column(
      [
        docs_header(theme, metrics.content_width, self.locale),
        button(
          message("docs.button"),
          on_click=ToggleDocsDrawer,
          variant=@views.ButtonVariant::Outline,
          theme~,
          width=metrics.content_width,
          height=42.0,
        ).semantics_expanded(expanded=self.docs_drawer_open),
        self.docs_document_panel(
          theme,
          doc_width,
          workspace_height,
          independent_scroll=true,
        ),
      ],
      spacing=18.0,
      align=@views.CrossAlign::Start,
    )
  } else {
    let workspace_height = max_website_double(
      240.0,
      metrics.body_height - 192.0,
    )
    column(
      [
        docs_header(theme, metrics.content_width, self.locale),
        row(
          [
            self.docs_sidebar(
              theme,
              metrics.docs_sidebar_width,
              workspace_height,
            ),
            self.docs_document_panel(
              theme,
              doc_width,
              workspace_height,
              independent_scroll=true,
            ),
          ],
          spacing=24.0,
          align=@views.CrossAlign::Start,
        ),
      ],
      spacing=20.0,
      align=@views.CrossAlign::Start,
    )
  }
  section_shell(
    theme,
    metrics,
    content,
    top=34.0,
    bottom=if metrics.docs_compact { 24.0 } else { 34.0 },
    background=Some(theme.palette.surface_variant.multiply_alpha(0.28)),
  )
}

///|
fn docs_header(
  theme : @moui.Theme,
  width : Double,
  locale : String,
) -> @moui.View[Msg] {
  let message = key => website_message(locale, key)
  column(
    [
      badge(
        message("docs.badge"),
        tone=@views.BadgeTone::Accent,
        theme~,
        width=112.0,
      ),
      docs_start_text(
        message("docs.title"),
        width~,
        height=38.0,
        font=@text.FontSpec::new(size=30.0, weight=820),
        color=theme.palette.foreground,
      )
      .semantics_role(@core.SemanticsRole::Heading)
      .semantics_level(1),
      docs_wrapped_text(
        theme,
        docs_header_summary(locale),
        width,
        13.0,
        20.0,
        muted=true,
      ),
    ],
    spacing=6.0,
    align=@views.CrossAlign::Start,
  )
}

///|
fn docs_header_summary(locale : String) -> String {
  website_message(locale, "docs.summary")
}

///|
fn Model::docs_sidebar(
  self : Model,
  theme : @moui.Theme,
  width : Double,
  max_height : Double,
) -> @moui.View[Msg] {
  let message = key => website_message(self.locale, key)
  let content_width = width - 28.0
  let groups : Array[@moui.View[Msg]] = []
  match self.website_catalog() {
    Some(catalog) => {
      let filtered = catalog.filtered_entries(self.docs_search)
      for group in catalog.groups {
        let rows : Array[@moui.View[Msg]] = []
        for entry in filtered {
          if entry.group == group.id {
            let selected = entry.slug == self.selected_doc_slug
            rows.push(
              frame(
                padding_edges(
                  text(
                    entry.title,
                    width=content_width - 16.0,
                    height=36.0,
                    align=@text.TextAlign::TextStart,
                  )
                  .font(@text.FontSpec::new(size=13.0, weight=680))
                  .foreground(
                    if selected {
                      theme.palette.primary
                    } else {
                      theme.palette.foreground
                    },
                  ),
                  right=8.0,
                  left=8.0,
                ),
                width=content_width,
                height=36.0,
              )
              .on_tap(SelectDoc(entry.slug))
              .accessibility_label(
                website_message_with(self.locale, "docs.open", [
                  ("title", entry.title),
                ]),
              )
              .semantics_role(@core.SemanticsRole::Link)
              .semantics_url("docs/" + entry.slug)
              .key("docs-nav-" + entry.slug),
            )
          }
        }
        if !rows.is_empty() {
          groups.push(
            column(
              [
                docs_start_text(
                  group.title,
                  width=content_width,
                  height=24.0,
                  font=@text.FontSpec::new(size=13.0, weight=760),
                  color=theme.palette.muted,
                )
                .semantics_role(@core.SemanticsRole::Heading)
                .semantics_level(2),
                column(rows, spacing=2.0, align=@views.CrossAlign::Start),
              ],
              spacing=4.0,
              align=@views.CrossAlign::Start,
            ),
          )
        }
      }
      if groups.is_empty() {
        groups.push(
          docs_start_text(
            message("docs.no_results"),
            width=content_width,
            height=24.0,
            font=theme.typography.caption,
            color=theme.palette.muted,
          ),
        )
      }
    }
    None => ()
  }
  let catalog_content = column(
    groups,
    spacing=12.0,
    align=@views.CrossAlign::Start,
  )
  let list_height = max_website_double(120.0, max_height - 92.0)
  container(
    column(
      [
        text_field(
          self.docs_search,
          on_input=value => SearchDocs(value),
          placeholder=message("docs.search"),
          variant=@views.TextFieldVariant::Outline,
          theme~,
          width=content_width,
          height=40.0,
        ).accessibility_label(message("docs.search_a11y")),
        scroll_view(
          catalog_content,
          width=content_width,
          height=list_height,
          offset=self.docs_body_scroll,
          on_scroll=Some(offset => DocsBodyScrolled(offset)),
          shows_indicator=true,
        ),
      ],
      spacing=12.0,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height=max_height,
    background=soft_panel_background(theme),
    corner_radius=8.0,
    theme~,
    padding=14.0,
  )
  .border(website_border(theme))
  .semantics_role(@core.SemanticsRole::Navigation)
  .accessibility_label(message("docs.navigation"))
}

///|
fn Model::docs_document_panel(
  self : Model,
  theme : @moui.Theme,
  width : Double,
  viewport_height : Double,
  independent_scroll~ : Bool,
) -> @moui.View[Msg] {
  match self.catalog_state {
    CatalogNotLoaded | CatalogLoading(_) =>
      docs_status_panel(
        theme,
        width,
        website_message(self.locale, "docs.loading_catalog"),
        website_message(self.locale, "docs.reading_catalog"),
        RetryCatalog,
        website_message(self.locale, "action.retry"),
      )
    CatalogFailed(reason) =>
      docs_status_panel(
        theme,
        width,
        website_message(self.locale, "docs.catalog_failed"),
        reason,
        RetryCatalog,
        website_message(self.locale, "action.retry"),
      )
    CatalogLoaded(catalog) =>
      match catalog.entry_by_slug(self.selected_doc_slug) {
        None =>
          docs_not_found_panel(
            theme,
            width,
            self.selected_doc_slug,
            self.locale,
          )
        Some(entry) =>
          match self.doc_state {
            DocLoaded(_, document) => {
              let content_width = width - 40.0
              let document_summary_height = website_doc_wrap_lines(
                  entry.summary,
                  content_width,
                  13.0,
                )
                .length()
                .to_double() *
                21.0
              let document_viewport_height = if independent_scroll {
                max_website_double(
                  64.0,
                  viewport_height - 142.0 - document_summary_height,
                )
              } else {
                0.0
              }
              let viewer = @moui_richtext.markdown_viewer(
                source=document.source,
                size=@core.Size::new(width=content_width, height=0.0),
                font=@text.FontSpec::new(size=14.5),
                foreground=theme.palette.foreground,
                background=@core.Brush::solid(theme.palette.surface),
                corner_radius=8.0,
                on_link_click=Some(target => OpenDocLink(target)),
                visible_viewport_height=document_viewport_height,
                visible_scroll_y=if independent_scroll {
                  self.docs_scroll.y
                } else {
                  0.0
                },
              )
              let body = if independent_scroll {
                scroll_view(
                  viewer,
                  width=content_width,
                  height=document_viewport_height,
                  offset=self.docs_scroll,
                  on_scroll=Some(offset => DocsScrolled(offset)),
                  shows_indicator=true,
                )
              } else {
                viewer
              }
              container(
                column(
                  [
                    docs_document_header(
                      theme,
                      entry,
                      document.title,
                      content_width,
                    ),
                    body,
                  ],
                  spacing=18.0,
                  align=@views.CrossAlign::Start,
                ),
                width~,
                height=if independent_scroll { viewport_height } else { 0.0 },
                background=theme.palette.surface,
                corner_radius=8.0,
                theme~,
                padding=20.0,
              ).border(website_border(theme))
            }
            DocLoading(_, path) =>
              docs_status_panel(
                theme,
                width,
                website_message(self.locale, "docs.loading_markdown"),
                path,
                RetryDoc,
                website_message(self.locale, "action.retry"),
              )
            DocFailed(path, reason) =>
              docs_status_panel(
                theme,
                width,
                website_message(self.locale, "docs.markdown_failed"),
                path + "\n" + reason,
                RetryDoc,
                website_message(self.locale, "action.retry"),
              )
            DocNotFound(slug) =>
              docs_not_found_panel(theme, width, slug, self.locale)
            DocNotLoaded =>
              docs_status_panel(
                theme,
                width,
                website_message(self.locale, "docs.preparing"),
                entry.path,
                RetryDoc,
                website_message(self.locale, "action.load"),
              )
          }
      }
  }
}

///|
fn docs_not_found_panel(
  theme : @moui.Theme,
  width : Double,
  slug : String,
  locale : String,
) -> @moui.View[Msg] {
  let message = key => website_message(locale, key)
  container(
    column(
      [
        docs_start_text(
          message("docs.not_found"),
          width=width - 40.0,
          height=34.0,
          font=@text.FontSpec::new(size=22.0, weight=780),
          color=theme.palette.foreground,
        )
        .semantics_role(@core.SemanticsRole::Heading)
        .semantics_level(1),
        docs_wrapped_text(
          theme,
          website_message_with(locale, "docs.not_found_detail", [("slug", slug)]),
          width - 40.0,
          14.0,
          22.0,
          muted=true,
        ),
        button(
          message("action.open_docs"),
          on_click=SelectDoc("moui-readme"),
          variant=@views.ButtonVariant::Outline,
          theme~,
          width=110.0,
          height=36.0,
        ),
      ],
      spacing=14.0,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height=190.0,
    background=theme.palette.surface,
    corner_radius=8.0,
    theme~,
    padding=20.0,
  ).border(website_border(theme))
}

///|
fn docs_document_header(
  theme : @moui.Theme,
  entry : WebsiteDocEntry,
  title : String,
  width : Double,
) -> @moui.View[Msg] {
  column(
    [
      docs_start_text(
        title,
        width~,
        height=40.0,
        font=@text.FontSpec::new(size=27.0, weight=820),
        color=theme.palette.foreground,
      )
      .semantics_role(@core.SemanticsRole::Heading)
      .semantics_level(2),
      docs_wrapped_text(theme, entry.summary, width, 13.0, 21.0, muted=true),
      tag(entry.path, theme~, width=website_doc_tag_width(width)),
    ],
    spacing=8.0,
    align=@views.CrossAlign::Start,
  )
}

///|
fn docs_status_panel(
  theme : @moui.Theme,
  width : Double,
  title : String,
  detail : String,
  action : Msg,
  action_label : String,
) -> @moui.View[Msg] {
  container(
    column(
      [
        docs_start_text(
          title,
          width=width - 40.0,
          height=34.0,
          font=@text.FontSpec::new(size=22.0, weight=780),
          color=theme.palette.foreground,
        )
        .semantics_role(@core.SemanticsRole::Heading)
        .semantics_level(1),
        docs_wrapped_text(theme, detail, width - 40.0, 13.0, 21.0, muted=true),
        button(
          action_label,
          on_click=action,
          variant=@views.ButtonVariant::Outline,
          theme~,
          width=94.0,
          height=36.0,
        ),
      ],
      spacing=14.0,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height=190.0,
    background=theme.palette.surface,
    corner_radius=8.0,
    theme~,
    padding=20.0,
  ).border(website_border(theme))
}

///|
fn docs_wrapped_text(
  theme : @moui.Theme,
  value : String,
  width : Double,
  font_size : Double,
  line_height : Double,
  muted~ : Bool,
) -> @moui.View[Msg] {
  let color = if muted { theme.palette.muted } else { theme.palette.foreground }
  let lines : Array[@moui.View[Msg]] = []
  for line in website_doc_wrap_lines(value, width, font_size) {
    lines.push(
      docs_start_text(
        line,
        width~,
        height=line_height,
        font=@text.FontSpec::new(size=font_size, weight=480),
        color~,
      ),
    )
  }
  column(lines, spacing=0.0, align=@views.CrossAlign::Start)
}

///|
fn docs_start_text(
  value : String,
  width~ : Double,
  height~ : Double,
  font~ : @text.FontSpec,
  color~ : @graphics.Color,
) -> @moui.View[Msg] {
  custom_layout(
    measure=_constraints => @geometry.Size::new(width~, height~),
    paint=(ctx, frame) => {
      draw_text(
        ctx,
        @text.TextRun::new(
          text=value,
          frame~,
          font~,
          color~,
          align=@text.TextAlign::TextStart,
        ),
      )
    },
    semantics_label=value,
  ).semantics_role(@core.SemanticsRole::Text)
}

///|
fn website_doc_tag_width(width : Double) -> Double {
  clamp_website_double(width * 0.76, 220.0, width)
}

///|
fn max_website_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}
