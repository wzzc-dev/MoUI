///|
using @views {
  type PaintContext,
  custom_layout,
  fill_rect,
  stroke_rect,
  draw_text,
  draw_image,
}

///|
fn pdf_workbench_sidebar(
  model : PdfWorkbenchModel,
  metrics : PdfWorkbenchLayoutMetrics,
  theme : @moui.Theme,
) -> @moui.View[PdfWorkbenchMsg] {
  let rows : Array[@moui.View[PdfWorkbenchMsg]] = []
  let item_width = pdf_workbench_panel_item_width(
    metrics.sidebar_scroll_width,
    theme,
  )
  match model.document {
    Some(document) => {
      let search_matches = document.search_match_pages(model.query)
      rows.push(
        @views.stat_card(
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
        @views.banner(
          "No PDF loaded",
          "Use Open to load PDF bytes through the host binary file service.",
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
      width=metrics.sidebar_scroll_width,
      height=pdf_workbench_panel_scroll_height(metrics, theme),
      offset=model.sidebar_scroll.offset(),
      state=Some(model.sidebar_scroll),
    ),
    width=metrics.sidebar_width,
    height=metrics.body_height,
    variant=@views.ContainerVariant::Raised,
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
  theme : @moui.Theme,
) -> @moui.View[PdfWorkbenchMsg] {
  let control_width = (width - 68.0).max(110.0)
  @views.row(
    [
      pdf_workbench_page_thumbnail(summary, selected~, thumbnail_raster~, theme),
      @views.column(
        [
          @views.button(
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
          @views.text(
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
  theme : @moui.Theme,
) -> @moui.View[PdfWorkbenchMsg] {
  custom_layout(
    measure=_ => @geometry.Size::new(width=54.0, height=68.0),
    paint=(ctx, frame) => {
      let page_width = 40.0
      let page_height = 56.0
      let x = frame.origin.x + (frame.size.width - page_width) / 2.0
      let y = frame.origin.y + (frame.size.height - page_height) / 2.0
      let page_rect = @geometry.Rect::new(
        x~,
        y~,
        width=page_width,
        height=page_height,
      )
      if selected {
        fill_rect(ctx, frame, theme.palette.primary.multiply_alpha(0.10))
      }
      fill_rect(ctx, page_rect, @graphics.Color::white())
      match thumbnail_raster {
        Some(raster) =>
          draw_image(ctx, @graphics.ImageRun::{
            source: raster.image_source,
            frame: page_rect,
            opacity: 1.0,
            fit: @graphics.ImageFit::Contain,
          })
        None => ()
      }
      stroke_rect(
        ctx,
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
      )
      let line_color = if selected {
        theme.palette.primary.multiply_alpha(0.42)
      } else {
        theme.palette.muted.multiply_alpha(0.48)
      }
      match thumbnail_raster {
        Some(_) => {
          let label_rect = @geometry.Rect::new(
            x=x + 5.0,
            y=y + page_height - 17.0,
            width=page_width - 10.0,
            height=13.0,
          )
          fill_rect(ctx, label_rect, theme.palette.surface.multiply_alpha(0.82))
        }
        None =>
          for index in 0..<4 {
            let line_y = y + 14.0 + index.to_double() * 7.0
            let line_width = if index == 3 { 18.0 } else { 26.0 }
            fill_rect(
              ctx,
              @geometry.Rect::new(
                x=x + 7.0,
                y=line_y,
                width=line_width,
                height=2.0,
              ),
              line_color,
            )
          }
      }
      draw_text(
        ctx,
        @text.TextRun::new(
          text=summary.page_number.to_string(),
          frame=@geometry.Rect::new(
            x=x + 7.0,
            y=y + page_height - 16.0,
            width=page_width - 14.0,
            height=12.0,
          ),
          font=@text.FontSpec::new(size=10.0),
          color=if selected {
            theme.palette.primary
          } else {
            theme.palette.muted
          },
          align=@text.TextAlign::TextCenter,
        ),
      )
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
