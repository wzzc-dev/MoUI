///|
/// Presentation-only projection of raw HTML container blocks, registered as
/// a `MarkdownBlockView` contribution.
///
/// Raw HTML stays raw by default. This view only recognizes `div`/`center`
/// containers whose children are all in a narrow displayable subset:
/// images (optionally wrapped in a single anchor), line breaks, comments,
/// `&nbsp;`-style spacing, paragraphs, headings, spans, plain text, and
/// nested containers (flattened into rows). Everything else — tables,
/// lists, unknown tags, malformed structure — declines so the block keeps
/// its raw source presentation. The canonical block source remains the
/// editable truth; this module never rewrites it.
priv struct MarkdownHtmlImageGalleryAttribute {
  name : String
  value : String?
}

///|
priv struct MarkdownHtmlImageGalleryTag {
  name : String
  attributes : Array[MarkdownHtmlImageGalleryAttribute]
  raw : String
  closing : Bool
  self_closing : Bool
}

///|
priv struct MarkdownHtmlImageGalleryTagParseResult {
  tag : MarkdownHtmlImageGalleryTag
  end : Int
}

///|
priv enum MarkdownHtmlImageGalleryDimension {
  Pixels(Double)
  Fraction(Double)
}

///|
/// Mutable walker state shared while projecting one container block.
priv struct MarkdownHtmlImageGalleryWalk {
  chars : Array[Char]
  index : Ref[Int]
  base : @core.FontSpec
  base_dir : String?
  runs : Array[RichTextRun]
  line_open : Ref[Bool]
  invalid : Ref[Bool]
}

///|
pub let markdown_html_image_gallery_view : MarkdownBlockView = {
  name: "html-image-gallery",
  matches: markdown_html_image_gallery_signature,
  project: (block, context) => {
    markdown_html_image_gallery_project(
      block.text,
      context.base,
      context.base_dir,
    )
  },
}

///|
/// Cheap candidacy signature: first tag of an HTML block must be an opened
/// `div`/`center`. No body parsing happens here so the height walk can
/// probe every block through the registry.
fn markdown_html_image_gallery_signature(block : MarkdownBlock) -> Bool {
  match block.kind {
    MarkdownBlockKind::HtmlBlock => {
      let chars = block.text.to_array()
      match
        markdown_html_image_gallery_tag_at(
          chars,
          markdown_html_image_gallery_skip_space(chars, 0),
        ) {
        Some(parsed) =>
          !parsed.tag.closing &&
          (parsed.tag.name == "div" || parsed.tag.name == "center")
        None => false
      }
    }
    _ => false
  }
}

///|
fn markdown_html_image_gallery_project(
  html : String,
  base : @core.FontSpec,
  base_dir : String?,
) -> MarkdownBlockViewProjection? {
  let chars = html.to_array()
  let start = markdown_html_image_gallery_skip_space(chars, 0)
  match markdown_html_image_gallery_tag_at(chars, start) {
    Some(opening) => {
      let outer = opening.tag
      if outer.closing ||
        outer.self_closing ||
        (outer.name != "div" && outer.name != "center") {
        return None
      }
      let line_align = match
        markdown_html_image_gallery_container_align(outer) {
        Some(align) => align
        None => return None
      }
      let walk : MarkdownHtmlImageGalleryWalk = {
        chars,
        index: Ref(opening.end),
        base,
        base_dir,
        runs: [],
        line_open: Ref(false),
        invalid: Ref(false),
      }
      markdown_html_image_gallery_walk_body(walk, outer.name)
      if !walk.invalid.val {
        markdown_html_image_gallery_walk_tail(walk)
        markdown_html_image_gallery_strip_trailing_newline(walk)
      }
      if walk.invalid.val || walk.runs.length() == 0 {
        None
      } else {
        Some({ runs: walk.runs, line_align: Some(line_align) })
      }
    }
    None => None
  }
}

///|
/// Walk a container body until its matching closing tag is consumed,
/// marking the walk invalid on any construct outside the displayable
/// subset.
fn markdown_html_image_gallery_walk_body(
  walk : MarkdownHtmlImageGalleryWalk,
  closing : String,
) -> Unit {
  let chars = walk.chars
  while !walk.invalid.val && walk.index.val < chars.length() {
    walk.index.val = markdown_html_image_gallery_skip_space(
      chars,
      walk.index.val,
    )
    if walk.index.val >= chars.length() {
      break
    }
    match markdown_html_image_gallery_comment_end(chars, walk.index.val) {
      Some(end) => {
        walk.index.val = end
        continue
      }
      None => ()
    }
    if chars[walk.index.val] != '<' {
      markdown_html_image_gallery_read_text(walk)
      continue
    }
    let element_start = walk.index.val
    match markdown_html_image_gallery_tag_at(chars, walk.index.val) {
      None => walk.invalid.val = true
      Some(parsed) => {
        let tag = parsed.tag
        walk.index.val = parsed.end
        if tag.closing {
          if tag.name == closing {
            return
          }
          walk.invalid.val = true
        } else {
          match tag.name {
            "img" => markdown_html_image_gallery_walk_image(walk, tag)
            "br" => {
              walk.runs.push(
                RichTextRun::new(
                  text=tag.raw,
                  visual_text=Some("\n"),
                  font=Some(walk.base),
                ),
              )
              walk.line_open.val = false
            }
            "div" | "center" =>
              if tag.self_closing {
                walk.invalid.val = true
              } else {
                markdown_html_image_gallery_break_before(walk)
                markdown_html_image_gallery_walk_body(walk, tag.name)
                markdown_html_image_gallery_break_before(walk)
              }
            "a" => markdown_html_image_gallery_walk_anchor(walk)
            "p" =>
              markdown_html_image_gallery_block_text(
                walk,
                element_start,
                tag.name,
                walk.base,
                true,
              )
            "h1" | "h2" | "h3" | "h4" | "h5" | "h6" =>
              markdown_html_image_gallery_block_text(
                walk,
                element_start,
                tag.name,
                { ..walk.base, size: walk.base.size * 1.15, weight: 700 },
                false,
              )
            "span" => markdown_html_image_gallery_span_text(walk, element_start)
            _ => walk.invalid.val = true
          }
        }
      }
    }
  }
  if !walk.invalid.val {
    // Reached the end of the block without the container's own closing
    // tag: the structure is malformed, so the block stays raw.
    walk.invalid.val = true
  }
}

///|
/// Walk what follows the first closed container: trailing text and sibling
/// containers remain displayable; anything else keeps the block raw.
fn markdown_html_image_gallery_walk_tail(
  walk : MarkdownHtmlImageGalleryWalk,
) -> Unit {
  let chars = walk.chars
  while !walk.invalid.val && walk.index.val < chars.length() {
    walk.index.val = markdown_html_image_gallery_skip_space(
      chars,
      walk.index.val,
    )
    if walk.index.val >= chars.length() {
      break
    }
    match markdown_html_image_gallery_comment_end(chars, walk.index.val) {
      Some(end) => {
        walk.index.val = end
        continue
      }
      None => ()
    }
    if chars[walk.index.val] != '<' {
      markdown_html_image_gallery_read_text(walk)
      continue
    }
    match markdown_html_image_gallery_tag_at(chars, walk.index.val) {
      None => walk.invalid.val = true
      Some(parsed) => {
        let tag = parsed.tag
        walk.index.val = parsed.end
        if !tag.closing &&
          !tag.self_closing &&
          (tag.name == "div" || tag.name == "center") {
          markdown_html_image_gallery_break_before(walk)
          markdown_html_image_gallery_walk_body(walk, tag.name)
          markdown_html_image_gallery_break_before(walk)
        } else {
          walk.invalid.val = true
        }
      }
    }
  }
}

///|
fn markdown_html_image_gallery_walk_image(
  walk : MarkdownHtmlImageGalleryWalk,
  tag : MarkdownHtmlImageGalleryTag,
) -> Unit {
  match markdown_html_image_gallery_image_run(tag, walk.base, walk.base_dir) {
    Some(run) => {
      walk.runs.push(run)
      walk.line_open.val = true
    }
    None => walk.invalid.val = true
  }
}

///|
/// An anchor is displayable only when it wraps a single image (badge rows).
fn markdown_html_image_gallery_walk_anchor(
  walk : MarkdownHtmlImageGalleryWalk,
) -> Unit {
  let chars = walk.chars
  while !walk.invalid.val {
    walk.index.val = markdown_html_image_gallery_skip_space(
      chars,
      walk.index.val,
    )
    if walk.index.val >= chars.length() {
      walk.invalid.val = true
      return
    }
    match markdown_html_image_gallery_comment_end(chars, walk.index.val) {
      Some(end) => {
        walk.index.val = end
        continue
      }
      None => ()
    }
    match markdown_html_image_gallery_tag_at(chars, walk.index.val) {
      None => {
        walk.invalid.val = true
        return
      }
      Some(parsed) => {
        let tag = parsed.tag
        walk.index.val = parsed.end
        if tag.closing {
          if tag.name == "a" {
            return
          }
          walk.invalid.val = true
          return
        }
        if tag.name != "img" {
          walk.invalid.val = true
          return
        }
        markdown_html_image_gallery_walk_image(walk, tag)
      }
    }
  }
}

///|
fn markdown_html_image_gallery_read_text(
  walk : MarkdownHtmlImageGalleryWalk,
) -> Unit {
  let chars = walk.chars
  let start = walk.index.val
  while walk.index.val < chars.length() && chars[walk.index.val] != '<' {
    walk.index.val = walk.index.val + 1
  }
  if walk.index.val == start {
    return
  }
  if markdown_html_image_gallery_space_entity_only(chars, start, walk.index.val) {
    if walk.line_open.val {
      markdown_html_image_gallery_push_inline(
        walk,
        String::from_array(chars[start:walk.index.val]),
        " ",
        walk.base,
        None,
      )
    }
    return
  }
  match markdown_html_image_gallery_decode_text(chars, start, walk.index.val) {
    Some(visual) => {
      markdown_html_image_gallery_break_before(walk)
      markdown_html_image_gallery_push_inline(
        walk,
        String::from_array(chars[start:walk.index.val]),
        visual,
        walk.base,
        Some(@core.Color::black().multiply_alpha(0.78)),
      )
      markdown_html_image_gallery_push_newline(walk)
    }
    None => ()
  }
}

///|
fn markdown_html_image_gallery_block_text(
  walk : MarkdownHtmlImageGalleryWalk,
  element_start : Int,
  name : String,
  font : @core.FontSpec,
  dim : Bool,
) -> Unit {
  let color = if dim {
    Some(@core.Color::black().multiply_alpha(0.78))
  } else {
    None
  }
  // Fast path: a pure-text paragraph/heading projects as one run covering
  // the whole element, which keeps the source mapping exact. Rich content
  // (nested anchors/images) falls through to the inline walker below.
  match markdown_html_image_gallery_inline_content(walk, name) {
    (true, None) => ()
    (true, Some(visual)) => {
      markdown_html_image_gallery_break_before(walk)
      markdown_html_image_gallery_push_inline(
        walk,
        String::from_array(walk.chars[element_start:walk.index.val]),
        visual,
        font,
        color,
      )
      markdown_html_image_gallery_push_newline(walk)
    }
    (false, _) => {
      markdown_html_image_gallery_break_before(walk)
      let before = walk.runs.length()
      if !markdown_html_image_gallery_walk_inline_until(walk, name, font, color) {
        walk.invalid.val = true
        return
      }
      if walk.runs.length() > before {
        markdown_html_image_gallery_push_newline(walk)
      }
    }
  }
}

///|
fn markdown_html_image_gallery_span_text(
  walk : MarkdownHtmlImageGalleryWalk,
  element_start : Int,
) -> Unit {
  let color = Some(@core.Color::black().multiply_alpha(0.78))
  match markdown_html_image_gallery_inline_content(walk, "span") {
    (true, None) => ()
    (true, Some(visual)) =>
      markdown_html_image_gallery_push_inline(
        walk,
        String::from_array(walk.chars[element_start:walk.index.val]),
        visual,
        walk.base,
        color,
      )
    (false, _) =>
      if !markdown_html_image_gallery_walk_inline_until(
          walk,
          "span",
          walk.base,
          color,
        ) {
        walk.invalid.val = true
      }
  }
}

///|
/// Walk the inline children of an opened `closing` element, pushing text,
/// images, anchors and line breaks as runs. Returns `false` — declining the
/// whole container — on any construct outside the displayable subset.
fn markdown_html_image_gallery_walk_inline_until(
  walk : MarkdownHtmlImageGalleryWalk,
  closing : String,
  font : @core.FontSpec,
  color : @core.Color?,
) -> Bool {
  let chars = walk.chars
  while walk.index.val < chars.length() {
    match markdown_html_image_gallery_comment_end(chars, walk.index.val) {
      Some(end) => {
        walk.index.val = end
        continue
      }
      None => ()
    }
    if chars[walk.index.val] != '<' {
      let start = walk.index.val
      while walk.index.val < chars.length() && chars[walk.index.val] != '<' {
        walk.index.val = walk.index.val + 1
      }
      match
        markdown_html_image_gallery_decode_text_inline(
          chars,
          start,
          walk.index.val,
        ) {
        None => ()
        Some(visual) =>
          // A whitespace-only segment only becomes a run mid-line, so a
          // paragraph's own indentation never leaks a leading space.
          if visual != " " || walk.line_open.val {
            markdown_html_image_gallery_push_inline(
              walk,
              String::from_array(chars[start:walk.index.val]),
              visual,
              font,
              color,
            )
          }
      }
      continue
    }
    let tag_start = walk.index.val
    match markdown_html_image_gallery_tag_at(chars, tag_start) {
      None => return false
      Some(parsed) => {
        let tag = parsed.tag
        walk.index.val = parsed.end
        if tag.closing {
          return tag.name == closing
        }
        match tag.name {
          "img" =>
            match
              markdown_html_image_gallery_image_run(
                tag,
                walk.base,
                walk.base_dir,
              ) {
              Some(run) => {
                walk.runs.push(run)
                walk.line_open.val = true
              }
              None => return false
            }
          "br" => {
            walk.runs.push(
              RichTextRun::new(
                text=tag.raw,
                visual_text=Some("\n"),
                font=Some(walk.base),
              ),
            )
            walk.line_open.val = false
          }
          "a" =>
            if !markdown_html_image_gallery_walk_inline_anchor(
                walk, tag_start, font, color,
              ) {
              return false
            }
          "span" | "strong" | "b" | "em" | "i" | "code" =>
            if !markdown_html_image_gallery_walk_inline_until(
                walk,
                tag.name,
                font,
                color,
              ) {
              return false
            }
          _ => return false
        }
      }
    }
  }
  false
}

///|
/// Inline anchor: displayable only when it wraps either a single image or
/// plain text (badge rows and inline links). Mixed content declines so the
/// container keeps its raw source presentation.
fn markdown_html_image_gallery_walk_inline_anchor(
  walk : MarkdownHtmlImageGalleryWalk,
  element_start : Int,
  font : @core.FontSpec,
  color : @core.Color?,
) -> Bool {
  let chars = walk.chars
  let inner_start = walk.index.val
  let mut has_text = false
  let mut has_image = false
  let mut image_run : RichTextRun? = None
  while walk.index.val < chars.length() {
    match markdown_html_image_gallery_comment_end(chars, walk.index.val) {
      Some(end) => {
        walk.index.val = end
        continue
      }
      None => ()
    }
    if chars[walk.index.val] != '<' {
      let start = walk.index.val
      while walk.index.val < chars.length() && chars[walk.index.val] != '<' {
        walk.index.val = walk.index.val + 1
      }
      if markdown_html_image_gallery_decode_text_inline(
          chars,
          start,
          walk.index.val,
        )
        is Some(_) {
        has_text = true
      }
      continue
    }
    let tag_start = walk.index.val
    match markdown_html_image_gallery_tag_at(chars, tag_start) {
      None => return false
      Some(parsed) => {
        let tag = parsed.tag
        walk.index.val = parsed.end
        if tag.closing {
          if tag.name != "a" {
            return false
          }
          if has_image && !has_text {
            match image_run {
              Some(run) => {
                walk.runs.push(run)
                walk.line_open.val = true
                return true
              }
              None => return false
            }
          }
          if has_text && !has_image {
            match
              markdown_html_image_gallery_decode_text_inline(
                chars, inner_start, tag_start,
              ) {
              None => ()
              Some(visual) =>
                if visual != " " || walk.line_open.val {
                  markdown_html_image_gallery_push_inline(
                    walk,
                    String::from_array(chars[element_start:walk.index.val]),
                    visual,
                    font,
                    color,
                  )
                }
            }
            return true
          }
          return false
        }
        if tag.name == "img" && !has_text && !has_image {
          match
            markdown_html_image_gallery_image_run(tag, walk.base, walk.base_dir) {
            Some(run) => {
              image_run = Some(run)
              has_image = true
            }
            None => return false
          }
        } else {
          return false
        }
      }
    }
  }
  false
}

///|
/// Inline text decoding: collapses whitespace runs to single spaces, keeps a
/// single trailing space so adjacent inline elements stay separated, and
/// returns `Some(" ")` for a whitespace-only segment (the caller drops it at
/// line start).
fn markdown_html_image_gallery_decode_text_inline(
  chars : Array[Char],
  start : Int,
  end : Int,
) -> String? {
  let output = StringBuilder()
  let mut index = start
  let mut pending_space = false
  let mut started = false
  while index < end {
    let ch = chars[index]
    if markdown_html_image_gallery_space(ch) {
      if started {
        pending_space = true
      }
      index = index + 1
    } else {
      let (text, next) = match
        markdown_html_image_gallery_entity_at(chars, index, end) {
        Some((text, next)) => (text, next)
        None => (String::from_array([ch]), index + 1)
      }
      if text == " " {
        if started {
          pending_space = true
        }
      } else {
        if pending_space {
          output.write_string(" ")
          pending_space = false
        }
        output.write_string(text)
        started = true
      }
      index = next
    }
  }
  if !started {
    return if start < end { Some(" ") } else { None }
  }
  if pending_space {
    output.write_string(" ")
  }
  Some(output.to_string())
}

///|
/// Collect the plain-text content of an opened `name` element up to its
/// closing tag. Any nested markup inside declines the element.
fn markdown_html_image_gallery_inline_content(
  walk : MarkdownHtmlImageGalleryWalk,
  name : String,
) -> (Bool, String?) {
  let chars = walk.chars
  let start = walk.index.val
  let mut index = start
  while index < chars.length() {
    if chars[index] == '<' {
      if markdown_html_image_gallery_ci_at(chars, index, "</" + name) {
        let mut cursor = index + 2 + name.length()
        while cursor < chars.length() && chars[cursor] != '>' {
          cursor = cursor + 1
        }
        if cursor >= chars.length() {
          return (false, None)
        }
        walk.index.val = cursor + 1
        return (
          true,
          markdown_html_image_gallery_decode_text(chars, start, index),
        )
      }
      return (false, None)
    }
    index = index + 1
  }
  (false, None)
}

///|
fn markdown_html_image_gallery_push_newline(
  walk : MarkdownHtmlImageGalleryWalk,
) -> Unit {
  walk.runs.push(
    RichTextRun::new(text="", visual_text=Some("\n"), font=Some(walk.base)),
  )
  walk.line_open.val = false
}

///|
/// Drop the newline-only runs the flat projection appends after the last
/// block-level child. Those separators exist to keep interior rows apart, but
/// after the container's final child nothing follows to separate from, so the
/// walk's trailing `push_newline` would lay out as a full empty line that HTML
/// never renders there.
fn markdown_html_image_gallery_strip_trailing_newline(
  walk : MarkdownHtmlImageGalleryWalk,
) -> Unit {
  while walk.runs.length() > 0 {
    let last = walk.runs[walk.runs.length() - 1]
    if last.text == "" && last.visual_text == Some("\n") {
      let _ = walk.runs.pop()
    } else {
      break
    }
  }
}

///|
fn markdown_html_image_gallery_break_before(
  walk : MarkdownHtmlImageGalleryWalk,
) -> Unit {
  if walk.line_open.val {
    markdown_html_image_gallery_push_newline(walk)
  }
}

///|
fn markdown_html_image_gallery_push_inline(
  walk : MarkdownHtmlImageGalleryWalk,
  raw : String,
  visual : String,
  font : @core.FontSpec,
  color : @core.Color?,
) -> Unit {
  let run = match color {
    None =>
      RichTextRun::new(text=raw, visual_text=Some(visual), font=Some(font))
    Some(color) =>
      RichTextRun::new(
        text=raw,
        visual_text=Some(visual),
        font=Some(font),
        color=Some(color),
      )
  }
  walk.runs.push(run)
  walk.line_open.val = true
}

///|
/// Decode HTML entities and collapse whitespace runs into single spaces.
/// Returns `None` when the segment carries no visible content.
fn markdown_html_image_gallery_decode_text(
  chars : Array[Char],
  start : Int,
  end : Int,
) -> String? {
  let output = StringBuilder()
  let mut index = start
  let mut pending_space = false
  let mut visible = false
  while index < end {
    let ch = chars[index]
    if markdown_html_image_gallery_space(ch) {
      pending_space = true
      index = index + 1
    } else {
      let (text, next) = match
        markdown_html_image_gallery_entity_at(chars, index, end) {
        Some((text, next)) => (text, next)
        None => (String::from_array([ch]), index + 1)
      }
      if text == " " {
        pending_space = true
      } else {
        if pending_space && visible {
          output.write_string(" ")
        }
        pending_space = false
        output.write_string(text)
        visible = true
      }
      index = next
    }
  }
  if visible {
    Some(output.to_string())
  } else {
    None
  }
}

///|
fn markdown_html_image_gallery_space_entity_only(
  chars : Array[Char],
  start : Int,
  end : Int,
) -> Bool {
  let mut index = start
  while index < end {
    let ch = chars[index]
    if markdown_html_image_gallery_space(ch) {
      index = index + 1
    } else if ch == '&' {
      match markdown_html_image_gallery_entity_at(chars, index, end) {
        Some((" ", next)) => index = next
        _ => return false
      }
    } else {
      return false
    }
  }
  true
}

///|
fn markdown_html_image_gallery_entity_at(
  chars : Array[Char],
  index : Int,
  end : Int,
) -> (String, Int)? {
  // chars[index] == '&'
  let name_start = index + 1
  let mut cursor = name_start
  while cursor < end && markdown_html_image_gallery_entity_char(chars[cursor]) {
    cursor = cursor + 1
  }
  if cursor >= end || chars[cursor] != ';' || cursor == name_start {
    return None
  }
  let name = String::from_array(chars[name_start:cursor]).to_lower()
  match name {
    "nbsp" => Some((" ", cursor + 1))
    "amp" => Some(("&", cursor + 1))
    "lt" => Some(("<", cursor + 1))
    "gt" => Some((">", cursor + 1))
    "quot" => Some(("\"", cursor + 1))
    "#39" => Some(("'", cursor + 1))
    _ => None
  }
}

///|
fn markdown_html_image_gallery_entity_char(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') ||
  (ch >= 'A' && ch <= 'Z') ||
  (ch >= '0' && ch <= '9') ||
  ch == '#'
}

///|
/// Skip an HTML comment at `index`, returning its end when a comment
/// starts there. An unterminated comment consumes the remaining text.
fn markdown_html_image_gallery_comment_end(
  chars : Array[Char],
  index : Int,
) -> Int? {
  if index + 4 > chars.length() ||
    chars[index] != '<' ||
    chars[index + 1] != '!' ||
    chars[index + 2] != '-' ||
    chars[index + 3] != '-' {
    return None
  }
  let mut cursor = index + 4
  while cursor + 3 <= chars.length() {
    if chars[cursor] == '-' &&
      chars[cursor + 1] == '-' &&
      chars[cursor + 2] == '>' {
      return Some(cursor + 3)
    }
    cursor = cursor + 1
  }
  Some(chars.length())
}

///|
fn markdown_html_image_gallery_ci_at(
  chars : Array[Char],
  index : Int,
  needle : String,
) -> Bool {
  let needle_chars = needle.to_array()
  if index + needle_chars.length() > chars.length() {
    return false
  }
  for offset in 0..<needle_chars.length() {
    if !markdown_html_image_gallery_ci_char(
        chars[index + offset],
        needle_chars[offset],
      ) {
      return false
    }
  }
  true
}

///|
fn markdown_html_image_gallery_ci_char(
  actual : Char,
  want_lower : Char,
) -> Bool {
  actual == want_lower ||
  (
    actual >= 'A' &&
    actual <= 'Z' &&
    actual.to_int() + 32 == want_lower.to_int()
  )
}

///|
fn markdown_html_image_gallery_container_align(
  tag : MarkdownHtmlImageGalleryTag,
) -> @core.TextAlign? {
  if tag.name == "center" {
    return Some(TextCenter)
  }
  match markdown_html_image_gallery_attribute(tag.attributes, "align") {
    None => Some(@core.TextAlign::TextStart)
    Some(value) =>
      match value.trim().to_owned().to_lower() {
        "center" => Some(TextCenter)
        "right" => Some(TextEnd)
        "left" => Some(TextStart)
        _ => None
      }
  }
}

///|
/// Vertical breathing room added around every gallery row. The layout stacks
/// image rows at exactly their pixel height, so without this padding rows
/// (mascot, badge row, single badge) sit flush against each other; the extra
/// height letterboxes the image inside its (Contain-fitted) line frame.
let markdown_html_image_gallery_row_gap : Double = 12.0

///|
fn markdown_html_image_gallery_image_run(
  tag : MarkdownHtmlImageGalleryTag,
  base : @core.FontSpec,
  base_dir : String?,
) -> RichTextRun? {
  match markdown_html_image_gallery_attribute(tag.attributes, "src") {
    Some(source) if source.trim().to_owned() != "" => {
      let alt = markdown_html_image_gallery_attribute(tag.attributes, "alt").unwrap_or(
        "",
      )
      let resolved = markdown_resolve_image_source(source, base_dir)
      let (image_size, image_width_fraction) = markdown_html_image_gallery_image_size(
        tag.attributes,
        base,
        resolved,
      )
      let image_size = @core.Size::new(
        width=image_size.width,
        height=image_size.height + markdown_html_image_gallery_row_gap,
      )
      Some(
        RichTextRun::new(
          text=tag.raw,
          visual_text=Some(alt),
          image_source=Some(resolved),
          image_size=Some(image_size),
          image_width_fraction~,
          font=Some({ ..base, weight: 600 }),
        ),
      )
    }
    _ => None
  }
}

///|
/// Box size plus optional content-column fraction for one gallery image.
/// Explicit pixel attributes win; otherwise the intrinsic header size (when
/// the host can provide it) supplies the aspect ratio, so percentage-width
/// images keep their real shape instead of a placeholder 16:9 box.
fn markdown_html_image_gallery_image_size(
  attributes : Array[MarkdownHtmlImageGalleryAttribute],
  base : @core.FontSpec,
  source : String,
) -> (@core.Size, Double?) {
  let fallback = @core.Size::new(width=base.size * 8.0, height=base.size * 4.5)
  let intrinsic = match markdown_image_metrics_size(source) {
    Some(size) if size.width > 0.0 && size.height > 0.0 => Some(size)
    _ => None
  }
  let aspect = match intrinsic {
    Some(size) => size.width / size.height
    None => fallback.width / fallback.height
  }
  let width = match markdown_html_image_gallery_attribute(attributes, "width") {
    Some(value) => markdown_html_image_gallery_dimension(value)
    None => None
  }
  let height = match
    markdown_html_image_gallery_attribute(attributes, "height") {
    Some(value) => markdown_html_image_gallery_dimension(value)
    None => None
  }
  match (width, height) {
    (Some(Pixels(width)), Some(Pixels(height))) =>
      (@core.Size::new(width~, height~), None)
    (Some(Pixels(width)), _) =>
      (@core.Size::new(width~, height=width / aspect), None)
    (Some(Fraction(fraction)), Some(Pixels(height))) =>
      (@core.Size::new(width=fallback.width, height~), Some(fraction))
    (Some(Fraction(fraction)), _) =>
      (intrinsic.unwrap_or(fallback), Some(fraction))
    (None, Some(Pixels(height))) =>
      (@core.Size::new(width=height * aspect, height~), None)
    (None, Some(Fraction(_))) | (None, None) =>
      (intrinsic.unwrap_or(fallback), None)
  }
}

///|
fn markdown_html_image_gallery_dimension(
  source : String,
) -> MarkdownHtmlImageGalleryDimension? {
  let value = source.trim().to_owned()
  if value == "" {
    return None
  }
  let chars = value.to_array()
  let percent = chars.length() > 1 && chars[chars.length() - 1] == '%'
  let unit_length = if percent {
    1
  } else if value.to_lower().has_suffix("px") {
    2
  } else {
    0
  }
  let number_end = chars.length() - unit_length
  match markdown_html_image_gallery_decimal(chars, number_end) {
    Some(number) if number > 0.0 =>
      if percent {
        Some(Fraction(min_double(1.0, number / 100.0)))
      } else {
        Some(Pixels(number))
      }
    _ => None
  }
}

///|
fn markdown_html_image_gallery_decimal(
  chars : Array[Char],
  end : Int,
) -> Double? {
  if end <= 0 {
    return None
  }
  let mut result = 0.0
  let mut fraction = 0.1
  let mut decimal = false
  let mut digit_count = 0
  for index in 0..<end {
    let ch = chars[index]
    if ch == '.' && !decimal {
      decimal = true
    } else {
      match markdown_html_image_gallery_digit(ch) {
        Some(digit) => {
          digit_count = digit_count + 1
          if decimal {
            result = result + digit.to_double() * fraction
            fraction = fraction / 10.0
          } else {
            result = result * 10.0 + digit.to_double()
          }
        }
        None => return None
      }
    }
  }
  if digit_count == 0 {
    None
  } else {
    Some(result)
  }
}

///|
fn markdown_html_image_gallery_digit(ch : Char) -> Int? {
  match ch {
    '0' => Some(0)
    '1' => Some(1)
    '2' => Some(2)
    '3' => Some(3)
    '4' => Some(4)
    '5' => Some(5)
    '6' => Some(6)
    '7' => Some(7)
    '8' => Some(8)
    '9' => Some(9)
    _ => None
  }
}

///|
fn markdown_html_image_gallery_attribute(
  attributes : Array[MarkdownHtmlImageGalleryAttribute],
  name : String,
) -> String? {
  for attribute in attributes {
    if attribute.name == name {
      return attribute.value
    }
  }
  None
}

///|
fn markdown_html_image_gallery_tag_at(
  chars : Array[Char],
  start : Int,
) -> MarkdownHtmlImageGalleryTagParseResult? {
  if start < 0 || start >= chars.length() || chars[start] != '<' {
    return None
  }
  let mut index = start + 1
  let mut closing = false
  if index < chars.length() && chars[index] == '/' {
    closing = true
    index = index + 1
  }
  let name_start = index
  if index >= chars.length() ||
    !markdown_html_image_gallery_tag_name_start(chars[index]) {
    return None
  }
  index = index + 1
  while index < chars.length() &&
        markdown_html_image_gallery_tag_name_char(chars[index]) {
    index = index + 1
  }
  let name = String::from_array(chars[name_start:index]).to_lower()
  let attributes : Array[MarkdownHtmlImageGalleryAttribute] = []
  let mut self_closing = false
  while index < chars.length() {
    index = markdown_html_image_gallery_skip_space(chars, index)
    if index >= chars.length() {
      return None
    }
    if chars[index] == '>' {
      let end = index + 1
      return Some({
        tag: {
          name,
          attributes,
          raw: String::from_array(chars[start:end]),
          closing,
          self_closing,
        },
        end,
      })
    }
    if chars[index] == '/' &&
      index + 1 < chars.length() &&
      chars[index + 1] == '>' {
      self_closing = true
      let end = index + 2
      return Some({
        tag: {
          name,
          attributes,
          raw: String::from_array(chars[start:end]),
          closing,
          self_closing,
        },
        end,
      })
    }
    if closing || !markdown_html_image_gallery_attribute_name_char(chars[index]) {
      return None
    }
    let attribute_start = index
    index = index + 1
    while index < chars.length() &&
          markdown_html_image_gallery_attribute_name_char(chars[index]) {
      index = index + 1
    }
    let attribute_name = String::from_array(chars[attribute_start:index]).to_lower()
    index = markdown_html_image_gallery_skip_space(chars, index)
    let mut value : String? = None
    if index < chars.length() && chars[index] == '=' {
      index = markdown_html_image_gallery_skip_space(chars, index + 1)
      if index >= chars.length() {
        return None
      }
      if chars[index] == '"' || chars[index] == '\'' {
        let quote = chars[index]
        let value_start = index + 1
        index = value_start
        while index < chars.length() && chars[index] != quote {
          index = index + 1
        }
        if index >= chars.length() {
          return None
        }
        value = Some(String::from_array(chars[value_start:index]))
        index = index + 1
      } else {
        let value_start = index
        while index < chars.length() &&
              !markdown_html_image_gallery_space(chars[index]) &&
              chars[index] != '>' &&
              !(chars[index] == '/' &&
              index + 1 < chars.length() &&
              chars[index + 1] == '>') {
          index = index + 1
        }
        if value_start == index {
          return None
        }
        value = Some(String::from_array(chars[value_start:index]))
      }
    }
    attributes.push({ name: attribute_name, value })
  }
  None
}

///|
fn markdown_html_image_gallery_skip_space(
  chars : Array[Char],
  start : Int,
) -> Int {
  let mut index = start
  while index < chars.length() &&
        markdown_html_image_gallery_space(chars[index]) {
    index = index + 1
  }
  index
}

///|
fn markdown_html_image_gallery_space(ch : Char) -> Bool {
  ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t'
}

///|
fn markdown_html_image_gallery_tag_name_start(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')
}

///|
fn markdown_html_image_gallery_tag_name_char(ch : Char) -> Bool {
  markdown_html_image_gallery_tag_name_start(ch) ||
  (ch >= '0' && ch <= '9') ||
  ch == '-' ||
  ch == ':'
}

///|
fn markdown_html_image_gallery_attribute_name_char(ch : Char) -> Bool {
  markdown_html_image_gallery_tag_name_char(ch) || ch == '_'
}
