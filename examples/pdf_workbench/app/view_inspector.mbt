///|
fn pdf_workbench_inspector(
  model : PdfWorkbenchModel,
  metrics : PdfWorkbenchLayoutMetrics,
  theme : @moui.Theme,
) -> @moui.View[PdfWorkbenchMsg] {
  let rows : Array[@moui.View[PdfWorkbenchMsg]] = []
  let item_width = pdf_workbench_panel_item_width(
    metrics.inspector_scroll_width,
    theme,
  )
  match model.document {
    Some(document) => {
      let matches = document.search_count(model.query)
      rows.push(
        pdf_workbench_inspector_summary(
          model, document, matches, item_width, theme,
        ),
      )
      rows.push(pdf_workbench_inspector_page_group(item_width, theme))
      rows.push(
        pdf_workbench_inspector_queue_group(document, item_width, theme),
      )
      rows.push(
        pdf_workbench_inspector_document_group(
          model, document, item_width, theme,
        ),
      )
      rows.push(
        pdf_workbench_inspector_diagnostics_group(document, item_width, theme),
      )
    }
    None =>
      rows.push(
        @views.banner(
          "Skia PDF note",
          "Skia's PDF sample is for PDF output generation, not existing-page rasterization.",
          tone=@views.FeedbackTone::Info,
          theme~,
          width=item_width,
        ),
      )
  }
  @views.container(
    @views.scroll_view(
      @views.column(
        rows,
        spacing=theme.spacing_scale.sm,
        align=@views.CrossAlign::Stretch,
      ),
      width=metrics.inspector_scroll_width,
      height=pdf_workbench_panel_scroll_height(metrics, theme),
      offset=model.inspector_scroll.offset(),
      state=Some(model.inspector_scroll),
    ),
    width=metrics.inspector_width,
    height=metrics.body_height,
    variant=@views.ContainerVariant::Raised,
    theme~,
    padding=theme.spacing_scale.sm,
  )
}

///|
fn pdf_workbench_inspector_summary(
  model : PdfWorkbenchModel,
  document : PdfWorkbenchDocument,
  matches : Int,
  width : Double,
  theme : @moui.Theme,
) -> @moui.View[PdfWorkbenchMsg] {
  let zoom_label = pdf_workbench_zoom_label(model.zoom)
  let edit_tone = if document.dirty {
    @views.BadgeTone::Warning
  } else {
    @views.BadgeTone::Success
  }
  @views.container(
    @views.column(
      [
        @views.row(
          [
            @views.status_badge(
              if document.dirty {
                "Unsaved"
              } else {
                "Saved"
              },
              tone=edit_tone,
              detail=if document.dirty {
                "Queued edits need save or discard"
              } else {
                "No queued edits"
              },
              theme~,
              width=78.0,
              height=24.0,
            ),
            @views.badge(
              zoom_label,
              tone=@views.BadgeTone::Neutral,
              theme~,
              width=58.0,
              height=24.0,
            ),
            @views.badge(
              pdf_workbench_search_badge_label(document, model.query),
              tone=if matches > 0 {
                @views.BadgeTone::Accent
              } else {
                @views.BadgeTone::Neutral
              },
              theme~,
              width=64.0,
              height=24.0,
            ),
          ],
          spacing=theme.spacing_scale.xs,
          align=@views.CrossAlign::Center,
        ),
        pdf_workbench_inspector_caption(
          "Page " +
          document.selected_page.to_string() +
          " of " +
          document.page_count.to_string() +
          " | " +
          pdf_workbench_raster_status_label(model.raster_status),
          width - 20.0,
          32.0,
          theme,
        ),
      ],
      spacing=theme.spacing_scale.xs,
      align=@views.CrossAlign::Stretch,
    ),
    width~,
    height=72.0,
    background=theme.palette.surface_variant.multiply_alpha(0.72),
    corner_radius=theme.radius_scale.sm,
    theme~,
    padding=theme.spacing_scale.sm,
  )
}

///|
fn pdf_workbench_inspector_page_group(
  width : Double,
  theme : @moui.Theme,
) -> @moui.View[PdfWorkbenchMsg] {
  let button_width = (width - theme.spacing_scale.sm) / 2.0
  pdf_workbench_inspector_group(
    "Page",
    [
      @views.row(
        [
          @views.button(
            "Rotate 90",
            on_click=RotateCurrentPage,
            variant=@views.ButtonVariant::Outline,
            theme~,
            width=button_width,
            height=34.0,
          ),
          @views.button(
            "Crop",
            on_click=CropCurrentPage,
            variant=@views.ButtonVariant::Outline,
            theme~,
            width=button_width,
            height=34.0,
          ),
        ],
        spacing=theme.spacing_scale.sm,
        align=@views.CrossAlign::Center,
      ),
      @views.button(
        "Stamp",
        on_click=StampCurrentPage,
        variant=@views.ButtonVariant::Outline,
        theme~,
        width~,
        height=34.0,
      ),
    ],
    width,
    theme,
  )
}

///|
fn pdf_workbench_inspector_document_group(
  model : PdfWorkbenchModel,
  document : PdfWorkbenchDocument,
  width : Double,
  theme : @moui.Theme,
) -> @moui.View[PdfWorkbenchMsg] {
  pdf_workbench_inspector_group(
    "Document",
    [
      @views.text_field(
        model.metadata_title_draft,
        on_input=value => MetadataTitleChanged(value),
        placeholder="Document title",
        variant=@views.TextFieldVariant::Outline,
        theme~,
        width~,
        height=34.0,
      ),
      @views.button(
        "Apply Title",
        on_click=ApplyMetadataTitle,
        variant=@views.ButtonVariant::Outline,
        theme~,
        width~,
        height=34.0,
      ),
      @views.text_field(
        model.bookmark_title_draft,
        on_input=value => BookmarkTitleChanged(value),
        placeholder="Current page bookmark",
        variant=@views.TextFieldVariant::Outline,
        theme~,
        width~,
        height=34.0,
      ),
      @views.button(
        "Add Bookmark",
        on_click=AddBookmarkForCurrentPage,
        variant=@views.ButtonVariant::Outline,
        theme~,
        width~,
        height=34.0,
      ),
      @views.text_field(
        model.annotation_text_draft,
        on_input=value => AnnotationTextChanged(value),
        placeholder="Current page note",
        variant=@views.TextFieldVariant::Outline,
        theme~,
        width~,
        height=34.0,
      ),
      @views.button(
        "Add Note",
        on_click=AddAnnotationForCurrentPage,
        variant=@views.ButtonVariant::Outline,
        theme~,
        width~,
        height=34.0,
      ),
      pdf_workbench_inspector_caption(
        if document.writeback_available {
          "pdflite writeback ready"
        } else {
          "Save needs pdflite document service"
        },
        width,
        22.0,
        theme,
      ),
    ],
    width,
    theme,
  )
}

///|
fn pdf_workbench_inspector_queue_group(
  document : PdfWorkbenchDocument,
  width : Double,
  theme : @moui.Theme,
) -> @moui.View[PdfWorkbenchMsg] {
  let rows : Array[@moui.View[PdfWorkbenchMsg]] = [
    @views.row(
      [
        @views.button(
          "Undo Last",
          on_click=UndoLastEdit,
          variant=@views.ButtonVariant::Ghost,
          theme~,
          width=(width - theme.spacing_scale.sm) / 2.0,
          height=34.0,
        ),
        @views.button(
          "Discard Edits",
          on_click=DiscardEdits,
          variant=@views.ButtonVariant::Ghost,
          theme~,
          width=(width - theme.spacing_scale.sm) / 2.0,
          height=34.0,
        ),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Center,
    ),
  ]
  if document.edits.is_empty() {
    rows.push(
      pdf_workbench_inspector_caption("No queued edits", width, 24.0, theme),
    )
  } else {
    let mut index = 0
    for edit in document.edits {
      if index < 4 {
        rows.push(pdf_workbench_edit_queue_row(edit, index + 1, width, theme))
      }
      index = index + 1
    }
    if document.edits.length() > 4 {
      rows.push(
        pdf_workbench_inspector_caption(
          "+" + (document.edits.length() - 4).to_string() + " more queued",
          width,
          22.0,
          theme,
        ),
      )
    }
  }
  pdf_workbench_inspector_group("Queue", rows, width, theme)
}

///|
fn pdf_workbench_inspector_diagnostics_group(
  document : PdfWorkbenchDocument,
  width : Double,
  theme : @moui.Theme,
) -> @moui.View[PdfWorkbenchMsg] {
  let rows : Array[@moui.View[PdfWorkbenchMsg]] = [
    pdf_workbench_inspector_caption(
      document.metadata_summary,
      width,
      36.0,
      theme,
    ),
    pdf_workbench_inspector_caption(
      document.outline_summary,
      width,
      36.0,
      theme,
    ),
    pdf_workbench_inspector_caption(
      document.annotation_summary,
      width,
      36.0,
      theme,
    ),
  ]
  let mut count = 0
  for entry in document.unsupported_entries {
    if count < 4 {
      rows.push(pdf_workbench_inspector_caption(entry, width, 44.0, theme))
    }
    count = count + 1
  }
  if document.unsupported_entries.length() > 4 {
    rows.push(
      pdf_workbench_inspector_caption(
        "+" +
        (document.unsupported_entries.length() - 4).to_string() +
        " more diagnostics",
        width,
        22.0,
        theme,
      ),
    )
  }
  pdf_workbench_inspector_group("Diagnostics", rows, width, theme)
}

///|
fn pdf_workbench_inspector_group(
  title : String,
  children : Array[@moui.View[PdfWorkbenchMsg]],
  width : Double,
  theme : @moui.Theme,
) -> @moui.View[PdfWorkbenchMsg] {
  let rows : Array[@moui.View[PdfWorkbenchMsg]] = [
    @views.text(
      title,
      role=@views.TextRole::Control,
      theme~,
      width~,
      height=24.0,
    ),
  ]
  for child in children {
    rows.push(child)
  }
  @views.container(
    @views.column(
      rows,
      spacing=theme.spacing_scale.xs,
      align=@views.CrossAlign::Stretch,
    ),
    width~,
    background=theme.palette.surface.multiply_alpha(0.96),
    corner_radius=theme.radius_scale.sm,
    theme~,
    padding=theme.spacing_scale.sm,
  )
}

///|
fn pdf_workbench_inspector_caption(
  value : String,
  width : Double,
  height : Double,
  theme : @moui.Theme,
) -> @moui.View[PdfWorkbenchMsg] {
  @views.text(value, role=@views.TextRole::Caption, theme~, width~, height~).foreground(
    theme.palette.muted,
  )
}

///|
fn pdf_workbench_edit_queue_row(
  edit : PdfWorkbenchEdit,
  index : Int,
  width : Double,
  theme : @moui.Theme,
) -> @moui.View[PdfWorkbenchMsg] {
  let label = index.to_string() + ". " + pdf_workbench_edit_queue_label(edit)
  @views.container(
    pdf_workbench_inspector_caption(label, width - 16.0, 30.0, theme),
    width~,
    height=38.0,
    background=theme.palette.surface_variant.multiply_alpha(0.58),
    corner_radius=theme.radius_scale.sm,
    theme~,
    padding=theme.spacing_scale.xs,
  )
}

///|
fn pdf_workbench_edit_queue_label(edit : PdfWorkbenchEdit) -> String {
  match edit {
    RotatePage(page, degrees) => "Rotate page \{page} \{degrees} deg"
    CropPage(page, _) => "Crop page \{page}"
    StampText(page, value) => "Stamp page \{page}: " + value
    SetMetadataTitle(value) => "Set title: " + value
    AddBookmark(page, title) => "Bookmark page \{page}: " + title
    AddTextAnnotation(page, text) => "Note page \{page}: " + text
  }
}
