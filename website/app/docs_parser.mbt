///|
priv struct WebsiteListParse {
  marker : String
  text : String
}

///|
fn website_parse_markdown_document(
  path : String,
  source : String,
) -> WebsiteDocDocument {
  let lines : Array[String] = []
  for line in source.split("\n") {
    lines.push(line.trim(char_set="\r").to_owned())
  }
  let blocks : Array[WebsiteDocBlock] = []
  let mut index = 0
  while index < lines.length() {
    let line = lines[index]
    let trimmed = line.trim().to_owned()
    if trimmed == "" {
      index = index + 1
    } else if trimmed.has_prefix("```") {
      let language = trimmed[3:].to_owned().trim().to_owned()
      let code_lines : Array[String] = []
      index = index + 1
      while index < lines.length() &&
            !lines[index].trim().to_owned().has_prefix("```") {
        code_lines.push(lines[index])
        index = index + 1
      }
      if index < lines.length() {
        index = index + 1
      }
      blocks.push(DocCodeBlock(language, code_lines.join("\n")))
    } else if website_markdown_table_starts(lines, index) {
      let table_lines : Array[String] = []
      while index < lines.length() &&
            lines[index].trim().to_owned().has_prefix("|") {
        table_lines.push(
          website_visible_inline_text(lines[index].trim().to_owned()),
        )
        index = index + 1
      }
      blocks.push(DocTable(table_lines))
    } else if website_markdown_heading_level(trimmed) > 0 {
      let level = website_markdown_heading_level(trimmed)
      blocks.push(
        DocHeading(
          level,
          website_visible_inline_text(
            trimmed[level + 1:].to_owned().trim().to_owned(),
          ),
        ),
      )
      index = index + 1
    } else if website_markdown_rule(trimmed) {
      blocks.push(DocRule)
      index = index + 1
    } else if trimmed.has_prefix(">") {
      let quote_lines : Array[String] = []
      while index < lines.length() &&
            lines[index].trim().to_owned().has_prefix(">") {
        let raw = lines[index].trim().to_owned()
        quote_lines.push(
          website_visible_inline_text(raw[1:].to_owned().trim().to_owned()),
        )
        index = index + 1
      }
      blocks.push(DocQuote(quote_lines.join(" ")))
    } else {
      match website_markdown_list_item(trimmed) {
        Some(item) => {
          blocks.push(
            DocListItem(item.marker, website_visible_inline_text(item.text)),
          )
          index = index + 1
        }
        None => {
          let paragraph_lines : Array[String] = []
          while index < lines.length() &&
                !website_markdown_paragraph_break(lines, index) {
            paragraph_lines.push(lines[index].trim().to_owned())
            index = index + 1
          }
          blocks.push(
            DocParagraph(website_visible_inline_text(paragraph_lines.join(" "))),
          )
        }
      }
    }
  }
  { title: website_document_title(path, blocks), blocks }
}

///|
fn website_document_title(
  path : String,
  blocks : Array[WebsiteDocBlock],
) -> String {
  for block in blocks {
    match block {
      DocHeading(_, title) => if title != "" { return title }
      _ => ()
    }
  }
  website_doc_entry_by_path(path).title
}

///|
fn website_markdown_paragraph_break(lines : Array[String], index : Int) -> Bool {
  if index >= lines.length() {
    return true
  }
  let trimmed = lines[index].trim().to_owned()
  trimmed == "" ||
  trimmed.has_prefix("```") ||
  trimmed.has_prefix(">") ||
  website_markdown_rule(trimmed) ||
  website_markdown_heading_level(trimmed) > 0 ||
  website_markdown_list_item(trimmed) is Some(_) ||
  website_markdown_table_starts(lines, index)
}

///|
fn website_markdown_heading_level(trimmed : String) -> Int {
  let chars = trimmed.to_array()
  let mut level = 0
  while level < chars.length() && level < 6 && chars[level] == '#' {
    level = level + 1
  }
  if level > 0 && level < chars.length() && chars[level] == ' ' {
    level
  } else {
    0
  }
}

///|
fn website_markdown_rule(trimmed : String) -> Bool {
  trimmed == "---" || trimmed == "***" || trimmed == "___"
}

///|
fn website_markdown_table_starts(lines : Array[String], index : Int) -> Bool {
  if index + 1 >= lines.length() {
    return false
  }
  let header = lines[index].trim().to_owned()
  let separator = lines[index + 1].trim().to_owned()
  header.has_prefix("|") &&
  separator.has_prefix("|") &&
  separator.contains("---")
}

///|
fn website_markdown_list_item(trimmed : String) -> WebsiteListParse? {
  if trimmed.has_prefix("- [x] ") || trimmed.has_prefix("- [X] ") {
    return Some({ marker: "x", text: trimmed[6:].to_owned() })
  }
  if trimmed.has_prefix("- [ ] ") {
    return Some({ marker: " ", text: trimmed[6:].to_owned() })
  }
  if trimmed.has_prefix("- ") ||
    trimmed.has_prefix("* ") ||
    trimmed.has_prefix("+ ") {
    return Some({ marker: "-", text: trimmed[2:].to_owned() })
  }
  let chars = trimmed.to_array()
  let mut index = 0
  while index < chars.length() &&
        chars[index].to_int() >= '0'.to_int() &&
        chars[index].to_int() <= '9'.to_int() {
    index = index + 1
  }
  if index > 0 &&
    index + 1 < chars.length() &&
    chars[index] == '.' &&
    chars[index + 1] == ' ' {
    Some({
      marker: String::from_array(chars[0:index]) + ".",
      text: String::from_array(chars[index + 2:]),
    })
  } else {
    None
  }
}

///|
fn website_visible_inline_text(value : String) -> String {
  let chars = value.to_array()
  let output : Array[Char] = []
  let mut index = 0
  while index < chars.length() {
    if chars[index] == '!' &&
      index + 1 < chars.length() &&
      chars[index + 1] == '[' {
      match website_markdown_link_label(chars, index + 1) {
        Some({ label, end_index }) => {
          output.append(label.to_array())
          index = end_index
        }
        None => {
          output.push(chars[index])
          index = index + 1
        }
      }
    } else if chars[index] == '[' {
      match website_markdown_link_label(chars, index) {
        Some({ label, end_index }) => {
          output.append(label.to_array())
          index = end_index
        }
        None => {
          output.push(chars[index])
          index = index + 1
        }
      }
    } else if chars[index] == '`' ||
      chars[index] == '*' ||
      chars[index] == '_' ||
      chars[index] == '~' {
      index = index + 1
    } else if chars[index] == '<' {
      let tag_end = website_find_char(chars, index + 1, '>')
      if tag_end >= 0 {
        index = tag_end + 1
      } else {
        output.push(chars[index])
        index = index + 1
      }
    } else {
      output.push(chars[index])
      index = index + 1
    }
  }
  String::from_array(output)
}

///|
priv struct WebsiteInlineLinkLabel {
  label : String
  end_index : Int
}

///|
fn website_markdown_link_label(
  chars : Array[Char],
  start : Int,
) -> WebsiteInlineLinkLabel? {
  let close_label = website_find_char(chars, start + 1, ']')
  if close_label < 0 ||
    close_label + 1 >= chars.length() ||
    chars[close_label + 1] != '(' {
    return None
  }
  let close_target = website_find_char(chars, close_label + 2, ')')
  if close_target < 0 {
    return None
  }
  Some({
    label: String::from_array(chars[start + 1:close_label]),
    end_index: close_target + 1,
  })
}

///|
fn website_find_char(chars : Array[Char], start : Int, needle : Char) -> Int {
  let mut index = start
  while index < chars.length() {
    if chars[index] == needle {
      return index
    }
    index = index + 1
  }
  -1
}
