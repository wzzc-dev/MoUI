///|
/// A deliberately small HTML subset for Markdown presentation blocks. Raw
/// HTML remains raw by default; this only recognizes a closed `div`/`center`
/// container whose body consists entirely of `img` and `br` tags.
priv struct MarkdownHtmlImageGallery {
  runs : Array[RichTextRun]
  line_align : @core.TextAlign
}

///|
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
fn markdown_html_image_gallery(
  html : String,
  base : @core.FontSpec,
  base_dir : String?,
) -> MarkdownHtmlImageGallery? {
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
      let runs : Array[RichTextRun] = []
      let mut image_count = 0
      let mut index = opening.end
      while index < chars.length() {
        index = markdown_html_image_gallery_skip_space(chars, index)
        match markdown_html_image_gallery_tag_at(chars, index) {
          Some(parsed) => {
            let tag = parsed.tag
            index = parsed.end
            if tag.closing {
              if tag.name != outer.name ||
                image_count == 0 ||
                markdown_html_image_gallery_skip_space(chars, index) !=
                chars.length() {
                return None
              }
              return Some({ runs, line_align })
            }
            match tag.name {
              "img" =>
                match
                  markdown_html_image_gallery_image_run(tag, base, base_dir) {
                  Some(run) => {
                    runs.push(run)
                    image_count = image_count + 1
                  }
                  None => return None
                }
              "br" =>
                runs.push(
                  RichTextRun::new(
                    text=tag.raw,
                    visual_text=Some("\n"),
                    font=Some(base),
                  ),
                )
              _ => return None
            }
          }
          None => return None
        }
      } nobreak {
        None
      }
    }
    None => None
  }
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
      let (image_size, image_width_fraction) = markdown_html_image_gallery_image_size(
        tag.attributes,
        base,
      )
      Some(
        RichTextRun::new(
          text=tag.raw,
          visual_text=Some(alt),
          image_source=Some(markdown_resolve_image_source(source, base_dir)),
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
fn markdown_html_image_gallery_image_size(
  attributes : Array[MarkdownHtmlImageGalleryAttribute],
  base : @core.FontSpec,
) -> (@core.Size, Double?) {
  let fallback = @core.Size::new(width=base.size * 8.0, height=base.size * 4.5)
  let width = match markdown_html_image_gallery_attribute(attributes, "width") {
    Some(value) => markdown_html_image_gallery_dimension(value)
    None => None
  }
  let height = match
    markdown_html_image_gallery_attribute(attributes, "height") {
    Some(value) => markdown_html_image_gallery_dimension(value)
    None => None
  }
  let aspect = fallback.width / fallback.height
  match (width, height) {
    (Some(Pixels(width)), Some(Pixels(height))) =>
      (@core.Size::new(width~, height~), None)
    (Some(Pixels(width)), _) =>
      (@core.Size::new(width~, height=width / aspect), None)
    (Some(Fraction(fraction)), Some(Pixels(height))) =>
      (@core.Size::new(width=fallback.width, height~), Some(fraction))
    (Some(Fraction(fraction)), _) => (fallback, Some(fraction))
    (None, Some(Pixels(height))) =>
      (@core.Size::new(width=height * aspect, height~), None)
    (None, Some(Fraction(_))) | (None, None) => (fallback, None)
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
