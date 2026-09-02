///|
fn markdown_editor_active_heading(
  blocks : Array[MarkdownEditorBlock],
) -> String {
  for block in blocks {
    match block.block.kind {
      Heading(_) => return block.block.text
      _ => ()
    }
  }
  "Untitled"
}

///|
priv struct MarkdownEditorFrontMatterMetadata {
  title : String
  tags : Array[String]
}

///|
fn markdown_editor_front_matter_metadata(
  blocks : Array[MarkdownEditorBlock],
) -> MarkdownEditorFrontMatterMetadata {
  if blocks.length() == 0 {
    return { title: "", tags: [] }
  }
  match blocks[0].block.kind {
    FrontMatter =>
      markdown_editor_parse_front_matter_metadata(blocks[0].block.text)
    _ => { title: "", tags: [] }
  }
}

///|
fn markdown_editor_parse_front_matter_metadata(
  source : String,
) -> MarkdownEditorFrontMatterMetadata {
  let tags : Array[String] = []
  let mut title = ""
  let mut collecting_tags = false
  for line in markdown_editor_lines(source) {
    let text = line.text.trim().to_owned()
    if text.has_prefix("title:") {
      let value = markdown_editor_substring(
          text,
          6,
          markdown_editor_text_length(text),
        )
        .trim()
        .to_owned()
      title = markdown_editor_front_matter_scalar(value)
      collecting_tags = false
    } else if text.has_prefix("tags:") {
      tags.clear()
      let value = markdown_editor_substring(
          text,
          5,
          markdown_editor_text_length(text),
        )
        .trim()
        .to_owned()
      if value == "" {
        collecting_tags = true
      } else {
        tags.append(markdown_editor_front_matter_tags(value))
        collecting_tags = false
      }
    } else if collecting_tags && text.has_prefix("- ") {
      let value = markdown_editor_substring(
          text,
          2,
          markdown_editor_text_length(text),
        )
        .trim()
        .to_owned()
      let tag = markdown_editor_front_matter_scalar(value)
      if tag != "" {
        tags.push(tag)
      }
    } else if text != "" {
      collecting_tags = false
    }
  }
  { title, tags }
}

///|
fn markdown_editor_front_matter_tags(source : String) -> Array[String] {
  let text = source.trim().to_owned()
  if text == "" {
    []
  } else if text.has_prefix("[") && text.has_suffix("]") {
    let length = markdown_editor_text_length(text)
    markdown_editor_split_front_matter_tag_list(
      markdown_editor_substring(text, 1, length - 1),
    )
  } else {
    let tag = markdown_editor_front_matter_scalar(text)
    if tag == "" {
      []
    } else {
      [tag]
    }
  }
}

///|
fn markdown_editor_split_front_matter_tag_list(
  source : String,
) -> Array[String] {
  let tags : Array[String] = []
  let current : Array[Char] = []
  let mut quoted = false
  let mut quote = '"'
  for ch in source {
    if quoted {
      current.push(ch)
      if ch == quote {
        quoted = false
      }
    } else if ch == '"' || ch == '\'' {
      quoted = true
      quote = ch
      current.push(ch)
    } else if ch == ',' {
      markdown_editor_push_front_matter_tag(tags, String::from_array(current))
      current.clear()
    } else {
      current.push(ch)
    }
  }
  markdown_editor_push_front_matter_tag(tags, String::from_array(current))
  tags
}

///|
fn markdown_editor_push_front_matter_tag(
  tags : Array[String],
  source : String,
) -> Unit {
  let tag = markdown_editor_front_matter_scalar(source.trim().to_owned())
  if tag != "" {
    tags.push(tag)
  }
}

///|
fn markdown_editor_front_matter_scalar(source : String) -> String {
  let text = source.trim().to_owned()
  let chars = text.to_array()
  if chars.length() >= 2 &&
    (
      (chars[0] == '"' && chars[chars.length() - 1] == '"') ||
      (chars[0] == '\'' && chars[chars.length() - 1] == '\'')
    ) {
    String::from_array(chars[1:chars.length() - 1]).trim().to_owned()
  } else {
    text
  }
}

///|
fn markdown_editor_reading_minutes(word_count : Int) -> Int {
  if word_count <= 0 {
    0
  } else {
    (word_count + 219) / 220
  }
}

///|
fn markdown_editor_outline(
  blocks : Array[MarkdownEditorBlock],
) -> Array[MarkdownEditorOutlineItem] {
  let items : Array[MarkdownEditorOutlineItem] = []
  for block in blocks {
    match block.block.kind {
      Heading(level) =>
        items.push({
          level,
          title: block.block.text,
          source_start: block.content_range.start,
        })
      _ => ()
    }
  }
  items
}
