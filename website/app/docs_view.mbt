///|
fn Model::docs_content(
  self : Model,
  theme : @moui.Theme,
  metrics : Metrics,
) -> @moui.View[Msg] {
  let doc_width = if metrics.compact {
    metrics.content_width
  } else {
    metrics.content_width - metrics.docs_sidebar_width - 24.0
  }
  let content = if metrics.compact {
    column(
      [
        docs_header(theme, metrics.content_width),
        self.docs_sidebar(theme, metrics.docs_sidebar_width),
        self.docs_document_panel(theme, doc_width),
      ],
      spacing=18.0,
      align=@views.CrossAlign::Start,
    )
  } else {
    column(
      [
        docs_header(theme, metrics.content_width),
        row(
          [
            self.docs_sidebar(theme, metrics.docs_sidebar_width),
            self.docs_document_panel(theme, doc_width),
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
    bottom=80.0,
    background=Some(theme.palette.surface_variant.multiply_alpha(0.28)),
  )
}

///|
fn docs_header(theme : @moui.Theme, width : Double) -> @moui.View[Msg] {
  column(
    [
      badge("Runtime docs", tone=@views.BadgeTone::Accent, theme~, width=112.0),
      docs_start_text(
        "MoUI Markdown Docs",
        width~,
        height=38.0,
        font=@core.FontSpec::new(size=30.0, weight=820),
        color=theme.palette.foreground,
      ),
      docs_start_text(
        "Markdown files stay in docs/ and the Web host fetches them at runtime.",
        width~,
        height=30.0,
        font=theme.typography.caption,
        color=theme.palette.muted,
      ),
    ],
    spacing=6.0,
    align=@views.CrossAlign::Start,
  )
}

///|
fn Model::docs_sidebar(
  self : Model,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[Msg] {
  let rows : Array[@moui.View[Msg]] = []
  for entry in website_docs_entries() {
    let selected = entry.slug == self.selected_doc_slug
    rows.push(
      button(
        entry.title,
        on_click=SelectDoc(entry.slug),
        variant=@views.ButtonVariant::Ghost,
        theme~,
        width=width - 28.0,
        height=34.0,
      )
      .foreground(
        if selected {
          theme.palette.primary
        } else {
          theme.palette.foreground
        },
      )
      .accessibility_label("Open " + entry.title),
    )
  }
  container(
    column(
      [
        docs_start_text(
          "Docs",
          width=width - 28.0,
          height=26.0,
          font=@core.FontSpec::new(size=17.0, weight=780),
          color=theme.palette.foreground,
        ),
        docs_start_text(
          "Static Markdown sources",
          width=width - 28.0,
          height=22.0,
          font=theme.typography.caption,
          color=theme.palette.muted,
        ),
        column(rows, spacing=4.0, align=@views.CrossAlign::Start),
      ],
      spacing=10.0,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height=website_docs_sidebar_height(),
    background=soft_panel_background(theme),
    corner_radius=8.0,
    theme~,
    padding=14.0,
  ).border(website_border(theme))
}

///|
fn Model::docs_document_panel(
  self : Model,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[Msg] {
  match self.doc_state {
    DocLoaded(path, document) =>
      container(
        column(
          [
            docs_document_header(
              theme,
              website_doc_entry_by_path(path),
              document.title,
              width - 40.0,
            ),
            docs_document_blocks(theme, document, width - 40.0),
          ],
          spacing=18.0,
          align=@views.CrossAlign::Start,
        ),
        width~,
        height=website_doc_loaded_height(document, width),
        background=theme.palette.surface,
        corner_radius=8.0,
        theme~,
        padding=20.0,
      ).border(website_border(theme))
    DocLoading(_, path) =>
      docs_status_panel(
        theme,
        width,
        "Loading Markdown",
        website_doc_entry_by_path(path).path,
        RetryDoc,
        "Retry",
      )
    DocFailed(path, reason) =>
      docs_status_panel(
        theme,
        width,
        "Could not load Markdown",
        website_doc_entry_by_path(path).path + "\n" + reason,
        RetryDoc,
        "Retry",
      )
    DocNotLoaded => {
      let entry = self.website_doc_selected_entry()
      docs_status_panel(
        theme,
        width,
        "Select a document",
        entry.path,
        RetryDoc,
        "Load",
      )
    }
  }
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
        height=38.0,
        font=@core.FontSpec::new(size=27.0, weight=820),
        color=theme.palette.foreground,
      ),
      docs_start_text(
        entry.summary,
        width~,
        height=24.0,
        font=theme.typography.caption,
        color=theme.palette.muted,
      ),
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
          font=@core.FontSpec::new(size=22.0, weight=780),
          color=theme.palette.foreground,
        ),
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
fn docs_document_blocks(
  theme : @moui.Theme,
  document : WebsiteDocDocument,
  width : Double,
) -> @moui.View[Msg] {
  let blocks : Array[@moui.View[Msg]] = []
  for block in document.blocks {
    blocks.push(docs_block_view(theme, block, width))
  }
  column(blocks, spacing=10.0, align=@views.CrossAlign::Start)
}

///|
fn docs_block_view(
  theme : @moui.Theme,
  block : WebsiteDocBlock,
  width : Double,
) -> @moui.View[Msg] {
  match block {
    DocHeading(level, value) => {
      let size = website_doc_heading_font_size(level)
      docs_wrapped_text(theme, value, width, size, size * 1.28, muted=false)
    }
    DocParagraph(value) =>
      docs_wrapped_text(theme, value, width, 14.5, 23.0, muted=false)
    DocListItem(marker, value) =>
      docs_wrapped_text(
        theme,
        website_doc_marker_label(marker) + " " + value,
        width,
        14.0,
        22.0,
        muted=false,
      )
    DocQuote(value) =>
      container(
        docs_wrapped_text(theme, value, width - 28.0, 14.0, 22.0, muted=true),
        width~,
        height=website_doc_text_block_height(value, width - 28.0, 14.0, 22.0) +
          20.0,
        background=theme.palette.surface_variant.multiply_alpha(0.52),
        corner_radius=6.0,
        theme~,
        padding=10.0,
      ).border(accent_border(theme, theme.palette.primary.multiply_alpha(0.38)))
    DocCodeBlock(language, value) =>
      docs_code_panel(theme, language, value, width)
    DocTable(lines) => docs_table_panel(theme, lines, width)
    DocRule => docs_rule(theme, width)
  }
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
  let lines = website_doc_wrap_lines(value, width, font_size)
  let rows : Array[@moui.View[Msg]] = []
  let font = @core.FontSpec::new(
    size=font_size,
    weight=if font_size >= 20.0 { 760 } else { 460 },
  )
  for line in lines {
    rows.push(
      docs_start_text(
        line,
        width~,
        height=line_height,
        font~,
        color=if muted { theme.palette.muted } else { theme.palette.foreground },
      ),
    )
  }
  column(rows, spacing=0.0, align=@views.CrossAlign::Start)
}

///|
fn docs_start_text(
  value : String,
  width~ : Double,
  height~ : Double,
  font~ : @core.FontSpec,
  color~ : @core.Color,
) -> @moui.View[Msg] {
  custom_layout(
    measure=_constraints => @moui.Size::new(width~, height~),
    paint=(ctx, frame) => {
      draw_text(
        ctx,
        @core.TextRun::new(
          text=value,
          frame=frame,
          font~,
          color~,
          align=@core.TextAlign::TextStart,
        ),
      )
    },
    semantics_label=value,
  )
}

///|
fn docs_code_panel(
  theme : @moui.Theme,
  language : String,
  value : String,
  width : Double,
) -> @moui.View[Msg] {
  let code_width = width - 28.0
  let rows : Array[@moui.View[Msg]] = []
  if language != "" {
    rows.push(
      docs_start_text(
        language,
        width=code_width,
        height=18.0,
        font=@core.FontSpec::new(size=11.0, weight=760),
        color=theme.palette.muted,
      ),
    )
  }
  for line in website_doc_code_lines(value, code_width, 12.5) {
    rows.push(
      docs_start_text(
        line,
        width=code_width,
        height=18.0,
        font=website_doc_mono_font(12.5),
        color=code_snippet_foreground(theme),
      ),
    )
  }
  container(
    column(rows, spacing=0.0, align=@views.CrossAlign::Start),
    width~,
    height=website_doc_code_height(language, value, width),
    background=code_panel_background(theme),
    corner_radius=7.0,
    theme~,
    padding=14.0,
  ).border(website_border(theme))
}

///|
fn docs_table_panel(
  theme : @moui.Theme,
  lines : Array[String],
  width : Double,
) -> @moui.View[Msg] {
  let code_width = width - 28.0
  let rows : Array[@moui.View[Msg]] = []
  for line in lines {
    for wrapped in website_doc_wrap_lines(line, code_width, 12.0) {
      rows.push(
        docs_start_text(
          wrapped,
          width=code_width,
          height=18.0,
          font=website_doc_mono_font(12.0),
          color=theme.palette.foreground,
        ),
      )
    }
  }
  container(
    column(rows, spacing=0.0, align=@views.CrossAlign::Start),
    width~,
    height=website_doc_table_height(lines, width),
    background=theme.palette.surface_variant.multiply_alpha(0.50),
    corner_radius=7.0,
    theme~,
    padding=14.0,
  ).border(website_border(theme))
}

///|
fn docs_rule(theme : @moui.Theme, width : Double) -> @moui.View[Msg] {
  custom_layout(
    measure=_constraints => @moui.Size::new(width~, height=22.0),
    paint=(ctx, frame) => {
      fill_rect(
        ctx,
        @core.Rect::new(
          x=frame.origin.x,
          y=frame.origin.y + frame.size.height / 2.0,
          width=frame.size.width,
          height=1.0,
        ),
        theme.palette.outline.multiply_alpha(0.35),
      )
    },
    semantics_label="Document rule",
  )
}

///|
fn Model::website_docs_content_height(
  self : Model,
  metrics : Metrics,
) -> Double {
  let doc_width = if metrics.compact {
    metrics.content_width
  } else {
    metrics.content_width - metrics.docs_sidebar_width - 24.0
  }
  let doc_height = match self.doc_state {
    DocLoaded(_, document) => website_doc_loaded_height(document, doc_width)
    _ => 190.0
  }
  let content_height = if metrics.compact {
    34.0 +
    110.0 +
    18.0 +
    website_docs_sidebar_height() +
    18.0 +
    doc_height +
    80.0
  } else {
    34.0 +
    110.0 +
    20.0 +
    max_website_double(website_docs_sidebar_height(), doc_height) +
    80.0
  }
  max_website_double(metrics.body_height, content_height)
}

///|
fn website_doc_loaded_height(
  document : WebsiteDocDocument,
  width : Double,
) -> Double {
  let inner_width = width - 40.0
  20.0 +
  38.0 +
  8.0 +
  24.0 +
  8.0 +
  28.0 +
  18.0 +
  website_doc_blocks_height(document, inner_width) +
  20.0
}

///|
fn website_doc_blocks_height(
  document : WebsiteDocDocument,
  width : Double,
) -> Double {
  let mut height = 0.0
  for block in document.blocks {
    height = height + website_doc_block_height(block, width) + 10.0
  }
  height
}

///|
fn website_doc_block_height(block : WebsiteDocBlock, width : Double) -> Double {
  match block {
    DocHeading(level, value) => {
      let size = website_doc_heading_font_size(level)
      website_doc_text_block_height(value, width, size, size * 1.28)
    }
    DocParagraph(value) =>
      website_doc_text_block_height(value, width, 14.5, 23.0)
    DocListItem(marker, value) =>
      website_doc_text_block_height(
        website_doc_marker_label(marker) + " " + value,
        width,
        14.0,
        22.0,
      )
    DocQuote(value) =>
      website_doc_text_block_height(value, width - 28.0, 14.0, 22.0) + 20.0
    DocCodeBlock(language, value) =>
      website_doc_code_height(language, value, width)
    DocTable(lines) => website_doc_table_height(lines, width)
    DocRule => 22.0
  }
}

///|
fn website_doc_text_block_height(
  value : String,
  width : Double,
  font_size : Double,
  line_height : Double,
) -> Double {
  website_doc_wrap_lines(value, width, font_size).length().to_double() *
  line_height
}

///|
fn website_doc_code_height(
  language : String,
  value : String,
  width : Double,
) -> Double {
  let code_width = width - 28.0
  let language_rows = if language == "" { 0 } else { 1 }
  (website_doc_code_lines(value, code_width, 12.5).length() + language_rows).to_double() *
  18.0 +
  28.0
}

///|
fn website_doc_table_height(lines : Array[String], width : Double) -> Double {
  let code_width = width - 28.0
  let mut count = 0
  for line in lines {
    count = count + website_doc_wrap_lines(line, code_width, 12.0).length()
  }
  max_website_double(1.0, count.to_double()) * 18.0 + 28.0
}

///|
fn website_doc_code_lines(
  value : String,
  width : Double,
  font_size : Double,
) -> Array[String] {
  let lines : Array[String] = []
  if value == "" {
    lines.push("")
  } else {
    for line in value.split("\n") {
      lines.append(website_doc_wrap_lines(line.to_owned(), width, font_size))
    }
  }
  lines
}

///|
fn website_doc_wrap_lines(
  value : String,
  width : Double,
  font_size : Double,
) -> Array[String] {
  let limit = max_website_int(8, (width / (font_size * 0.56)).to_int())
  let lines : Array[String] = []
  if value == "" {
    lines.push("")
    return lines
  }
  for source_line in value.split("\n") {
    let chars = source_line.to_owned().to_array()
    if chars.length() == 0 {
      lines.push("")
    } else {
      let mut start = 0
      while start < chars.length() {
        let end = min_website_int(chars.length(), start + limit)
        lines.push(String::from_array(chars[start:end]))
        start = end
      }
    }
  }
  lines
}

///|
fn website_doc_marker_label(marker : String) -> String {
  match marker {
    "x" => "[x]"
    " " => "[ ]"
    "-" => "-"
    _ => marker
  }
}

///|
fn website_doc_heading_font_size(level : Int) -> Double {
  if level <= 1 {
    25.0
  } else if level == 2 {
    21.0
  } else if level == 3 {
    18.0
  } else {
    16.0
  }
}

///|
fn website_doc_mono_font(size : Double) -> @core.FontSpec {
  @core.FontSpec::new(
    families=@core.FontFamilyStack::monospace(),
    size~,
    weight=520,
  )
}

///|
fn website_doc_tag_width(width : Double) -> Double {
  clamp_website_double(width * 0.76, 220.0, width)
}

///|
fn website_docs_sidebar_height() -> Double {
  26.0 + 22.0 + 10.0 + website_docs_entries().length().to_double() * 38.0 + 28.0
}

///|
fn max_website_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn min_website_int(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}
