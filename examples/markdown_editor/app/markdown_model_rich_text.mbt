///|
fn markdown_block_to_rich_text(
  block : MarkdownBlock,
  base : @core.FontSpec,
) -> @views.RichTextBlock {
  match block.kind {
    Heading(level) => {
      let font = {
        ..base,
        size: base.size * markdown_heading_size_scale(level),
        weight: 700,
      }
      @views.RichTextBlock::new(
        runs=markdown_inlines_to_rich_text(block.inlines, font),
        font=Some(font),
        line_height=Some(base.size * markdown_heading_line_height_scale(level)),
      )
    }
    UnorderedListItem =>
      @views.RichTextBlock::new(
        runs=markdown_inlines_to_rich_text(block.inlines, base),
        prefix="• ",
        line_height=Some(base.size * 1.55),
      )
    TaskListItem(checked) =>
      @views.RichTextBlock::new(
        runs=markdown_inlines_to_rich_text(block.inlines, base),
        prefix=if checked { "☑ " } else { "☐ " },
        line_height=Some(base.size * 1.55),
      )
    OrderedListItem(number) =>
      @views.RichTextBlock::new(
        runs=markdown_inlines_to_rich_text(block.inlines, base),
        prefix="\{number}. ",
        line_height=Some(base.size * 1.55),
      )
    Blockquote =>
      @views.RichTextBlock::new(
        runs=markdown_inlines_to_rich_text(block.inlines, base),
        color=Some(@core.Color::black().multiply_alpha(0.82)),
        border_left=Some(
          @core.BorderStyle::new(
            brush=@core.Brush::solid(@core.Color::black().multiply_alpha(0.32)),
            width=4.0,
          ),
        ),
        inset={ top: 4.0, right: 0.0, bottom: 12.0, left: 14.0 },
        line_height=Some(base.size * 1.55),
      )
    CodeBlock =>
      @views.RichTextBlock::new(
        runs=markdown_code_block_runs(block, base),
        background=Some(
          @core.Brush::solid(@core.Color::rgba(r=0.12, g=0.13, b=0.15, a=0.08)),
        ),
        inset={ top: 8.0, right: 10.0, bottom: 8.0, left: 10.0 },
        line_height=Some(base.size * 1.1),
        corner_radius=6.0,
      )
    HorizontalRule =>
      @views.RichTextBlock::new(
        runs=[],
        line_height=Some(base.size * 1.0),
        rule=true,
      )
    Table =>
      @views.RichTextBlock::new(
        runs=[
          @views.RichTextRun::new(
            text=block.text,
            font=Some({
              ..base,
              families: @core.FontFamilyStack::monospace(),
              size: base.size * 0.92,
            }),
          ),
        ],
        table=markdown_table_preview(block, base),
        background=Some(
          @core.Brush::solid(@core.Color::rgba(r=0.08, g=0.12, b=0.16, a=0.05)),
        ),
        inset={ top: 6.0, right: 10.0, bottom: 6.0, left: 10.0 },
        line_height=Some(base.size * 1.35),
        corner_radius=6.0,
      )
    FootnoteDefinition(label) =>
      @views.RichTextBlock::new(
        runs=[
          @views.RichTextRun::new(
            text="[^" + label + "]: ",
            visual_text=Some(label),
            font=Some({ ..base, size: base.size * 0.78, weight: 700 }),
            color=Some(@core.Color::black().multiply_alpha(0.58)),
            background=Some(
              @core.Brush::solid(
                @core.Color::rgba(r=0.18, g=0.4, b=0.7, a=0.08),
              ),
            ),
            background_radius=4.0,
          ),
          ..markdown_inlines_to_rich_text(block.inlines, base),
        ],
        color=Some(@core.Color::black().multiply_alpha(0.82)),
        border_left=Some(
          @core.BorderStyle::new(
            brush=@core.Brush::solid(@core.Color::black().multiply_alpha(0.22)),
            width=3.0,
          ),
        ),
        inset={ top: 2.0, right: 0.0, bottom: 2.0, left: 12.0 },
        line_height=Some(base.size * 1.45),
      )
    HtmlBlock =>
      @views.RichTextBlock::new(
        runs=[
          @views.RichTextRun::new(
            text=block.text,
            font=Some({
              ..base,
              families: @core.FontFamilyStack::monospace(),
              size: base.size * 0.9,
            }),
            color=Some(@core.Color::black().multiply_alpha(0.7)),
          ),
        ],
        background=Some(
          @core.Brush::solid(@core.Color::rgba(r=0.12, g=0.12, b=0.12, a=0.06)),
        ),
        inset={ top: 4.0, right: 10.0, bottom: 4.0, left: 10.0 },
        line_height=Some(base.size * 1.25),
        corner_radius=6.0,
      )
    FrontMatter =>
      @views.RichTextBlock::new(
        runs=[
          @views.RichTextRun::new(
            text=block.text,
            font=Some({
              ..base,
              families: @core.FontFamilyStack::monospace(),
              size: base.size * 0.9,
            }),
            color=Some(@core.Color::black().multiply_alpha(0.74)),
          ),
        ],
        background=Some(
          @core.Brush::solid(@core.Color::rgba(r=0.20, g=0.28, b=0.36, a=0.07)),
        ),
        inset={ top: 6.0, right: 10.0, bottom: 6.0, left: 10.0 },
        line_height=Some(base.size * 1.25),
        corner_radius=6.0,
      )
    Paragraph =>
      @views.RichTextBlock::new(
        runs=markdown_inlines_to_rich_text(block.inlines, base),
        line_height=Some(base.size * 1.55),
      )
  }
}

///|
fn markdown_code_block_runs(
  block : MarkdownBlock,
  base : @core.FontSpec,
) -> Array[@views.RichTextRun] {
  let font = {
    ..base,
    families: @core.FontFamilyStack::monospace(),
    size: base.size * 0.92,
  }
  match block.code_language {
    Some(language) =>
      [
        @views.RichTextRun::new(
          text=language,
          font=Some({ ..font, size: base.size * 0.78, weight: 700 }),
          visual_text=Some(language),
          color=Some(@core.Color::black().multiply_alpha(0.56)),
        ),
        @views.RichTextRun::new(text="\n", font=Some(font)),
        @views.RichTextRun::new(text=block.text, font=Some(font)),
      ]
    None => [@views.RichTextRun::new(text=block.text, font=Some(font))]
  }
}

///|
fn markdown_heading_size_scale(level : Int) -> Double {
  if level <= 1 {
    1.45
  } else if level == 2 {
    1.22
  } else if level == 3 {
    1.08
  } else if level == 4 {
    1.0
  } else if level == 5 {
    0.94
  } else {
    0.9
  }
}

///|
fn markdown_heading_line_height_scale(level : Int) -> Double {
  if level <= 1 {
    2.0
  } else if level == 2 {
    1.65
  } else if level == 3 {
    1.45
  } else {
    1.35
  }
}

///|
fn markdown_inlines_to_rich_text(
  inlines : Array[MarkdownInline],
  base : @core.FontSpec,
) -> Array[@views.RichTextRun] {
  let runs : Array[@views.RichTextRun] = []
  for span in inlines {
    runs.push(
      @views.RichTextRun::new(
        text=markdown_inline_source_text(span),
        visual_text=Some(markdown_inline_visual_text(span)),
        image_source=markdown_inline_image_source(span),
        image_size=markdown_inline_image_size(span, base),
        font=Some(markdown_inline_font(span.kind, base)),
        background=markdown_inline_background(span.kind),
        decoration=markdown_inline_decoration(span.kind),
      ),
    )
  }
  runs
}

///|
fn markdown_inline_visual_text(inline : MarkdownInline) -> String {
  match inline.kind {
    Image => markdown_inline_source_text(inline)
    FootnoteReference => inline.text
    _ => inline.text
  }
}

///|
fn markdown_inline_image_source(inline : MarkdownInline) -> String? {
  match inline.kind {
    Image => inline.target
    _ => None
  }
}

///|
fn markdown_inline_image_size(
  inline : MarkdownInline,
  base : @core.FontSpec,
) -> @core.Size? {
  match inline.kind {
    Image =>
      Some(@core.Size::new(width=base.size * 8.0, height=base.size * 4.5))
    _ => None
  }
}

///|
fn markdown_inline_source_text(inline : MarkdownInline) -> String {
  if inline.kind is HtmlInline {
    return markdown_html_inline_source(inline.text)
  }
  if inline.kind is FootnoteReference {
    return "[^" + inline.text + "]"
  }
  if inline.text == "" {
    "image"
  } else {
    inline.text
  }
}

///|
fn markdown_inline_font(
  kind : MarkdownInlineKind,
  font : @core.FontSpec,
) -> @core.FontSpec {
  match kind {
    Bold => { ..font, weight: 700 }
    Italic => { ..font, weight: 500 }
    Strikethrough => { ..font, weight: 400 }
    Link | Autolink => { ..font, weight: 500 }
    Image => { ..font, weight: 600 }
    FootnoteReference => { ..font, size: font.size * 0.76, weight: 700 }
    HtmlInline =>
      {
        ..font,
        families: @core.FontFamilyStack::named("SFMono-Regular")
        .with_fallback(@core.FontFamily::UiMonospace)
        .with_fallback(@core.FontFamily::Monospace),
        size: font.size * 0.9,
      }
    Code =>
      {
        ..font,
        families: @core.FontFamilyStack::named("SFMono-Regular")
        .with_fallback(@core.FontFamily::UiMonospace)
        .with_fallback(@core.FontFamily::Monospace),
        size: font.size * 0.92,
      }
    Plain => font
  }
}

///|
fn markdown_inline_background(kind : MarkdownInlineKind) -> @core.Brush? {
  match kind {
    Code => Some(@core.Brush::solid(@core.Color::black().multiply_alpha(0.08)))
    Image =>
      Some(@core.Brush::solid(@core.Color::rgba(r=0.18, g=0.4, b=0.7, a=0.08)))
    FootnoteReference =>
      Some(@core.Brush::solid(@core.Color::rgba(r=0.18, g=0.4, b=0.7, a=0.08)))
    HtmlInline =>
      Some(@core.Brush::solid(@core.Color::black().multiply_alpha(0.06)))
    Plain | Bold | Italic | Strikethrough | Link | Autolink => None
  }
}

///|
fn markdown_inline_decoration(
  kind : MarkdownInlineKind,
) -> @views.RichTextDecoration? {
  match kind {
    Strikethrough => Some(@views.RichTextDecoration::Strikethrough)
    Plain
    | Bold
    | Italic
    | Code
    | Link
    | Autolink
    | Image
    | FootnoteReference
    | HtmlInline => None
  }
}
