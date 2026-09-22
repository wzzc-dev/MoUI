///|
pub fn markdown_block_to_rich_text(
  block : MarkdownBlock,
  base : @core.FontSpec,
  base_dir? : String? = None,
) -> RichTextBlock {
  match block.kind {
    Heading(level) => {
      let font = {
        ..base,
        size: base.size * markdown_heading_size_scale(level),
        weight: 700,
      }
      // GitHub-like rhythm: big titles get a full blank line above and half
      // below; smaller headings keep the tighter Typora-style spacing.
      let inset : @core.Insets = if level <= 2 {
        { top: base.size * 1.0, right: 0.0, bottom: base.size * 0.5, left: 0.0 }
      } else {
        { top: base.size * 0.6, right: 0.0, bottom: base.size * 0.3, left: 0.0 }
      }
      RichTextBlock::new(
        runs=markdown_inlines_to_rich_text(block.inlines, font, base_dir~),
        font=Some(font),
        line_height=Some(base.size * markdown_heading_line_height_scale(level)),
        inset~,
      )
    }
    UnorderedListItem =>
      RichTextBlock::new(
        runs=markdown_inlines_to_rich_text(block.inlines, base, base_dir~),
        prefix="• ",
        line_height=Some(base.size * 1.55),
        // Typora-style breathing room between list items; the last item of
        // a list gets paragraph spacing from the following blank-gap block.
        inset={ top: 0.0, right: 0.0, bottom: base.size * 0.25, left: 0.0 },
      )
    TaskListItem(checked) =>
      RichTextBlock::new(
        runs=markdown_inlines_to_rich_text(block.inlines, base, base_dir~),
        // One placeholder char keeps prefix-indexed caret, selection, and
        // hit-test arithmetic intact; the painter draws the vector checkbox at
        // the lane width instead of this glyph.
        prefix=" ",
        marker=Some(RichTextMarker::TaskCheckbox(checked)),
        line_height=Some(base.size * 1.55),
        inset={ top: 0.0, right: 0.0, bottom: base.size * 0.25, left: 0.0 },
      )
    OrderedListItem(number) =>
      RichTextBlock::new(
        runs=markdown_inlines_to_rich_text(block.inlines, base, base_dir~),
        prefix="\{number}. ",
        line_height=Some(base.size * 1.55),
        inset={ top: 0.0, right: 0.0, bottom: base.size * 0.25, left: 0.0 },
      )
    Blockquote =>
      RichTextBlock::new(
        runs=markdown_inlines_to_rich_text(block.inlines, base, base_dir~),
        color=Some(@core.Color::black().multiply_alpha(0.82)),
        background=Some(
          @core.Brush::solid(@core.Color::rgba(r=0.12, g=0.13, b=0.15, a=0.05)),
        ),
        border_left=Some(
          @core.BorderStyle::new(
            brush=@core.Brush::solid(@core.Color::black().multiply_alpha(0.32)),
            width=4.0,
          ),
        ),
        inset={ top: 6.0, right: 0.0, bottom: 6.0, left: 14.0 },
        line_height=Some(base.size * 1.55),
        corner_radius=4.0,
      )
    CodeBlock =>
      RichTextBlock::new(
        runs=markdown_code_block_runs(block, base),
        background=Some(
          @core.Brush::solid(@core.Color::rgba(r=0.12, g=0.13, b=0.15, a=0.06)),
        ),
        inset={ top: 12.0, right: 14.0, bottom: 0.0, left: 14.0 },
        // 1.3x the base font is 1.4x the 0.92 code font, so descenders in code
        // stay inside the line box the painter clips to.
        line_height=Some(base.size * 1.3),
        corner_radius=8.0,
      )
    HorizontalRule =>
      RichTextBlock::new(runs=[], line_height=Some(base.size * 1.0), rule=true)
    Table =>
      RichTextBlock::new(
        runs=[
          RichTextRun::new(
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
      RichTextBlock::new(
        runs=[
          RichTextRun::new(
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
          ..markdown_inlines_to_rich_text(block.inlines, base, base_dir~),
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
      match markdown_block_view_project(block, base, base_dir~) {
        Some(projection) =>
          RichTextBlock::new(
            runs=projection.runs,
            // Generous outer insets so consecutive html blocks (a badge row
            // followed by another badge block) read as separate lines.
            inset={ top: 8.0, right: 0.0, bottom: 10.0, left: 0.0 },
            line_height=Some(base.size * 1.45),
            line_align=projection.line_align,
          )
        None => markdown_html_raw_block_rich_text(block.text, base)
      }
    FrontMatter =>
      RichTextBlock::new(
        runs=[
          RichTextRun::new(
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
      RichTextBlock::new(
        runs=markdown_inlines_to_rich_text(block.inlines, base, base_dir~),
        line_height=Some(base.size * 1.55),
        // Paragraph spacing below for readability between blocks.
        inset={ top: 0.0, right: 0.0, bottom: base.size * 0.4, left: 0.0 },
      )
  }
}

///|
/// Keep all HTML outside the explicit image-gallery subset visibly raw. This
/// preserves the existing safe fallback instead of turning the rich-text view
/// into a general HTML renderer.
fn markdown_html_raw_block_rich_text(
  html : String,
  base : @core.FontSpec,
) -> RichTextBlock {
  RichTextBlock::new(
    runs=[
      RichTextRun::new(
        text=html,
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
    inset={ top: 6.0, right: 10.0, bottom: 6.0, left: 10.0 },
    // ~1.67x the monospace run size (editor-style leading) so multi-line
    // markup reads line by line instead of stacking on itself.
    line_height=Some(base.size * 1.5),
    corner_radius=6.0,
  )
}

///|
fn markdown_code_block_runs(
  block : MarkdownBlock,
  base : @core.FontSpec,
) -> Array[RichTextRun] {
  let font = {
    ..base,
    families: @core.FontFamilyStack::monospace(),
    size: base.size * 0.92,
  }
  match block.code_language {
    Some(language) => {
      let runs : Array[RichTextRun] = [
        RichTextRun::new(
          text=language,
          font=Some({ ..font, size: base.size * 0.78, weight: 700 }),
          visual_text=Some(language),
          color=Some(@core.Color::black().multiply_alpha(0.56)),
        ),
        RichTextRun::new(text="\n", font=Some(font)),
      ]
      // Apply syntax highlighting when the language is supported; otherwise emit
      // the source as a single plain run.
      if code_highlight_supports_language(language) {
        for span in code_highlight_tokenize(block.text, language) {
          let color = if span.kind is CodePlain {
            None
          } else {
            Some(code_highlight_color(span.kind))
          }
          runs.push(RichTextRun::new(text=span.text, font=Some(font), color~))
        }
      } else {
        runs.push(RichTextRun::new(text=block.text, font=Some(font)))
      }
      runs
    }
    None => [RichTextRun::new(text=block.text, font=Some(font))]
  }
}

///|
fn markdown_heading_size_scale(level : Int) -> Double {
  if level <= 1 {
    1.95
  } else if level == 2 {
    1.5
  } else if level == 3 {
    1.25
  } else if level == 4 {
    1.0
  } else if level == 5 {
    0.94
  } else {
    0.9
  }
}

///|
/// Editor-style leading for a heading line box, expressed against the heading's
/// own font size. The painter clips every run to its line box, so a box shorter
/// than the font's own line height slices the glyph bottoms: with the old
/// base-relative factors the level-2 heading box was 1.1x its font and the
/// descender of "Today" was cut off. Every heading therefore gets this leading
/// over its scaled size, which also covers CJK fallback faces whose ascent plus
/// descent is taller than a Latin font's.
fn markdown_heading_line_height_scale(level : Int) -> Double {
  markdown_heading_size_scale(level) * 1.4
}

///|
fn markdown_inlines_to_rich_text(
  inlines : Array[MarkdownInline],
  base : @core.FontSpec,
  base_dir? : String? = None,
) -> Array[RichTextRun] {
  let runs : Array[RichTextRun] = []
  for span in inlines {
    runs.push(
      RichTextRun::new(
        text=markdown_inline_source_text(span),
        visual_text=Some(markdown_inline_visual_text(span)),
        image_source=markdown_inline_image_source(span, base_dir~),
        image_size=markdown_inline_image_size(span, base, base_dir~),
        font=Some(markdown_inline_font(span.kind, base)),
        color=markdown_inline_color(span.kind),
        background=markdown_inline_background(span.kind),
        decoration=markdown_inline_decoration(span.kind),
      ),
    )
  }
  runs
}

///|
/// Visual text keeps soft breaks as real newlines: paint, block heights,
/// caret geometry, and hit-test all split on them, so a single newline in
/// the source shows as its own line instead of silently joining into one
/// run-on line with a space.
fn markdown_inline_visual_text(inline : MarkdownInline) -> String {
  match inline.kind {
    Image => markdown_inline_source_text(inline)
    FootnoteReference => inline.text
    _ => inline.text
  }
}

///|
fn markdown_inline_image_source(
  inline : MarkdownInline,
  base_dir? : String? = None,
) -> String? {
  match inline.kind {
    Image =>
      match inline.target {
        Some(target) => Some(markdown_resolve_image_source(target, base_dir))
        None => None
      }
    _ => None
  }
}

///|
/// Resolve a markdown image target against the document's directory. Absolute
/// paths, `data:`/`http:`/`https:` URIs and absolute POSIX paths are returned
/// unchanged; relative paths are joined to `base_dir` (the directory of the
/// open `.md` file) so the renderer — which resolves `DrawImage` sources
/// against the process cwd — can find images sitting next to the document.
fn markdown_resolve_image_source(target : String, base_dir : String?) -> String {
  match base_dir {
    Some(dir) =>
      if dir == "" || markdown_target_is_absolute(target) {
        target
      } else {
        markdown_join_path(dir, target)
      }
    None => target
  }
}

///|
/// True for sources that should not be re-rooted: data/URL URIs and absolute
/// POSIX/Windows paths.
fn markdown_target_is_absolute(target : String) -> Bool {
  target.has_prefix("data:") ||
  target.has_prefix("http://") ||
  target.has_prefix("https://") ||
  target.has_prefix("file://") ||
  target.has_prefix("/") ||
  target.has_prefix("\\") ||
  (target.length() >= 2 && target[1] == ':')
}

///|
/// Join a directory and a relative path with a single `/` separator. Does not
/// canonicalize `..` segments; the renderer/host fs resolves them.
fn markdown_join_path(dir : String, rel : String) -> String {
  let dir_chars = dir.to_array()
  let has_slash = dir_chars.length() > 0 &&
    (
      dir_chars[dir_chars.length() - 1] == '/' ||
      dir_chars[dir_chars.length() - 1] == '\\'
    )
  if has_slash {
    dir + rel
  } else {
    dir + "/" + rel
  }
}

///|
/// Box size for a plain markdown image. The intrinsic header size (when the
/// host can provide it) keeps the image's real shape; otherwise a
/// placeholder box reserves the space until layout learns more. The drawn
/// width is capped to the content column by the resolver, mirroring the
/// usual `max-width: 100%` behavior.
fn markdown_inline_image_size(
  inline : MarkdownInline,
  base : @core.FontSpec,
  base_dir~ : String?,
) -> @core.Size? {
  match inline.kind {
    Image => {
      let fallback = @core.Size::new(
        width=base.size * 8.0,
        height=base.size * 4.5,
      )
      Some(
        match inline.target {
          Some(target) if target.trim().to_owned() != "" =>
            markdown_image_metrics_size(
              markdown_resolve_image_source(target, base_dir),
            ).unwrap_or(fallback)
          _ => fallback
        },
      )
    }
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
    Highlight => font
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
/// Inline run colors. Links/autolinks render in Typora's blue so they read as
/// actionable; everything else inherits the block foreground (None).
fn markdown_inline_color(kind : MarkdownInlineKind) -> @core.Color? {
  match kind {
    Link | Autolink => Some(@core.Color::rgba(r=0.13, g=0.45, b=0.94, a=1.0))
    _ => None
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
    Highlight =>
      Some(@core.Brush::solid(@core.Color::rgba(r=1.0, g=0.83, b=0.2, a=0.4)))
    Plain | Bold | Italic | Strikethrough | Link | Autolink => None
  }
}

///|
fn markdown_inline_decoration(kind : MarkdownInlineKind) -> RichTextDecoration? {
  match kind {
    Strikethrough => Some(RichTextDecoration::Strikethrough)
    Plain
    | Bold
    | Italic
    | Code
    | Highlight
    | Link
    | Autolink
    | Image
    | FootnoteReference
    | HtmlInline => None
  }
}
