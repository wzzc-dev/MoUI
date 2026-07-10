///|
fn Model::docs_content(
  self : Model,
  theme : @moui.Theme,
  metrics : Metrics,
) -> @moui.View[Msg] {
  let doc_width = if metrics.docs_compact {
    metrics.content_width
  } else {
    metrics.content_width - metrics.docs_sidebar_width - 24.0
  }
  let content = if metrics.docs_compact {
    let summary_height = website_doc_wrap_lines(
        docs_header_summary(),
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
        docs_header(theme, metrics.content_width),
        button(
          "Search & Contents",
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
        docs_header(theme, metrics.content_width),
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
fn docs_header(theme : @moui.Theme, width : Double) -> @moui.View[Msg] {
  column(
    [
      badge("Runtime docs", tone=@views.BadgeTone::Accent, theme~, width=112.0),
      docs_start_text(
        "MoUI Documentation",
        width~,
        height=38.0,
        font=@text.FontSpec::new(size=30.0, weight=820),
        color=theme.palette.foreground,
      )
      .semantics_role(@core.SemanticsRole::Heading)
      .semantics_level(1),
      docs_wrapped_text(
        theme,
        docs_header_summary(),
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
fn docs_header_summary() -> String {
  "Framework guides, platform support, architecture, contributor workflow, and evidence."
}

///|
fn Model::docs_sidebar(
  self : Model,
  theme : @moui.Theme,
  width : Double,
  max_height : Double,
) -> @moui.View[Msg] {
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
              .accessibility_label("Open " + entry.title)
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
            "No documents match your search.",
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
          placeholder="Search docs",
          variant=@views.TextFieldVariant::Outline,
          theme~,
          width=content_width,
          height=40.0,
        ).accessibility_label("Search documentation"),
        scroll_view(
          catalog_content,
          state=Some(self.docs_body_scroll),
          width=content_width,
          height=list_height,
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
  .accessibility_label("Documentation navigation")
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
        "Loading documentation",
        "Reading docs/catalog.json",
        RetryCatalog,
        "Retry",
      )
    CatalogFailed(reason) =>
      docs_status_panel(
        theme,
        width,
        "Could not load documentation",
        reason,
        RetryCatalog,
        "Retry",
      )
    CatalogLoaded(catalog) =>
      match catalog.entry_by_slug(self.selected_doc_slug) {
        None => docs_not_found_panel(theme, width, self.selected_doc_slug)
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
                visible_scroll_state=if independent_scroll {
                  Some(self.docs_scroll)
                } else {
                  None
                },
              )
              let body = if independent_scroll {
                scroll_view(
                  viewer,
                  state=Some(self.docs_scroll),
                  width=content_width,
                  height=document_viewport_height,
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
                "Loading Markdown",
                path,
                RetryDoc,
                "Retry",
              )
            DocFailed(path, reason) =>
              docs_status_panel(
                theme,
                width,
                "Could not load Markdown",
                path + "\n" + reason,
                RetryDoc,
                "Retry",
              )
            DocNotFound(slug) => docs_not_found_panel(theme, width, slug)
            DocNotLoaded =>
              docs_status_panel(
                theme,
                width,
                "Preparing document",
                entry.path,
                RetryDoc,
                "Load",
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
) -> @moui.View[Msg] {
  container(
    column(
      [
        docs_start_text(
          "Document not found",
          width=width - 40.0,
          height=34.0,
          font=@text.FontSpec::new(size=22.0, weight=780),
          color=theme.palette.foreground,
        )
        .semantics_role(@core.SemanticsRole::Heading)
        .semantics_level(1),
        docs_wrapped_text(
          theme,
          "No public documentation entry matches '" + slug + "'.",
          width - 40.0,
          14.0,
          22.0,
          muted=true,
        ),
        button(
          "Open Docs",
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
