///|
fn pdf_workbench_toolbar(
  model : PdfWorkbenchModel,
  theme : @core.Theme,
) -> @core.View[PdfWorkbenchMsg] {
  @views.row(
    [
      @views.column(
        [
          @views.text(
            "PDF Workbench",
            role=@views.TextRole::Title,
            theme~,
            width=220.0,
            height=32.0,
          ),
          @views.text(
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
      @views.spacer(min_length=16.0, weight=1.0),
      @views.button(
        "Open",
        on_click=OpenRequested,
        theme~,
        width=82.0,
        height=36.0,
      ),
      @views.button(
        "Save",
        on_click=SaveRequested,
        variant=@views.ButtonVariant::Outline,
        theme~,
        width=78.0,
        height=36.0,
      ),
      @views.button(
        "Save As",
        on_click=SaveAsRequested,
        variant=@views.ButtonVariant::Outline,
        theme~,
        width=92.0,
        height=36.0,
      ),
      @views.text_field(
        model.query,
        on_input=query => SearchChanged(query),
        placeholder="Search extracted text",
        variant=@views.TextFieldVariant::Outline,
        theme~,
        width=156.0,
        height=36.0,
      ),
      @views.text(
        model.search_status_label(),
        role=@views.TextRole::Caption,
        theme~,
        width=92.0,
        height=24.0,
      ).foreground(theme.palette.muted),
      @views.button(
        "Prev Hit",
        on_click=SearchPrevious,
        variant=@views.ButtonVariant::Outline,
        theme~,
        width=78.0,
        height=36.0,
      ),
      @views.button(
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
      @views.row(
        [
          @views.banner(
            "PDF Workbench needs attention",
            reason,
            tone=@views.FeedbackTone::Danger,
            theme~,
            width=(metrics.inner_width - 112.0 - theme.spacing_scale.sm).max(
              360.0,
            ),
          ),
          @views.button(
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
    _ => @views.spacer(min_length=0.0)
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
  @views.status_bar(
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
