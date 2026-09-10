///|
/// Vector text support for SVG documents rendered through the image pipeline.
///
/// The SVG renderer has no font system: `<text>` falls back to a built-in
/// bitmap font, which reads as blocky, misplaced lettering on real assets
/// (shields.io badges lean on `text-anchor` centering the renderer ignores).
/// Hosts that can supply glyph outlines replace that fallback wholesale:
/// before rasterization every `Shape::Text` node is handed to a resolver and,
/// on success, swapped for an equivalent `Shape::Path`. Text that the resolver
/// declines keeps the bitmap fallback, so partial font coverage degrades
/// gracefully.
///
/// The resolver lives in a registry rather than a decoder parameter because
/// renderer providers must stay mutually independent: one provider's font
/// stack (for example the pure-MoonBit outline extractor in `moui_sun/text`)
/// registers the implementation at application startup, and every backend's
/// decoder picks it up without importing another provider.

///|
/// Anchor semantics of an SVG `<text>` run, resolved from the
/// `text-anchor` attribute (with group inheritance) at scan time.
pub(all) enum SvgTextAnchor {
  Start
  Middle
  End
} derive(Eq, Debug)

///|
/// One SVG `<text>` run, in the node's own user space. `x`/`baseline_y` carry
/// the anchor point and baseline; `text` and `font_size` are the element's
/// literal content.
pub(all) struct SvgTextRun {
  text : String
  font_size : Double
  x : Double
  baseline_y : Double
  anchor : SvgTextAnchor
  /// `textLength` attribute in the run's user space; 0 when unspecified.
  text_length : Double
} derive(Debug)

///|
/// Glyph outlines for one `SvgTextRun`, in text-local space: the origin is
/// the run's left edge on the baseline (Start anchoring), `width` is the
/// laid-out advance, and polygons are closed contours ready for a nonzero
/// fill. Returning `None` keeps the bitmap fallback for that run.
pub(all) struct SvgTextRunOutline {
  width : Double
  polygons : Array[Array[(Double, Double)]]
} derive(Debug)

///|
/// Host-supplied conversion from an SVG text run to glyph outline polygons.
pub type SvgTextPathResolver = (SvgTextRun) -> SvgTextRunOutline?

///|
priv struct SvgTextPathRegistry {
  mut resolver : SvgTextPathResolver?
}

///|
let svg_text_path_registry : SvgTextPathRegistry = { resolver: None }

///|
/// Install (replace) the process-wide text resolver. Call once at application
/// startup, before SVG assets decode; later calls swap the implementation for
/// subsequent documents.
pub fn set_svg_text_path_resolver(resolver : SvgTextPathResolver) -> Unit {
  svg_text_path_registry.resolver = Some(resolver)
}

///|
/// Drop the installed resolver; SVG text falls back to the bitmap font.
pub fn clear_svg_text_path_resolver() -> Unit {
  svg_text_path_registry.resolver = None
}

///|
fn svg_current_text_path_resolver() -> SvgTextPathResolver? {
  svg_text_path_registry.resolver
}

///|
fn cursor_scanned_font_size(
  scanned : Array[SvgScannedText],
  cursor : SvgTextAnchorCursor,
) -> Double? {
  if cursor.value < scanned.length() {
    scanned[cursor.value].font_size
  } else {
    None
  }
}

///|
fn cursor_scanned_text_length(
  scanned : Array[SvgScannedText],
  cursor : SvgTextAnchorCursor,
) -> Double? {
  if cursor.value < scanned.length() {
    scanned[cursor.value].text_length
  } else {
    None
  }
}

///|
/// Presentation facts for one `<text>` element recovered from the raw markup.
/// `font_size` is `None` when no own-or-inherited numeric `font-size` exists;
/// the node's parsed value then wins.
priv struct SvgScannedText {
  anchor : SvgTextAnchor
  font_size : Double?
  text_length : Double?
}

///|
/// Document-order cursor shared across the recursive tree walk so each
/// `<text>` element consumes its scanned facts in turn.
priv struct SvgTextAnchorCursor {
  mut value : Int
}

///|
/// Effective `text-anchor` for every `<text>` element, in document order.
///
/// The renderer's scene graph does not carry presentation attributes, so the
/// anchor is recovered with a bounded scan of the raw markup: container tags
/// (`svg`/`g`) push their inherited anchor, `<text>` start tags record the
/// effective value, closers pop. Quoted `>` inside attribute values is not
/// handled; real-world badge and icon markup does not use it.
fn svg_scan_text_anchors(svg_text : String) -> Array[SvgScannedText] {
  let scanned : Array[SvgScannedText] = []
  let stack : Array[(SvgTextAnchor, Double?)] = [(Start, None)]
  let chars = svg_text.to_array()
  let limit = chars.length()
  let mut index = 0
  fn anchor_of(value : String, fallback : SvgTextAnchor) -> SvgTextAnchor {
    match value {
      "middle" => Middle
      "end" => End
      "start" => Start
      _ => fallback
    }
  }

  fn chars_equal_at(
    tag : Array[Char],
    offset : Int,
    name : Array[Char],
  ) -> Bool {
    let name_len = name.length()
    if offset + name_len > tag.length() {
      return false
    }
    for k = 0; k < name_len; k = k + 1 {
      if tag[offset + k] != name[k] {
        return false
      }
    }
    true
  }

  fn tag_attr(tag : Array[Char], name : Array[Char]) -> String? {
    // Locate `name=` inside the tag body and return the quoted value.
    let name_len = name.length()
    let mut i = 0
    while i < tag.length() {
      if chars_equal_at(tag, i, name) &&
        i + name_len < tag.length() &&
        tag[i + name_len] == '=' {
        let value_start = i + name_len + 1
        if value_start < tag.length() {
          let quote = tag[value_start]
          if quote == '"' || quote == '\'' {
            let mut end = value_start + 1
            while end < tag.length() && tag[end] != quote {
              end = end + 1
            }
            if end > value_start + 1 && end <= tag.length() {
              return Some(
                String::from_array(tag[value_start + 1:end].to_owned()),
              )
            }
          }
        }
        return None
      }
      i = i + 1
    }
    None
  }

  while index < limit {
    if chars[index] != '<' {
      index = index + 1
      continue
    }
    // Read the tag body up to the closing '>'.
    let mut end = index + 1
    while end < limit && chars[end] != '>' {
      end = end + 1
    }
    if end >= limit {
      break
    }
    let body = chars[index + 1:end].to_owned()
    index = end + 1
    if body.length() == 0 {
      continue
    }
    if body[0] == '!' || body[0] == '?' {
      continue
    }
    if body[0] == '/' {
      // Closing tag: pop containers pushed by their start tags.
      let name = String::from_array(
        svg_tag_name(body[1:body.length()].to_owned()),
      )
      if name == "g" || name == "svg" {
        if stack.length() > 1 {
          let _ = stack.pop()
        }
      }
      continue
    }
    let self_closing = body[body.length() - 1] == '/'
    let name = String::from_array(svg_tag_name(body))
    let frame = stack[stack.length() - 1]
    let anchor = match tag_attr(body, "text-anchor".to_array()) {
      Some(value) => anchor_of(value, frame.0)
      None => frame.0
    }
    let font_size = match tag_attr(body, "font-size".to_array()) {
      Some(value) => svg_parse_px_length(value)
      None => frame.1
    }
    // textLength only ever applies on the <text> element itself.
    let text_length = if name == "text" {
      match tag_attr(body, "textLength".to_array()) {
        Some(value) => svg_parse_px_length(value)
        None => None
      }
    } else {
      None
    }
    if name == "text" {
      scanned.push({ anchor, font_size, text_length })
    } else if (name == "g" || name == "svg") && !self_closing {
      stack.push((anchor, font_size))
    }
  }
  scanned
}

///|
/// Numeric `font-size` literal (`110`, `12.5`, `14px`); percentages and other
/// units return `None` because they need a resolved context.
fn svg_parse_px_length(value : String) -> Double? {
  let trimmed = value.trim().to_owned()
  if trimmed == "" || trimmed.contains("%") {
    return None
  }
  let chars = trimmed.to_array()
  let mut index = 0
  let mut whole = 0.0
  let mut digits = 0
  while index < chars.length() && chars[index] >= '0' && chars[index] <= '9' {
    whole = whole * 10.0 + (chars[index].to_int() - 48).to_double()
    digits = digits + 1
    index = index + 1
  }
  if digits == 0 {
    return None
  }
  let mut fraction = 0.0
  if index < chars.length() && chars[index] == '.' {
    index = index + 1
    let mut scale = 1.0
    while index < chars.length() && chars[index] >= '0' && chars[index] <= '9' {
      scale = scale * 10.0
      fraction = fraction + (chars[index].to_int() - 48).to_double() / scale
      index = index + 1
    }
  }
  Some(whole + fraction)
}

///|
/// Element name of a tag body: the leading run of name characters.
fn svg_tag_name(body : Array[Char]) -> Array[Char] {
  let out : Array[Char] = []
  for ch in body {
    if (ch >= 'a' && ch <= 'z') ||
      (ch >= 'A' && ch <= 'Z') ||
      (ch >= '0' && ch <= '9') ||
      ch == '_' ||
      ch == '-' {
      out.push(ch)
    } else {
      break
    }
  }
  out
}

///|
/// Replace every `Shape::Text` node with an equivalent `Shape::Path` when the
/// installed resolver supplies outlines. Text nodes are matched to scanned
/// anchors in document order; runs the resolver declines keep their original
/// shape. Returns the number of replaced runs.
fn svg_apply_text_paths(
  node : @svg.SVGNode,
  resolver : SvgTextPathResolver,
  anchors : Array[SvgScannedText],
  cursor : SvgTextAnchorCursor,
) -> Int {
  let replaced = match node.shape {
    @svg.Shape::Text(x~, y~, text~, font_size~) => {
      let anchor = if cursor.value < anchors.length() {
        anchors[cursor.value].anchor
      } else {
        Start
      }
      // The renderer's scene graph does not inherit `font-size` from
      // container groups; the scanned value restores the intended size.
      let run_font_size = match cursor_scanned_font_size(anchors, cursor) {
        Some(size) => size
        None => font_size
      }
      let run_text_length = match cursor_scanned_text_length(anchors, cursor) {
        Some(length) => length
        None => 0.0
      }
      cursor.value = cursor.value + 1
      match
        resolver({
          text,
          font_size: run_font_size,
          x,
          baseline_y: y,
          anchor,
          text_length: run_text_length,
        }) {
        Some(outline) =>
          if outline.polygons.is_empty() {
            0
          } else {
            let start_x = match anchor {
              Start => x
              Middle => x - outline.width / 2.0
              End => x - outline.width
            }
            node.shape = @svg.Shape::Path(
              commands=svg_text_polygons_to_commands(
                outline.polygons,
                start_x,
                y,
              ),
            )
            1
          }
        None => 0
      }
    }
    @svg.Shape::Group => {
      let mut total = 0
      for child in node.children {
        total = total + svg_apply_text_paths(child, resolver, anchors, cursor)
      }
      total
    }
    _ => 0
  }
  replaced
}

///|
/// Build the renderer's path commands for text polygons placed into user
/// space. Polygon coordinates are text-local — x from the run's left edge,
/// y from the baseline — so the anchor-resolved `start_x` and the run's
/// `baseline_y` are added to every point.
fn svg_text_polygons_to_commands(
  polygons : Array[Array[(Double, Double)]],
  start_x : Double,
  baseline_y : Double,
) -> Array[@svg.PathCommand] {
  let commands : Array[@svg.PathCommand] = []
  for polygon in polygons {
    if polygon.length() < 2 {
      continue
    }
    commands.push(
      @svg.PathCommand::MoveTo(
        polygon[0].0 + start_x,
        polygon[0].1 + baseline_y,
      ),
    )
    for i = 1; i < polygon.length(); i = i + 1 {
      commands.push(
        @svg.PathCommand::LineTo(
          polygon[i].0 + start_x,
          polygon[i].1 + baseline_y,
        ),
      )
    }
    commands.push(@svg.PathCommand::ClosePath)
  }
  commands
}

///|
/// Install text outlines into a freshly parsed document when a resolver is
/// registered. Called after parse and viewBox synthesis, before rasterize.
fn svg_install_text_paths(
  document : @svg.SVGDocument,
  svg_text : String,
) -> Unit {
  match svg_current_text_path_resolver() {
    Some(resolver) => {
      let anchors = svg_scan_text_anchors(svg_text)
      let cursor : SvgTextAnchorCursor = { value: 0 }
      let _ = svg_apply_text_paths(document.root(), resolver, anchors, cursor)
    }
    None => ()
  }
}
