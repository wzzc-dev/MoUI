///|
/// Colors baked into the markdown rich-text projection.
///
/// The projection is shared by the editor, the session snapshot export, and
/// the markdown preview surfaces. Colors are decided at conversion time and
/// stored on runs/blocks, so every role the converter paints has to be
/// represented here rather than resolved later from the editor foreground.
///
/// `light()` reproduces the historical colors exactly, which keeps existing
/// callers (and their golden tests) unchanged. Dark surfaces pass a palette
/// built from their theme; `dark()` is a readable default for callers that do
/// not have one.
#derive(Eq, Debug, ToJson)
pub(all) struct MarkdownRichTextPalette {
  /// Link and autolink text.
  link : @core.Color
  /// Inline code (`code`) background.
  inline_code_background : @core.Color
  /// Image placeholder background.
  image_background : @core.Color
  /// Footnote reference (`[^x]`) background.
  footnote_reference_background : @core.Color
  /// Raw inline HTML background.
  html_inline_background : @core.Color
  /// Highlight (`==text==`) background.
  highlight_background : @core.Color
  /// Blockquote text, background, and left border.
  quote_text : @core.Color
  quote_background : @core.Color
  quote_border : @core.Color
  /// Code block background and language label text.
  code_background : @core.Color
  code_language_text : @core.Color
  /// Table block background, border, and header background.
  table_background : @core.Color
  table_border : @core.Color
  table_header_background : @core.Color
  /// Footnote definition text, label, label background, and left border.
  footnote_text : @core.Color
  footnote_label_text : @core.Color
  footnote_label_background : @core.Color
  footnote_border : @core.Color
  /// Front matter background and text.
  front_matter_background : @core.Color
  front_matter_text : @core.Color
  /// Raw HTML block background and text.
  html_background : @core.Color
  html_text : @core.Color
  /// Code syntax token colors.
  syntax_keyword : @core.Color
  syntax_string : @core.Color
  syntax_comment : @core.Color
  syntax_number : @core.Color
  syntax_function : @core.Color
  syntax_type : @core.Color
  syntax_operator : @core.Color
  syntax_annotation : @core.Color
  syntax_escape : @core.Color
}

///|
pub extend MarkdownRichTextPalette with Debug::{to_repr}

///|
pub extend MarkdownRichTextPalette with Eq::{not_equal, equal}

///|
pub extend MarkdownRichTextPalette with ToJson::{to_json}

///|
/// The historical light palette. Values match the colors that were previously
/// hard-coded in `markdown_model_rich_text.mbt` and `code_highlight.mbt`.
pub fn MarkdownRichTextPalette::light() -> MarkdownRichTextPalette {
  {
    link: @core.Color::rgba(r=0.13, g=0.45, b=0.94, a=1.0),
    inline_code_background: @core.Color::black().multiply_alpha(0.08),
    image_background: @core.Color::rgba(r=0.18, g=0.4, b=0.7, a=0.08),
    footnote_reference_background: @core.Color::rgba(
      r=0.18,
      g=0.4,
      b=0.7,
      a=0.08,
    ),
    html_inline_background: @core.Color::black().multiply_alpha(0.06),
    highlight_background: @core.Color::rgba(r=1.0, g=0.83, b=0.2, a=0.4),
    quote_text: @core.Color::black().multiply_alpha(0.82),
    quote_background: @core.Color::rgba(r=0.12, g=0.13, b=0.15, a=0.05),
    quote_border: @core.Color::black().multiply_alpha(0.32),
    code_background: @core.Color::rgba(r=0.12, g=0.13, b=0.15, a=0.06),
    code_language_text: @core.Color::black().multiply_alpha(0.56),
    table_background: @core.Color::rgba(r=0.08, g=0.12, b=0.16, a=0.05),
    table_border: @core.Color::black().multiply_alpha(0.16),
    table_header_background: @core.Color::rgba(r=0.08, g=0.12, b=0.16, a=0.06),
    footnote_text: @core.Color::black().multiply_alpha(0.82),
    footnote_label_text: @core.Color::black().multiply_alpha(0.58),
    footnote_label_background: @core.Color::rgba(r=0.18, g=0.4, b=0.7, a=0.08),
    footnote_border: @core.Color::black().multiply_alpha(0.22),
    front_matter_background: @core.Color::rgba(r=0.20, g=0.28, b=0.36, a=0.07),
    front_matter_text: @core.Color::black().multiply_alpha(0.74),
    html_background: @core.Color::rgba(r=0.12, g=0.12, b=0.12, a=0.06),
    html_text: @core.Color::black().multiply_alpha(0.70),
    syntax_keyword: @core.Color::rgba(r=0.36, g=0.32, b=0.78, a=1.0),
    syntax_string: @core.Color::rgba(r=0.20, g=0.62, b=0.36, a=1.0),
    syntax_comment: @core.Color::rgba(r=0.45, g=0.48, b=0.52, a=1.0),
    syntax_number: @core.Color::rgba(r=0.78, g=0.52, b=0.18, a=1.0),
    syntax_function: @core.Color::rgba(r=0.27, g=0.42, b=0.70, a=1.0),
    syntax_type: @core.Color::rgba(r=0.22, g=0.77, b=0.62, a=1.0),
    syntax_operator: @core.Color::rgba(r=0.87, g=0.33, b=0.33, a=1.0),
    syntax_annotation: @core.Color::rgba(r=0.76, g=0.32, b=0.62, a=1.0),
    syntax_escape: @core.Color::rgba(r=0.67, g=0.29, b=0.91, a=1.0),
  }
}

///|
/// A readable dark-surface palette. The editor passes its own theme tokens;
/// this is the default for previews and callers without a theme.
pub fn MarkdownRichTextPalette::dark() -> MarkdownRichTextPalette {
  {
    link: @core.Color::rgba(r=0.48, g=0.70, b=1.0, a=1.0),
    inline_code_background: @core.Color::white().multiply_alpha(0.10),
    image_background: @core.Color::rgba(r=0.45, g=0.65, b=0.95, a=0.14),
    footnote_reference_background: @core.Color::rgba(
      r=0.45,
      g=0.65,
      b=0.95,
      a=0.14,
    ),
    html_inline_background: @core.Color::white().multiply_alpha(0.08),
    highlight_background: @core.Color::rgba(r=1.0, g=0.80, b=0.25, a=0.28),
    quote_text: @core.Color::rgba(r=0.86, g=0.88, b=0.91, a=1.0),
    quote_background: @core.Color::white().multiply_alpha(0.06),
    quote_border: @core.Color::white().multiply_alpha(0.30),
    code_background: @core.Color::white().multiply_alpha(0.06),
    code_language_text: @core.Color::white().multiply_alpha(0.60),
    table_background: @core.Color::white().multiply_alpha(0.05),
    table_border: @core.Color::white().multiply_alpha(0.16),
    table_header_background: @core.Color::white().multiply_alpha(0.07),
    footnote_text: @core.Color::rgba(r=0.86, g=0.88, b=0.91, a=1.0),
    footnote_label_text: @core.Color::white().multiply_alpha(0.65),
    footnote_label_background: @core.Color::rgba(r=0.45, g=0.65, b=0.95, a=0.16),
    footnote_border: @core.Color::white().multiply_alpha(0.24),
    front_matter_background: @core.Color::white().multiply_alpha(0.07),
    front_matter_text: @core.Color::white().multiply_alpha(0.75),
    html_background: @core.Color::white().multiply_alpha(0.07),
    html_text: @core.Color::white().multiply_alpha(0.75),
    syntax_keyword: @core.Color::rgba(r=0.78, g=0.57, b=0.93, a=1.0),
    syntax_string: @core.Color::rgba(r=0.63, g=0.84, b=0.65, a=1.0),
    syntax_comment: @core.Color::rgba(r=0.50, g=0.54, b=0.60, a=1.0),
    syntax_number: @core.Color::rgba(r=0.95, g=0.77, b=0.42, a=1.0),
    syntax_function: @core.Color::rgba(r=0.51, g=0.72, b=0.98, a=1.0),
    syntax_type: @core.Color::rgba(r=0.50, g=0.86, b=0.85, a=1.0),
    syntax_operator: @core.Color::rgba(r=0.95, g=0.62, b=0.56, a=1.0),
    syntax_annotation: @core.Color::rgba(r=0.90, g=0.81, b=0.48, a=1.0),
    syntax_escape: @core.Color::rgba(r=0.78, g=0.57, b=0.93, a=1.0),
  }
}

///|
fn markdown_rich_text_palette_mix_color(
  hash : UInt64,
  color : @core.Color,
) -> UInt64 {
  let mut hash = rich_text_digest_mix(
    hash,
    (color.r * 255.0).to_int().to_uint64(),
  )
  hash = rich_text_digest_mix(hash, (color.g * 255.0).to_int().to_uint64())
  hash = rich_text_digest_mix(hash, (color.b * 255.0).to_int().to_uint64())
  rich_text_digest_mix(hash, (color.a * 255.0).to_int().to_uint64())
}

///|
/// Stable digest of every role. Block conversions cache their baked colors,
/// so this participates in the conversion cache key; a theme switch therefore
/// cannot reuse a block projected with the old palette.
pub fn MarkdownRichTextPalette::cache_key(
  self : MarkdownRichTextPalette,
) -> String {
  let colors : Array[@core.Color] = [
    self.link,
    self.inline_code_background,
    self.image_background,
    self.footnote_reference_background,
    self.html_inline_background,
    self.highlight_background,
    self.quote_text,
    self.quote_background,
    self.quote_border,
    self.code_background,
    self.code_language_text,
    self.table_background,
    self.table_border,
    self.table_header_background,
    self.footnote_text,
    self.footnote_label_text,
    self.footnote_label_background,
    self.footnote_border,
    self.front_matter_background,
    self.front_matter_text,
    self.html_background,
    self.html_text,
    self.syntax_keyword,
    self.syntax_string,
    self.syntax_comment,
    self.syntax_number,
    self.syntax_function,
    self.syntax_type,
    self.syntax_operator,
    self.syntax_annotation,
    self.syntax_escape,
  ]
  let mut hash = 0xcbf29ce484222325UL
  for color in colors {
    hash = markdown_rich_text_palette_mix_color(hash, color)
  }
  "palette:" + hash.to_string()
}

///|
/// Resolve an optional palette at a conversion entry point. `None` keeps the
/// historical light output for every existing caller.
fn markdown_rich_text_palette_or_light(
  palette : MarkdownRichTextPalette?,
) -> MarkdownRichTextPalette {
  match palette {
    Some(palette) => palette
    None => MarkdownRichTextPalette::light()
  }
}
