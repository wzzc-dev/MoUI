///|
using @views {
  banner,
  button,
  column,
  expanded,
  row,
  scroll_view,
  spacer,
  status_bar,
  surface,
  text,
  text_field,
}

///|
fn PdfWorkbenchModel::view_with_environment(
  self : PdfWorkbenchModel,
  env : @core.ViewEnvironment,
) -> @core.View[PdfWorkbenchMsg] {
  self.view_for_viewport(env.viewport_size())
}

///|
fn PdfWorkbenchModel::view_for_viewport(
  self : PdfWorkbenchModel,
  viewport : @core.Size,
) -> @core.View[PdfWorkbenchMsg] {
  let theme = @views.light_theme()
  let metrics = pdf_workbench_layout_metrics(
    viewport,
    theme,
    reader_fullscreen=self.reader_fullscreen,
  )
  if self.reader_fullscreen {
    return surface(
      pdf_workbench_page_surface(self, metrics, theme),
      width=metrics.viewport.width,
      height=metrics.viewport.height,
      variant=@views.SurfaceVariant::Base,
      theme~,
      padding=theme.spacing_scale.sm,
    )
  }
  let header = pdf_workbench_toolbar(self, theme)
  let body_columns : Array[@core.View[PdfWorkbenchMsg]] = []
  if metrics.sidebar_visible {
    body_columns.push(pdf_workbench_sidebar(self, metrics, theme))
  }
  body_columns.push(expanded(pdf_workbench_page_surface(self, metrics, theme)))
  if metrics.inspector_visible {
    body_columns.push(pdf_workbench_inspector(self, metrics, theme))
  }
  let body = row(
    body_columns,
    spacing=theme.spacing_scale.md,
    align=@views.CrossAlign::Start,
  )
  let rows : Array[@core.View[PdfWorkbenchMsg]] = [header]
  match self.status {
    Failed(_) => rows.push(pdf_workbench_failure_banner(self, metrics, theme))
    _ => ()
  }
  rows.push(body)
  rows.push(pdf_workbench_status(self, metrics, theme))
  surface(
    column(
      rows,
      spacing=theme.spacing_scale.md,
      align=@views.CrossAlign::Stretch,
    ),
    width=metrics.viewport.width,
    height=metrics.viewport.height,
    variant=@views.SurfaceVariant::Base,
    theme~,
    padding=theme.spacing_scale.lg,
  )
}

///|
priv struct PdfWorkbenchLayoutMetrics {
  viewport : @core.Size
  inner_width : Double
  body_height : Double
  sidebar_visible : Bool
  sidebar_width : Double
  sidebar_scroll_width : Double
  page_width : Double
  preview_width : Double
  preview_height : Double
  inspector_visible : Bool
  inspector_width : Double
  inspector_scroll_width : Double
  reader_fullscreen : Bool
}

///|
fn pdf_workbench_layout_metrics(
  viewport : @core.Size,
  theme : @core.Theme,
  reader_fullscreen? : Bool = false,
) -> PdfWorkbenchLayoutMetrics {
  let safe_width = viewport.width.max(640.0)
  let safe_height = viewport.height.max(520.0)
  let root_padding = if reader_fullscreen {
    theme.spacing_scale.sm
  } else {
    theme.spacing_scale.lg
  }
  let spacing = theme.spacing_scale.md
  let inner_width = (safe_width - root_padding * 2.0).max(560.0)
  let inner_height = (safe_height - root_padding * 2.0).max(460.0)
  let toolbar_height = 58.0
  let status_height = 40.0
  let body_height = if reader_fullscreen {
    inner_height.max(320.0)
  } else {
    (inner_height - toolbar_height - status_height - spacing * 2.0).max(320.0)
  }
  let sidebar_visible = !reader_fullscreen && inner_width >= 860.0
  let inspector_visible = !reader_fullscreen && inner_width >= 1040.0
  let sidebar_width = if !sidebar_visible {
    0.0
  } else if inner_width >= 1500.0 {
    260.0
  } else if inner_width >= 1180.0 {
    236.0
  } else {
    212.0
  }
  let inspector_width = if !inspector_visible {
    0.0
  } else if inner_width >= 1500.0 {
    286.0
  } else if inner_width >= 1180.0 {
    260.0
  } else {
    232.0
  }
  let visible_side_columns = (if sidebar_visible { 1 } else { 0 }) +
    (if inspector_visible { 1 } else { 0 })
  let page_width = (inner_width -
  sidebar_width -
  inspector_width -
  spacing * visible_side_columns.to_double()).max(360.0)
  let panel_padding = theme.spacing_scale.md
  let compact_panel_padding = theme.spacing_scale.sm
  {
    viewport: @core.Size::new(width=safe_width, height=safe_height),
    inner_width,
    body_height,
    sidebar_visible,
    sidebar_width,
    sidebar_scroll_width: (sidebar_width - compact_panel_padding * 2.0).max(
      160.0,
    ),
    page_width,
    preview_width: (page_width - panel_padding * 2.0).max(300.0),
    preview_height: (body_height - panel_padding * 2.0 - 42.0).max(260.0),
    inspector_visible,
    inspector_width,
    inspector_scroll_width: (inspector_width - compact_panel_padding * 2.0).max(
      180.0,
    ),
    reader_fullscreen,
  }
}

///|
fn pdf_workbench_panel_item_width(
  scroll_width : Double,
  theme : @core.Theme,
) -> Double {
  (scroll_width - theme.spacing_scale.md).max(140.0)
}

///|
fn pdf_workbench_panel_scroll_height(
  metrics : PdfWorkbenchLayoutMetrics,
  theme : @core.Theme,
) -> Double {
  (metrics.body_height - theme.spacing_scale.sm * 2.0).max(260.0)
}

///|
fn pdf_workbench_toolbar(
  model : PdfWorkbenchModel,
  theme : @core.Theme,
) -> @core.View[PdfWorkbenchMsg] {
  row(
    [
      column(
        [
          text(
            "PDF Workbench",
            role=@views.TextRole::Title,
            theme~,
            width=220.0,
            height=32.0,
          ),
          text(
            "Native PDF reader with light editing",
            role=@views.TextRole::Caption,
            theme~,
            width=300.0,
            height=22.0,
          ).foreground(theme.palette.muted),
        ],
        spacing=0.0,
        align=@views.CrossAlign::Start,
      ),
      spacer(min_length=16.0, weight=1.0),
      button("Open", on_click=OpenRequested, theme~, width=82.0, height=36.0),
      button(
        "Save",
        on_click=SaveRequested,
        variant=@views.ButtonVariant::Outline,
        theme~,
        width=78.0,
        height=36.0,
      ),
      button(
        "Save As",
        on_click=SaveAsRequested,
        variant=@views.ButtonVariant::Outline,
        theme~,
        width=92.0,
        height=36.0,
      ),
      text_field(
        model.query,
        on_input=query => SearchChanged(query),
        placeholder="Search extracted text",
        variant=@views.TextFieldVariant::Outline,
        theme~,
        width=156.0,
        height=36.0,
      ),
      text(
        model.search_status_label(),
        role=@views.TextRole::Caption,
        theme~,
        width=92.0,
        height=24.0,
      ).foreground(theme.palette.muted),
      button(
        "Prev Hit",
        on_click=SearchPrevious,
        variant=@views.ButtonVariant::Outline,
        theme~,
        width=78.0,
        height=36.0,
      ),
      button(
        "Next Hit",
        on_click=SearchNext,
        variant=@views.ButtonVariant::Outline,
        theme~,
        width=78.0,
        height=36.0,
      ),
    ],
    spacing=theme.spacing_scale.sm,
    align=@views.CrossAlign::Center,
  )
}

///|
fn pdf_workbench_page_surface(
  model : PdfWorkbenchModel,
  metrics : PdfWorkbenchLayoutMetrics,
  theme : @core.Theme,
) -> @core.View[PdfWorkbenchMsg] {
  let page = match model.document {
    Some(document) => document.selected_summary()
    None =>
      match model.status {
        Failed(reason) =>
          {
            page_number: 0,
            text_preview: "PDF load failed: " + reason,
            content_diagnostic: model.last_event,
          }
        _ =>
          {
            page_number: 0,
            text_preview: "Open a PDF to show a structured page preview.",
            content_diagnostic: "No document",
          }
      }
  }
  let page_label = match model.document {
    Some(document) =>
      "Page " +
      document.selected_page.to_string() +
      " / " +
      document.page_count.to_string()
    None => "Preview"
  }
  let rows : Array[@core.View[PdfWorkbenchMsg]] = [
    pdf_workbench_page_toolbar(model, page_label, metrics, theme),
  ]
  if !metrics.reader_fullscreen && !metrics.inspector_visible {
    rows.push(pdf_workbench_compact_edit_strip(model, metrics, theme))
  }
  rows.push(
    scroll_view(
      pdf_workbench_preview_canvas(
        page,
        model.document,
        model.raster_page,
        model.raster_status,
        model.zoom,
        metrics,
        theme,
      ),
      offset=model.preview_scroll_offset,
      width=metrics.preview_width,
      height=pdf_workbench_page_scroll_height(metrics),
      on_scroll=Some(delta => PreviewScrolled(delta)),
    ),
  )
  surface(
    column(
      rows,
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Stretch,
    ),
    width=metrics.page_width,
    height=metrics.body_height,
    variant=@views.SurfaceVariant::Raised,
    theme~,
    padding=theme.spacing_scale.md,
  )
}

///|
fn pdf_workbench_page_toolbar(
  model : PdfWorkbenchModel,
  page_label : String,
  metrics : PdfWorkbenchLayoutMetrics,
  theme : @core.Theme,
) -> @core.View[PdfWorkbenchMsg] {
  let fullscreen_label = if model.reader_fullscreen { "Exit" } else { "Full" }
  row(
    [
      button(
        "Prev",
        on_click=PreviousPage,
        variant=@views.ButtonVariant::Ghost,
        theme~,
        width=56.0,
        height=32.0,
      ),
      text(
        page_label,
        role=@views.TextRole::Title,
        theme~,
        width=(metrics.page_width - 514.0).max(36.0),
        height=32.0,
      ),
      button(
        "Next",
        on_click=NextPage,
        variant=@views.ButtonVariant::Ghost,
        theme~,
        width=56.0,
        height=32.0,
      ),
      spacer(min_length=8.0, weight=1.0),
      text_field(
        model.page_number_draft,
        on_input=value => PageNumberChanged(value),
        placeholder="Page",
        variant=@views.TextFieldVariant::Outline,
        theme~,
        width=52.0,
        height=32.0,
      ),
      button(
        "Go",
        on_click=GoToPage,
        variant=@views.ButtonVariant::Outline,
        theme~,
        width=40.0,
        height=32.0,
      ),
      text(
        pdf_workbench_zoom_label(model.zoom),
        role=@views.TextRole::Caption,
        theme~,
        width=48.0,
        height=24.0,
      ).foreground(theme.palette.muted),
      button("+", on_click=ZoomIn, theme~, width=34.0, height=32.0),
      button("-", on_click=ZoomOut, theme~, width=34.0, height=32.0),
      button(
        "Fit",
        on_click=ZoomFitWidth,
        variant=@views.ButtonVariant::Outline,
        theme~,
        width=44.0,
        height=32.0,
      ),
      button(
        fullscreen_label,
        on_click=ToggleReaderFullscreen,
        variant=@views.ButtonVariant::Outline,
        theme~,
        width=54.0,
        height=32.0,
      ),
    ],
    spacing=theme.spacing_scale.sm,
    align=@views.CrossAlign::Center,
  )
}

///|
fn pdf_workbench_compact_edit_strip(
  model : PdfWorkbenchModel,
  metrics : PdfWorkbenchLayoutMetrics,
  theme : @core.Theme,
) -> @core.View[PdfWorkbenchMsg] {
  ignore(metrics)
  let dirty = match model.document {
    Some(document) => document.dirty || document.edits.length() > 0
    None => false
  }
  row(
    [
      text(
        if dirty {
          "Quick edits"
        } else {
          "Edit"
        },
        role=@views.TextRole::Control,
        theme~,
        width=72.0,
        height=28.0,
      ),
      button(
        "Rotate 90",
        on_click=RotateCurrentPage,
        variant=@views.ButtonVariant::Outline,
        theme~,
        width=82.0,
        height=30.0,
      ),
      button(
        "Crop",
        on_click=CropCurrentPage,
        variant=@views.ButtonVariant::Outline,
        theme~,
        width=58.0,
        height=30.0,
      ),
      button(
        "Stamp",
        on_click=StampCurrentPage,
        variant=@views.ButtonVariant::Outline,
        theme~,
        width=66.0,
        height=30.0,
      ),
      spacer(min_length=4.0, weight=1.0),
      button(
        "Undo Last",
        on_click=UndoLastEdit,
        variant=@views.ButtonVariant::Ghost,
        theme~,
        width=78.0,
        height=30.0,
      ),
      button(
        "Discard Edits",
        on_click=DiscardEdits,
        variant=@views.ButtonVariant::Ghost,
        theme~,
        width=104.0,
        height=30.0,
      ),
    ],
    spacing=theme.spacing_scale.xs,
    align=@views.CrossAlign::Center,
  )
}

///|
fn pdf_workbench_page_scroll_height(
  metrics : PdfWorkbenchLayoutMetrics,
) -> Double {
  if metrics.reader_fullscreen || metrics.inspector_visible {
    metrics.preview_height
  } else {
    (metrics.preview_height - 38.0).max(220.0)
  }
}

///|
fn pdf_workbench_zoom_label(zoom : Double) -> String {
  pdf_workbench_zoom_bucket(zoom).to_string() + "%"
}

///|
fn pdf_workbench_failure_banner(
  model : PdfWorkbenchModel,
  metrics : PdfWorkbenchLayoutMetrics,
  theme : @core.Theme,
) -> @core.View[PdfWorkbenchMsg] {
  match model.status {
    Failed(reason) =>
      row(
        [
          banner(
            "PDF Workbench needs attention",
            reason,
            tone=@views.FeedbackTone::Danger,
            theme~,
            width=(metrics.inner_width - 112.0 - theme.spacing_scale.sm).max(
              360.0,
            ),
          ),
          button(
            "Dismiss",
            on_click=ClearFailure,
            variant=@views.ButtonVariant::Outline,
            theme~,
            width=88.0,
            height=36.0,
          ),
        ],
        spacing=theme.spacing_scale.sm,
        align=@views.CrossAlign::Center,
      )
    _ => spacer(min_length=0.0)
  }
}

///|
fn pdf_workbench_status(
  model : PdfWorkbenchModel,
  metrics : PdfWorkbenchLayoutMetrics,
  theme : @core.Theme,
) -> @core.View[PdfWorkbenchMsg] {
  let status = match model.status {
    Empty => "Empty"
    Requesting(label) => "Requesting: " + label
    Pending(_, label) => "Pending: " + label
    Ready => "Ready"
    Failed(reason) => "Failed: " + reason
  }
  let document_status = match model.document {
    Some(document) =>
      pdf_workbench_file_name(document.path) +
      " | \{document.original_bytes.length()} byte(s) | page \{document.selected_page}/\{document.page_count}"
    None => "No document"
  }
  status_bar(
    [
      status,
      document_status,
      model.search_status_label(),
      pdf_workbench_raster_status_label(model.raster_status),
      model.last_event,
    ],
    theme~,
    width=metrics.inner_width,
  )
}

///|
fn PdfWorkbenchModel::search_status_label(self : PdfWorkbenchModel) -> String {
  match self.document {
    Some(document) => {
      let query = self.query.trim().to_owned()
      if query == "" {
        "Find: empty"
      } else {
        "Find: " + pdf_workbench_search_badge_label(document, self.query)
      }
    }
    None =>
      if self.query.trim().to_owned() == "" {
        "Find: empty"
      } else {
        "Find: no document"
      }
  }
}

///|
fn pdf_workbench_search_badge_label(
  document : PdfWorkbenchDocument,
  query : String,
) -> String {
  let matches = document.search_match_pages(query)
  if query.trim().to_owned() == "" {
    "No query"
  } else if matches.is_empty() {
    "0 hits"
  } else {
    match document.search_match_position(query, document.selected_page) {
      Some(position) =>
        position.to_string() + "/" + matches.length().to_string()
      None => {
        let suffix = if matches.length() == 1 { " hit" } else { " hits" }
        matches.length().to_string() + suffix
      }
    }
  }
}
