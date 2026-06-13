///|
fn PdfWorkbenchModel::select_page_delta(
  self : PdfWorkbenchModel,
  delta : Int,
) -> PdfWorkbenchModel {
  match self.document {
    Some(document) => {
      let next = pdf_workbench_clamp_int(
        document.selected_page + delta,
        1,
        document.page_count,
      )
      {
        ..self,
        document: Some({ ..document, selected_page: next }),
        page_number_draft: next.to_string(),
        preview_scroll_offset: if next == document.selected_page {
          self.preview_scroll_offset
        } else {
          @core.Point::new(x=0.0, y=0.0)
        },
      }
    }
    None => self
  }
}

///|
fn PdfWorkbenchModel::select_page(
  self : PdfWorkbenchModel,
  page : Int,
) -> PdfWorkbenchModel {
  match self.document {
    Some(document) => {
      let selected = pdf_workbench_clamp_int(page, 1, document.page_count)
      {
        ..self,
        document: Some({ ..document, selected_page: selected }),
        page_number_draft: selected.to_string(),
        preview_scroll_offset: if selected == document.selected_page {
          self.preview_scroll_offset
        } else {
          @core.Point::new(x=0.0, y=0.0)
        },
      }
    }
    None => self
  }
}

///|
fn PdfWorkbenchModel::with_zoom(
  self : PdfWorkbenchModel,
  zoom : Double,
) -> PdfWorkbenchModel {
  let clamped = if zoom < 0.5 { 0.5 } else if zoom > 2.0 { 2.0 } else { zoom }
  {
    ..self,
    zoom: clamped,
    preview_scroll_offset: if clamped == self.zoom {
      self.preview_scroll_offset
    } else {
      @core.Point::new(x=0.0, y=0.0)
    },
  }
}

///|
fn PdfWorkbenchModel::scroll_preview(
  self : PdfWorkbenchModel,
  delta : @core.Point,
) -> PdfWorkbenchModel {
  {
    ..self,
    preview_scroll_offset: @core.Point::new(
      x=(self.preview_scroll_offset.x - delta.x).max(0.0),
      y=(self.preview_scroll_offset.y - delta.y).max(0.0),
    ),
  }
}

///|
fn PdfWorkbenchModel::toggle_reader_fullscreen(
  self : PdfWorkbenchModel,
) -> PdfWorkbenchModel {
  let next_fullscreen = !self.reader_fullscreen
  {
    ..self,
    reader_fullscreen: next_fullscreen,
    last_event: if next_fullscreen {
      "Reader filled window"
    } else {
      "Reader restored panels"
    },
  }
}

///|
fn PdfWorkbenchModel::reset_panel_scrolls(self : PdfWorkbenchModel) -> Unit {
  self.sidebar_scroll.scroll_to(x=0.0, y=0.0)
  self.inspector_scroll.scroll_to(x=0.0, y=0.0)
}

///|
fn PdfWorkbenchModel::select_next_search_result(
  self : PdfWorkbenchModel,
) -> PdfWorkbenchModel {
  self.select_search_result(true)
}

///|
fn PdfWorkbenchModel::select_previous_search_result(
  self : PdfWorkbenchModel,
) -> PdfWorkbenchModel {
  self.select_search_result(false)
}

///|
fn PdfWorkbenchModel::select_search_result(
  self : PdfWorkbenchModel,
  forward : Bool,
) -> PdfWorkbenchModel {
  match self.document {
    Some(document) => {
      let target = if forward {
        document.next_search_page(self.query)
      } else {
        document.previous_search_page(self.query)
      }
      match target {
        Some(page) =>
          {
            ..self,
            document: Some({ ..document, selected_page: page }),
            page_number_draft: page.to_string(),
            preview_scroll_offset: if page == document.selected_page {
              self.preview_scroll_offset
            } else {
              @core.Point::new(x=0.0, y=0.0)
            },
            last_event: "Search matched page " +
            page.to_string() +
            pdf_workbench_search_position_suffix(document, self.query, page),
          }
        None =>
          {
            ..self,
            last_event: if self.query.trim().to_owned() == "" {
              "Enter search text before finding"
            } else {
              "No page matches for search"
            },
          }
      }
    }
    None => { ..self, last_event: "Open a PDF before searching" }
  }
}

///|
fn PdfWorkbenchModel::with_search_query(
  self : PdfWorkbenchModel,
  query : String,
) -> PdfWorkbenchModel {
  let needle = query.trim().to_owned()
  let last_event = if needle == "" {
    "Search cleared"
  } else {
    match self.document {
      Some(document) => {
        let matches = document.search_count(query)
        if matches == 0 {
          "Search found no matching pages"
        } else if matches == 1 {
          "Search found 1 matching page"
        } else {
          "Search found " + matches.to_string() + " matching pages"
        }
      }
      None => "Open a PDF before searching"
    }
  }
  { ..self, query, last_event }
}

///|
fn PdfWorkbenchModel::go_to_page_number(
  self : PdfWorkbenchModel,
) -> PdfWorkbenchModel {
  match self.document {
    Some(document) =>
      match pdf_workbench_parse_positive_int(self.page_number_draft) {
        Some(page) => {
          let selected = pdf_workbench_clamp_int(page, 1, document.page_count)
          {
            ..self,
            document: Some({ ..document, selected_page: selected }),
            page_number_draft: selected.to_string(),
            preview_scroll_offset: if selected == document.selected_page {
              self.preview_scroll_offset
            } else {
              @core.Point::new(x=0.0, y=0.0)
            },
            last_event: if selected == page {
              "Jumped to page " + selected.to_string()
            } else {
              "Jumped to nearest page " + selected.to_string()
            },
          }
        }
        None =>
          {
            ..self,
            page_number_draft: document.selected_page.to_string(),
            last_event: "Enter a valid page number",
          }
      }
    None =>
      {
        ..self,
        page_number_draft: "",
        last_event: "Open a PDF before jumping to a page",
      }
  }
}
