///|
fn pdf_workbench_preview_canvas(
  page : PdfWorkbenchPageSummary,
  document : PdfWorkbenchDocument?,
  raster_page : PdfWorkbenchRasterPage?,
  raster_status : PdfWorkbenchRasterStatus,
  zoom : Double,
  metrics : PdfWorkbenchLayoutMetrics,
  theme : @moui.Theme,
) -> @moui.View[PdfWorkbenchMsg] {
  custom_layout(
    measure=_ => pdf_workbench_preview_content_size(raster_page, zoom, metrics),
    paint=(ctx, frame) => {
      let page_size = pdf_workbench_preview_page_size(
        raster_page, zoom, metrics,
      )
      let page_width = page_size.width
      let page_height = page_size.height
      let x = frame.origin.x + (frame.size.width - page_width) / 2.0
      let y = frame.origin.y + 36.0
      let page_rect = @geometry.Rect::new(
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
      fill_rect(ctx, frame, theme.palette.surface_variant)
      fill_rect(ctx, page_rect, @graphics.Color::white())
      match raster_page {
        Some(raster) =>
          draw_image(ctx, @views.ImageRun::{
            source: raster.image_source,
            frame: page_rect,
            opacity: 1.0,
            fit: @views.ImageFit::Contain,
          })
        None => {
          draw_text(
            ctx,
            @text.TextRun::new(
              text=loaded_title,
              frame=@geometry.Rect::new(
                x=x + 24.0,
                y=y + 28.0,
                width=page_width - 48.0,
                height=28.0,
              ),
              font=@text.FontSpec::new(size=18.0),
              color=theme.palette.foreground,
              align=@text.TextAlign::TextStart,
            ),
          )
          draw_text(
            ctx,
            @text.TextRun::new(
              text=file_line,
              frame=@geometry.Rect::new(
                x=x + 24.0,
                y=y + 62.0,
                width=page_width - 48.0,
                height=24.0,
              ),
              font=@text.FontSpec::new(size=12.0),
              color=theme.palette.muted,
              align=@text.TextAlign::TextStart,
            ),
          )
          draw_text(
            ctx,
            @text.TextRun::new(
              text=page.text_preview,
              frame=@geometry.Rect::new(
                x=x + 24.0,
                y=y + 104.0,
                width=page_width - 48.0,
                height=160.0,
              ),
              font=@text.FontSpec::new(size=14.0),
              color=theme.palette.foreground,
              align=@text.TextAlign::TextStart,
            ),
          )
          draw_text(
            ctx,
            @text.TextRun::new(
              text=page.content_diagnostic,
              frame=@geometry.Rect::new(
                x=x + 24.0,
                y=y + page_height - 92.0,
                width=page_width - 48.0,
                height=32.0,
              ),
              font=@text.FontSpec::new(size=12.0),
              color=theme.palette.muted,
              align=@text.TextAlign::TextStart,
            ),
          )
        }
      }
      stroke_rect(ctx, page_rect, theme.palette.outline, 1.0)
      match document {
        Some(document) =>
          pdf_workbench_push_page_edit_overlays(ctx, document, page_rect, theme)
        None => ()
      }
      draw_text(
        ctx,
        @text.TextRun::new(
          text=pdf_workbench_raster_status_label(raster_status),
          frame=@geometry.Rect::new(
            x=frame.origin.x + 16.0,
            y=frame.origin.y + 4.0,
            width=frame.size.width - 32.0,
            height=20.0,
          ),
          font=@text.FontSpec::new(size=12.0),
          color=theme.palette.muted,
          align=@text.TextAlign::TextStart,
        ),
      )
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
) -> @geometry.Size {
  let aspect = pdf_workbench_preview_aspect(raster_page)
  let available_width = (metrics.preview_width - 32.0).max(120.0)
  let page_width = (available_width * pdf_workbench_preview_display_zoom(zoom)).max(
    120.0,
  )
  @geometry.Size::new(width=page_width, height=(page_width / aspect).max(120.0))
}

///|
fn pdf_workbench_preview_content_size(
  raster_page : PdfWorkbenchRasterPage?,
  zoom : Double,
  metrics : PdfWorkbenchLayoutMetrics,
) -> @geometry.Size {
  let page_size = pdf_workbench_preview_page_size(raster_page, zoom, metrics)
  @geometry.Size::new(
    width=(page_size.width + 32.0).max(metrics.preview_width),
    height=(page_size.height + 72.0).max(metrics.preview_height),
  )
}

///|
fn pdf_workbench_push_page_edit_overlays(
  ctx : PaintContext,
  document : PdfWorkbenchDocument,
  page_rect : @geometry.Rect,
  theme : @moui.Theme,
) -> Unit {
  let mut stamp_index = 0
  let mut note_index = 0
  for edit in document.edits {
    match edit {
      StampText(page, value) =>
        if page == document.selected_page {
          let stamp_width = 104.0
          let stamp_height = 28.0
          let stamp_rect = @geometry.Rect::new(
            x=page_rect.origin.x + page_rect.size.width - stamp_width - 18.0,
            y=page_rect.origin.y + 18.0 + stamp_index.to_double() * 34.0,
            width=stamp_width,
            height=stamp_height,
          )
          fill_rect(ctx, stamp_rect, theme.palette.primary.multiply_alpha(0.12))
          stroke_rect(
            ctx,
            stamp_rect,
            theme.palette.primary.multiply_alpha(0.72),
            1.0,
          )
          draw_text(
            ctx,
            @text.TextRun::new(
              text=value,
              frame=stamp_rect,
              font=@text.FontSpec::new(size=12.0),
              color=theme.palette.primary,
              align=@text.TextAlign::TextCenter,
            ),
          )
          stamp_index = stamp_index + 1
        }
      AddTextAnnotation(page, value) =>
        if page == document.selected_page {
          let note_width = 168.0
          let note_height = 46.0
          let note_rect = @geometry.Rect::new(
            x=page_rect.origin.x + 18.0,
            y=page_rect.origin.y + 18.0 + note_index.to_double() * 52.0,
            width=note_width,
            height=note_height,
          )
          fill_rect(ctx, note_rect, theme.palette.primary.multiply_alpha(0.10))
          stroke_rect(
            ctx,
            note_rect,
            theme.palette.primary.multiply_alpha(0.58),
            1.0,
          )
          draw_text(
            ctx,
            @text.TextRun::new(
              text=value,
              frame=@geometry.Rect::new(
                x=note_rect.origin.x + 8.0,
                y=note_rect.origin.y + 7.0,
                width=note_rect.size.width - 16.0,
                height=note_rect.size.height - 14.0,
              ),
              font=@text.FontSpec::new(size=11.0),
              color=theme.palette.primary,
              align=@text.TextAlign::TextStart,
            ),
          )
          note_index = note_index + 1
        }
      _ => ()
    }
  }
}
