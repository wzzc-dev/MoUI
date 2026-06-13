///|
using @views {
  badge,
  banner,
  button,
  column,
  custom_layout,
  expanded,
  row,
  scroll_view,
  spacer,
  stat_card,
  status_badge,
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
fn pdf_workbench_sidebar(
  model : PdfWorkbenchModel,
  metrics : PdfWorkbenchLayoutMetrics,
  theme : @core.Theme,
) -> @core.View[PdfWorkbenchMsg] {
  let rows : Array[@core.View[PdfWorkbenchMsg]] = []
  let item_width = pdf_workbench_panel_item_width(
    metrics.sidebar_scroll_width,
    theme,
  )
  match model.document {
    Some(document) => {
      let search_matches = document.search_match_pages(model.query)
      rows.push(
        stat_card(
          "Pages",
          document.page_count.to_string(),
          caption=if document.dirty { "Unsaved edits" } else { "Saved state" },
          tone=if document.dirty {
            @views.FeedbackTone::Warning
          } else {
            @views.FeedbackTone::Success
          },
          theme~,
          width=item_width,
          height=104.0,
        ),
      )
      for summary in document.page_summaries {
        rows.push(
          pdf_workbench_page_nav_item(
            summary,
            selected=summary.page_number == document.selected_page,
            matched=search_matches.any(page => page == summary.page_number),
            thumbnail_raster=model.thumbnail_raster_for_page(
              summary.page_number,
            ),
            width=item_width,
            theme,
          ),
        )
      }
    }
    None =>
      rows.push(
        banner(
          "No PDF loaded",
          "Use Open to load PDF bytes through the host binary file service.",
          tone=@views.FeedbackTone::Info,
          theme~,
          width=item_width,
        ),
      )
  }
  surface(
    scroll_view(
      column(
        rows,
        spacing=theme.spacing_scale.sm,
        align=@views.CrossAlign::Stretch,
      ),
      width=metrics.sidebar_scroll_width,
      height=pdf_workbench_panel_scroll_height(metrics, theme),
      offset=model.sidebar_scroll.offset(),
      state=Some(model.sidebar_scroll),
    ),
    width=metrics.sidebar_width,
    height=metrics.body_height,
    variant=@views.SurfaceVariant::Raised,
    theme~,
    padding=theme.spacing_scale.sm,
  )
}

///|
fn pdf_workbench_page_nav_item(
  summary : PdfWorkbenchPageSummary,
  selected~ : Bool,
  matched~ : Bool,
  thumbnail_raster~ : PdfWorkbenchRasterPage?,
  width~ : Double,
  theme : @core.Theme,
) -> @core.View[PdfWorkbenchMsg] {
  let control_width = (width - 68.0).max(110.0)
  row(
    [
      pdf_workbench_page_thumbnail(summary, selected~, thumbnail_raster~, theme),
      column(
        [
          button(
            "Page " + summary.page_number.to_string(),
            on_click=SelectPage(summary.page_number),
            variant=if selected {
              @views.ButtonVariant::Primary
            } else {
              @views.ButtonVariant::Ghost
            },
            theme~,
            width=control_width,
            height=32.0,
          ),
          text(
            if selected {
              "Current"
            } else if matched {
              "Match"
            } else {
              ""
            },
            role=@views.TextRole::Caption,
            theme~,
            width=control_width,
            height=18.0,
          ).foreground(theme.palette.muted),
        ],
        spacing=2.0,
        align=@views.CrossAlign::Stretch,
      ),
    ],
    spacing=theme.spacing_scale.sm,
    align=@views.CrossAlign::Center,
  )
}

///|
fn pdf_workbench_page_thumbnail(
  summary : PdfWorkbenchPageSummary,
  selected~ : Bool,
  thumbnail_raster~ : PdfWorkbenchRasterPage?,
  theme : @core.Theme,
) -> @core.View[PdfWorkbenchMsg] {
  custom_layout(
    measure=_ => @core.Size::new(width=54.0, height=68.0),
    paint=frame => {
      let page_width = 40.0
      let page_height = 56.0
      let x = frame.origin.x + (frame.size.width - page_width) / 2.0
      let y = frame.origin.y + (frame.size.height - page_height) / 2.0
      let page_rect = @core.Rect::new(
        x~,
        y~,
        width=page_width,
        height=page_height,
      )
      let commands : Array[@core.DrawCommand] = []
      if selected {
        commands.push(
          @core.DrawCommand::FillRect(
            frame,
            theme.palette.primary.multiply_alpha(0.10),
          ),
        )
      }
      commands.push(
        @core.DrawCommand::FillRect(page_rect, @core.Color::white()),
      )
      match thumbnail_raster {
        Some(raster) =>
          commands.push(
            @core.DrawCommand::DrawImage(@core.ImageRun::{
              source: raster.image_source,
              frame: page_rect,
              opacity: 1.0,
              fit: @core.ImageFit::Contain,
            }),
          )
        None => ()
      }
      commands.push(
        @core.DrawCommand::StrokeRect(
          page_rect,
          if selected {
            theme.palette.primary
          } else {
            theme.palette.outline
          },
          if selected {
            2.0
          } else {
            1.0
          },
        ),
      )
      let line_color = if selected {
        theme.palette.primary.multiply_alpha(0.42)
      } else {
        theme.palette.muted.multiply_alpha(0.48)
      }
      match thumbnail_raster {
        Some(_) => {
          let label_rect = @core.Rect::new(
            x=x + 5.0,
            y=y + page_height - 17.0,
            width=page_width - 10.0,
            height=13.0,
          )
          commands.push(
            @core.DrawCommand::FillRect(
              label_rect,
              theme.palette.surface.multiply_alpha(0.82),
            ),
          )
        }
        None =>
          for index in 0..<4 {
            let line_y = y + 14.0 + index.to_double() * 7.0
            let line_width = if index == 3 { 18.0 } else { 26.0 }
            commands.push(
              @core.DrawCommand::FillRect(
                @core.Rect::new(
                  x=x + 7.0,
                  y=line_y,
                  width=line_width,
                  height=2.0,
                ),
                line_color,
              ),
            )
          }
      }
      commands.push(
        @core.DrawCommand::DrawText(
          @core.TextRun::new(
            text=summary.page_number.to_string(),
            frame=@core.Rect::new(
              x=x + 7.0,
              y=y + page_height - 16.0,
              width=page_width - 14.0,
              height=12.0,
            ),
            font=@core.FontSpec::new(size=10.0),
            color=if selected {
              theme.palette.primary
            } else {
              theme.palette.muted
            },
            align=@core.TextAlign::TextCenter,
          ),
        ),
      )
      commands
    },
    semantics_label="Page thumbnail " + summary.page_number.to_string(),
  )
}

///|
fn PdfWorkbenchModel::thumbnail_raster_for_page(
  self : PdfWorkbenchModel,
  page_number : Int,
) -> PdfWorkbenchRasterPage? {
  match self.raster_page {
    Some(page) => if page.page_number == page_number { return Some(page) }
    None => ()
  }
  let length = self.raster_cache.length()
  for offset in 0..<length {
    let index = length - 1 - offset
    let page = self.raster_cache[index]
    if page.page_number == page_number {
      return Some(page)
    }
  }
  None
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
fn pdf_workbench_preview_canvas(
  page : PdfWorkbenchPageSummary,
  document : PdfWorkbenchDocument?,
  raster_page : PdfWorkbenchRasterPage?,
  raster_status : PdfWorkbenchRasterStatus,
  zoom : Double,
  metrics : PdfWorkbenchLayoutMetrics,
  theme : @core.Theme,
) -> @core.View[PdfWorkbenchMsg] {
  custom_layout(
    measure=_ => pdf_workbench_preview_content_size(raster_page, zoom, metrics),
    paint=frame => {
      let page_size = pdf_workbench_preview_page_size(
        raster_page, zoom, metrics,
      )
      let page_width = page_size.width
      let page_height = page_size.height
      let x = frame.origin.x + (frame.size.width - page_width) / 2.0
      let y = frame.origin.y + 36.0
      let page_rect = @core.Rect::new(
        x~,
        y~,
        width=page_width,
        height=page_height,
      )
      let loaded_title = match document {
        Some(_) => "Loaded PDF"
        None => if page.page_number == 0 { "No PDF loaded" } else { "Preview" }
      }
      let file_line = match document {
        Some(document) =>
          pdf_workbench_file_name(document.path) +
          " | \{document.original_bytes.length()} byte(s) | page \{document.selected_page}/\{document.page_count}"
        None => "Use Open to choose a .pdf file"
      }
      let commands : Array[@core.DrawCommand] = []
      commands.push(
        @core.DrawCommand::FillRect(frame, theme.palette.surface_variant),
      )
      commands.push(
        @core.DrawCommand::FillRect(page_rect, @core.Color::white()),
      )
      match raster_page {
        Some(raster) =>
          commands.push(
            @core.DrawCommand::DrawImage(@core.ImageRun::{
              source: raster.image_source,
              frame: page_rect,
              opacity: 1.0,
              fit: @core.ImageFit::Contain,
            }),
          )
        None => {
          commands.push(
            @core.DrawCommand::DrawText(
              @core.TextRun::new(
                text=loaded_title,
                frame=@core.Rect::new(
                  x=x + 24.0,
                  y=y + 28.0,
                  width=page_width - 48.0,
                  height=28.0,
                ),
                font=@core.FontSpec::new(size=18.0),
                color=theme.palette.foreground,
                align=@core.TextAlign::TextStart,
              ),
            ),
          )
          commands.push(
            @core.DrawCommand::DrawText(
              @core.TextRun::new(
                text=file_line,
                frame=@core.Rect::new(
                  x=x + 24.0,
                  y=y + 62.0,
                  width=page_width - 48.0,
                  height=24.0,
                ),
                font=@core.FontSpec::new(size=12.0),
                color=theme.palette.muted,
                align=@core.TextAlign::TextStart,
              ),
            ),
          )
          commands.push(
            @core.DrawCommand::DrawText(
              @core.TextRun::new(
                text=page.text_preview,
                frame=@core.Rect::new(
                  x=x + 24.0,
                  y=y + 104.0,
                  width=page_width - 48.0,
                  height=160.0,
                ),
                font=@core.FontSpec::new(size=14.0),
                color=theme.palette.foreground,
                align=@core.TextAlign::TextStart,
              ),
            ),
          )
          commands.push(
            @core.DrawCommand::DrawText(
              @core.TextRun::new(
                text=page.content_diagnostic,
                frame=@core.Rect::new(
                  x=x + 24.0,
                  y=y + page_height - 92.0,
                  width=page_width - 48.0,
                  height=32.0,
                ),
                font=@core.FontSpec::new(size=12.0),
                color=theme.palette.muted,
                align=@core.TextAlign::TextStart,
              ),
            ),
          )
        }
      }
      commands.push(
        @core.DrawCommand::StrokeRect(page_rect, theme.palette.outline, 1.0),
      )
      match document {
        Some(document) =>
          pdf_workbench_push_page_edit_overlays(
            commands, document, page_rect, theme,
          )
        None => ()
      }
      commands.push(
        @core.DrawCommand::DrawText(
          @core.TextRun::new(
            text=pdf_workbench_raster_status_label(raster_status),
            frame=@core.Rect::new(
              x=frame.origin.x + 16.0,
              y=frame.origin.y + 4.0,
              width=frame.size.width - 32.0,
              height=20.0,
            ),
            font=@core.FontSpec::new(size=12.0),
            color=theme.palette.muted,
            align=@core.TextAlign::TextStart,
          ),
        ),
      )
      commands
    },
    semantics_label=page.text_preview,
  )
}

///|
fn pdf_workbench_preview_aspect(
  raster_page : PdfWorkbenchRasterPage?,
) -> Double {
  match raster_page {
    Some(raster) =>
      if raster.height_px > 0 {
        raster.width_px.to_double() / raster.height_px.to_double()
      } else {
        0.75
      }
    None => 0.75
  }
}

///|
fn pdf_workbench_preview_display_zoom(zoom : Double) -> Double {
  if zoom < 0.5 {
    0.5
  } else if zoom > 2.0 {
    2.0
  } else {
    zoom
  }
}

///|
fn pdf_workbench_preview_page_size(
  raster_page : PdfWorkbenchRasterPage?,
  zoom : Double,
  metrics : PdfWorkbenchLayoutMetrics,
) -> @core.Size {
  let aspect = pdf_workbench_preview_aspect(raster_page)
  let available_width = (metrics.preview_width - 32.0).max(120.0)
  let page_width = (available_width * pdf_workbench_preview_display_zoom(zoom)).max(
    120.0,
  )
  @core.Size::new(width=page_width, height=(page_width / aspect).max(120.0))
}

///|
fn pdf_workbench_preview_content_size(
  raster_page : PdfWorkbenchRasterPage?,
  zoom : Double,
  metrics : PdfWorkbenchLayoutMetrics,
) -> @core.Size {
  let page_size = pdf_workbench_preview_page_size(raster_page, zoom, metrics)
  @core.Size::new(
    width=(page_size.width + 32.0).max(metrics.preview_width),
    height=(page_size.height + 72.0).max(metrics.preview_height),
  )
}

///|
fn pdf_workbench_push_page_edit_overlays(
  commands : Array[@core.DrawCommand],
  document : PdfWorkbenchDocument,
  page_rect : @core.Rect,
  theme : @core.Theme,
) -> Unit {
  let mut stamp_index = 0
  let mut note_index = 0
  for edit in document.edits {
    match edit {
      StampText(page, value) =>
        if page == document.selected_page {
          let stamp_width = 104.0
          let stamp_height = 28.0
          let stamp_rect = @core.Rect::new(
            x=page_rect.origin.x + page_rect.size.width - stamp_width - 18.0,
            y=page_rect.origin.y + 18.0 + stamp_index.to_double() * 34.0,
            width=stamp_width,
            height=stamp_height,
          )
          commands.push(
            @core.DrawCommand::FillRect(
              stamp_rect,
              theme.palette.primary.multiply_alpha(0.12),
            ),
          )
          commands.push(
            @core.DrawCommand::StrokeRect(
              stamp_rect,
              theme.palette.primary.multiply_alpha(0.72),
              1.0,
            ),
          )
          commands.push(
            @core.DrawCommand::DrawText(
              @core.TextRun::new(
                text=value,
                frame=stamp_rect,
                font=@core.FontSpec::new(size=12.0),
                color=theme.palette.primary,
                align=@core.TextAlign::TextCenter,
              ),
            ),
          )
          stamp_index = stamp_index + 1
        }
      AddTextAnnotation(page, value) =>
        if page == document.selected_page {
          let note_width = 168.0
          let note_height = 46.0
          let note_rect = @core.Rect::new(
            x=page_rect.origin.x + 18.0,
            y=page_rect.origin.y + 18.0 + note_index.to_double() * 52.0,
            width=note_width,
            height=note_height,
          )
          commands.push(
            @core.DrawCommand::FillRect(
              note_rect,
              theme.palette.primary.multiply_alpha(0.10),
            ),
          )
          commands.push(
            @core.DrawCommand::StrokeRect(
              note_rect,
              theme.palette.primary.multiply_alpha(0.58),
              1.0,
            ),
          )
          commands.push(
            @core.DrawCommand::DrawText(
              @core.TextRun::new(
                text=value,
                frame=@core.Rect::new(
                  x=note_rect.origin.x + 8.0,
                  y=note_rect.origin.y + 7.0,
                  width=note_rect.size.width - 16.0,
                  height=note_rect.size.height - 14.0,
                ),
                font=@core.FontSpec::new(size=11.0),
                color=theme.palette.primary,
                align=@core.TextAlign::TextStart,
              ),
            ),
          )
          note_index = note_index + 1
        }
      _ => ()
    }
  }
}

///|
fn pdf_workbench_inspector(
  model : PdfWorkbenchModel,
  metrics : PdfWorkbenchLayoutMetrics,
  theme : @core.Theme,
) -> @core.View[PdfWorkbenchMsg] {
  let rows : Array[@core.View[PdfWorkbenchMsg]] = []
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
        banner(
          "Skia PDF note",
          "Skia's PDF sample is for PDF output generation, not existing-page rasterization.",
          tone=@views.FeedbackTone::Info,
          theme~,
          width=item_width,
        ),
      )
  }
  surface(
    scroll_view(
      column(
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
    variant=@views.SurfaceVariant::Raised,
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
  theme : @core.Theme,
) -> @core.View[PdfWorkbenchMsg] {
  let zoom_label = pdf_workbench_zoom_label(model.zoom)
  let edit_tone = if document.dirty {
    @views.BadgeTone::Warning
  } else {
    @views.BadgeTone::Success
  }
  surface(
    column(
      [
        row(
          [
            status_badge(
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
            badge(
              zoom_label,
              tone=@views.BadgeTone::Neutral,
              theme~,
              width=58.0,
              height=24.0,
            ),
            badge(
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
  theme : @core.Theme,
) -> @core.View[PdfWorkbenchMsg] {
  let button_width = (width - theme.spacing_scale.sm) / 2.0
  pdf_workbench_inspector_group(
    "Page",
    [
      row(
        [
          button(
            "Rotate 90",
            on_click=RotateCurrentPage,
            variant=@views.ButtonVariant::Outline,
            theme~,
            width=button_width,
            height=34.0,
          ),
          button(
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
      button(
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
  theme : @core.Theme,
) -> @core.View[PdfWorkbenchMsg] {
  pdf_workbench_inspector_group(
    "Document",
    [
      text_field(
        model.metadata_title_draft,
        on_input=value => MetadataTitleChanged(value),
        placeholder="Document title",
        variant=@views.TextFieldVariant::Outline,
        theme~,
        width~,
        height=34.0,
      ),
      button(
        "Apply Title",
        on_click=ApplyMetadataTitle,
        variant=@views.ButtonVariant::Outline,
        theme~,
        width~,
        height=34.0,
      ),
      text_field(
        model.bookmark_title_draft,
        on_input=value => BookmarkTitleChanged(value),
        placeholder="Current page bookmark",
        variant=@views.TextFieldVariant::Outline,
        theme~,
        width~,
        height=34.0,
      ),
      button(
        "Add Bookmark",
        on_click=AddBookmarkForCurrentPage,
        variant=@views.ButtonVariant::Outline,
        theme~,
        width~,
        height=34.0,
      ),
      text_field(
        model.annotation_text_draft,
        on_input=value => AnnotationTextChanged(value),
        placeholder="Current page note",
        variant=@views.TextFieldVariant::Outline,
        theme~,
        width~,
        height=34.0,
      ),
      button(
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
  theme : @core.Theme,
) -> @core.View[PdfWorkbenchMsg] {
  let rows : Array[@core.View[PdfWorkbenchMsg]] = [
    row(
      [
        button(
          "Undo Last",
          on_click=UndoLastEdit,
          variant=@views.ButtonVariant::Ghost,
          theme~,
          width=(width - theme.spacing_scale.sm) / 2.0,
          height=34.0,
        ),
        button(
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
  theme : @core.Theme,
) -> @core.View[PdfWorkbenchMsg] {
  let rows : Array[@core.View[PdfWorkbenchMsg]] = [
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
  children : Array[@core.View[PdfWorkbenchMsg]],
  width : Double,
  theme : @core.Theme,
) -> @core.View[PdfWorkbenchMsg] {
  let rows : Array[@core.View[PdfWorkbenchMsg]] = [
    text(title, role=@views.TextRole::Control, theme~, width~, height=24.0),
  ]
  for child in children {
    rows.push(child)
  }
  surface(
    column(
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
  theme : @core.Theme,
) -> @core.View[PdfWorkbenchMsg] {
  text(value, role=@views.TextRole::Caption, theme~, width~, height~).foreground(
    theme.palette.muted,
  )
}

///|
fn pdf_workbench_edit_queue_row(
  edit : PdfWorkbenchEdit,
  index : Int,
  width : Double,
  theme : @core.Theme,
) -> @core.View[PdfWorkbenchMsg] {
  let label = index.to_string() + ". " + pdf_workbench_edit_queue_label(edit)
  surface(
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
fn pdf_workbench_zoom_label(zoom : Double) -> String {
  pdf_workbench_zoom_bucket(zoom).to_string() + "%"
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
