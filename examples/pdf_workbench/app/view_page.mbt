///|
fn pdf_workbench_page_surface(
  model : PdfWorkbenchModel,
  metrics : PdfWorkbenchLayoutMetrics,
  theme : @moui.Theme,
) -> @moui.View[PdfWorkbenchMsg] {
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
  let rows : Array[@moui.View[PdfWorkbenchMsg]] = [
    pdf_workbench_page_toolbar(model, page_label, metrics, theme),
  ]
  if !metrics.reader_fullscreen && !metrics.inspector_visible {
    rows.push(pdf_workbench_compact_edit_strip(model, metrics, theme))
  }
  rows.push(
    @views.scroll_view(
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
  @views.container(
    @views.column(
      rows,
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Stretch,
    ),
    width=metrics.page_width,
    height=metrics.body_height,
    variant=@views.ContainerVariant::Raised,
    theme~,
    padding=theme.spacing_scale.md,
  )
}

///|
fn pdf_workbench_page_toolbar(
  model : PdfWorkbenchModel,
  page_label : String,
  metrics : PdfWorkbenchLayoutMetrics,
  theme : @moui.Theme,
) -> @moui.View[PdfWorkbenchMsg] {
  let fullscreen_label = if model.reader_fullscreen { "Exit" } else { "Full" }
  @views.row(
    [
      @views.button(
        "Prev",
        on_click=PreviousPage,
        variant=@views.ButtonVariant::Ghost,
        theme~,
        width=56.0,
        height=32.0,
      ),
      @views.text(
        page_label,
        role=@views.TextRole::Title,
        theme~,
        width=(metrics.page_width - 514.0).max(36.0),
        height=32.0,
      ),
      @views.button(
        "Next",
        on_click=NextPage,
        variant=@views.ButtonVariant::Ghost,
        theme~,
        width=56.0,
        height=32.0,
      ),
      @views.spacer(min_length=8.0, weight=1.0),
      @views.text_field(
        model.page_number_draft,
        on_input=value => PageNumberChanged(value),
        placeholder="Page",
        variant=@views.TextFieldVariant::Outline,
        theme~,
        width=52.0,
        height=32.0,
      ),
      @views.button(
        "Go",
        on_click=GoToPage,
        variant=@views.ButtonVariant::Outline,
        theme~,
        width=40.0,
        height=32.0,
      ),
      @views.text(
        pdf_workbench_zoom_label(model.zoom),
        role=@views.TextRole::Caption,
        theme~,
        width=48.0,
        height=24.0,
      ).foreground(theme.palette.muted),
      @views.button("+", on_click=ZoomIn, theme~, width=34.0, height=32.0),
      @views.button("-", on_click=ZoomOut, theme~, width=34.0, height=32.0),
      @views.button(
        "Fit",
        on_click=ZoomFitWidth,
        variant=@views.ButtonVariant::Outline,
        theme~,
        width=44.0,
        height=32.0,
      ),
      @views.button(
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
  theme : @moui.Theme,
) -> @moui.View[PdfWorkbenchMsg] {
  ignore(metrics)
  let dirty = match model.document {
    Some(document) => document.dirty || document.edits.length() > 0
    None => false
  }
  @views.row(
    [
      @views.text(
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
      @views.button(
        "Rotate 90",
        on_click=RotateCurrentPage,
        variant=@views.ButtonVariant::Outline,
        theme~,
        width=82.0,
        height=30.0,
      ),
      @views.button(
        "Crop",
        on_click=CropCurrentPage,
        variant=@views.ButtonVariant::Outline,
        theme~,
        width=58.0,
        height=30.0,
      ),
      @views.button(
        "Stamp",
        on_click=StampCurrentPage,
        variant=@views.ButtonVariant::Outline,
        theme~,
        width=66.0,
        height=30.0,
      ),
      @views.spacer(min_length=4.0, weight=1.0),
      @views.button(
        "Undo Last",
        on_click=UndoLastEdit,
        variant=@views.ButtonVariant::Ghost,
        theme~,
        width=78.0,
        height=30.0,
      ),
      @views.button(
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
