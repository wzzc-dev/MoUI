///|
fn MarkdownEditorApp::html_export_document(self : MarkdownEditorApp) -> String {
  let snapshot = self.document_session.snapshot()
  let title = markdown_editor_document_title(
    path=self.document_path,
    fallback=snapshot.active_heading,
  )
  markdown_editor_html_document(snapshot, title)
}

///|
fn markdown_editor_html_document(
  snapshot : MarkdownEditorSnapshot,
  title : String,
) -> String {
  markdown_join_lines([
    "<!doctype html>",
    "<html>",
    "<head>",
    "  <meta charset=\"utf-8\">",
    "  <title>" + markdown_editor_html_escape_text(title) + "</title>",
    "</head>",
    "<body>",
    markdown_editor_html_blocks(snapshot.blocks),
    "</body>",
    "</html>",
  ])
}

///|
fn markdown_editor_html_blocks(blocks : Array[MarkdownEditorBlock]) -> String {
  let parts : Array[String] = []
  let mut index = 0
  while index < blocks.length() {
    let block = blocks[index].block
    match block.kind {
      UnorderedListItem | TaskListItem(_) => {
        let group = markdown_editor_html_unordered_list(blocks, index)
        parts.push(group.html)
        index = group.next_index
        continue
      }
      OrderedListItem(_) => {
        let group = markdown_editor_html_ordered_list(blocks, index)
        parts.push(group.html)
        index = group.next_index
        continue
      }
      Paragraph =>
        if block.text.trim().to_owned() != "" {
          parts.push(
            "<p>" + markdown_editor_html_inlines(block.inlines) + "</p>",
          )
        }
      Heading(level) => {
        let tag = "h" + markdown_editor_clamp_int(level, 1, 6).to_string()
        parts.push(
          "<" +
          tag +
          ">" +
          markdown_editor_html_inlines(block.inlines) +
          "</" +
          tag +
          ">",
        )
      }
      Blockquote =>
        parts.push(
          "<blockquote><p>" +
          markdown_editor_html_inlines(block.inlines) +
          "</p></blockquote>",
        )
      CodeBlock => parts.push(markdown_editor_html_code_block(block))
      HorizontalRule => parts.push("<hr>")
      Table => parts.push(markdown_editor_html_table(block))
      FootnoteDefinition(label) =>
        parts.push(
          "<section class=\"footnote-definition\" id=\"fn-" +
          markdown_editor_html_escape_attribute(label) +
          "\"><p><sup>" +
          markdown_editor_html_escape_text(label) +
          "</sup> " +
          markdown_editor_html_inlines(block.inlines) +
          "</p></section>",
        )
      HtmlBlock => parts.push(block.text)
      FrontMatter => ()
    }
    index = index + 1
  }
  markdown_join_lines(parts)
}

///|
priv struct MarkdownEditorHtmlListGroup {
  html : String
  next_index : Int
}

///|
fn markdown_editor_html_unordered_list(
  blocks : Array[MarkdownEditorBlock],
  start : Int,
) -> MarkdownEditorHtmlListGroup {
  let items : Array[String] = []
  let mut index = start
  while index < blocks.length() {
    let block = blocks[index].block
    match block.kind {
      UnorderedListItem =>
        items.push(
          "<li>" + markdown_editor_html_inlines(block.inlines) + "</li>",
        )
      TaskListItem(checked) => {
        let checked_attribute = if checked { " checked" } else { "" }
        items.push(
          "<li class=\"task-list-item\"><input type=\"checkbox\" disabled" +
          checked_attribute +
          "> " +
          markdown_editor_html_inlines(block.inlines) +
          "</li>",
        )
      }
      _ => break
    }
    index = index + 1
  }
  { html: "<ul>\n" + markdown_join_lines(items) + "\n</ul>", next_index: index }
}

///|
fn markdown_editor_html_ordered_list(
  blocks : Array[MarkdownEditorBlock],
  start : Int,
) -> MarkdownEditorHtmlListGroup {
  let items : Array[String] = []
  let mut index = start
  let mut first_number = 1
  while index < blocks.length() {
    let block = blocks[index].block
    match block.kind {
      OrderedListItem(number) => {
        if index == start {
          first_number = number
        }
        items.push(
          "<li>" + markdown_editor_html_inlines(block.inlines) + "</li>",
        )
      }
      _ => break
    }
    index = index + 1
  }
  let start_attr = if first_number == 1 {
    ""
  } else {
    " start=\"" + first_number.to_string() + "\""
  }
  {
    html: "<ol" + start_attr + ">\n" + markdown_join_lines(items) + "\n</ol>",
    next_index: index,
  }
}

///|
fn markdown_editor_html_code_block(block : MarkdownBlock) -> String {
  let class_attr = match block.code_language {
    Some(language) =>
      if language.trim().to_owned() == "" {
        ""
      } else {
        " class=\"language-" +
        markdown_editor_html_escape_attribute(language.trim().to_owned()) +
        "\""
      }
    None => ""
  }
  "<pre><code" +
  class_attr +
  ">" +
  markdown_editor_html_escape_text(block.text) +
  "</code></pre>"
}

///|
fn markdown_editor_html_table(block : MarkdownBlock) -> String {
  let lines = markdown_split_lines(block.text)
  if lines.length() == 0 {
    return ""
  }
  let rows : Array[String] = []
  for index in 0..<lines.length() {
    let cells = markdown_split_table_cells(lines[index])
    let cell_html : Array[String] = []
    for cell_index in 0..<cells.length() {
      let tag = if index == 0 { "th" } else { "td" }
      let align = markdown_editor_html_table_align_attribute(
        block.table_alignments,
        cell_index,
      )
      let text = cells[cell_index].trim().to_owned()
      cell_html.push(
        "<" +
        tag +
        align +
        ">" +
        markdown_editor_html_inlines(parse_markdown_inlines(text)) +
        "</" +
        tag +
        ">",
      )
    }
    rows.push("<tr>" + cell_html.join("") + "</tr>")
  }
  let head = "<thead>\n" + rows[0] + "\n</thead>"
  let body_rows : Array[String] = []
  for index in 1..<rows.length() {
    body_rows.push(rows[index])
  }
  let body = if body_rows.length() == 0 {
    ""
  } else {
    "\n<tbody>\n" + markdown_join_lines(body_rows) + "\n</tbody>"
  }
  "<table>\n" + head + body + "\n</table>"
}

///|
fn markdown_editor_html_table_align_attribute(
  alignments : Array[@text.TextAlign?],
  index : Int,
) -> String {
  if index >= alignments.length() {
    return ""
  }
  match alignments[index] {
    Some(@text.TextAlign::TextStart) => " style=\"text-align:left\""
    Some(@text.TextAlign::TextCenter) => " style=\"text-align:center\""
    Some(@text.TextAlign::TextEnd) => " style=\"text-align:right\""
    None => ""
  }
}

///|
fn markdown_editor_html_inlines(inlines : Array[MarkdownInline]) -> String {
  let parts : Array[String] = []
  for inline in inlines {
    parts.push(markdown_editor_html_inline(inline))
  }
  parts.join("")
}

///|
fn markdown_editor_html_inline(inline : MarkdownInline) -> String {
  let text = markdown_editor_html_escape_text(inline.text)
  match inline.kind {
    Plain => text
    Bold => "<strong>" + text + "</strong>"
    Italic => "<em>" + text + "</em>"
    Code => "<code>" + text + "</code>"
    Strikethrough => "<del>" + text + "</del>"
    Link | Autolink => {
      let target = match inline.target {
        Some(target) => target
        None => inline.text
      }
      "<a href=\"" +
      markdown_editor_html_escape_attribute(target) +
      "\">" +
      text +
      "</a>"
    }
    Image => {
      let target = match inline.target {
        Some(target) => target
        None => ""
      }
      "<img src=\"" +
      markdown_editor_html_escape_attribute(target) +
      "\" alt=\"" +
      markdown_editor_html_escape_attribute(inline.text) +
      "\">"
    }
    FootnoteReference =>
      "<sup id=\"fnref-" +
      markdown_editor_html_escape_attribute(inline.text) +
      "\"><a href=\"#fn-" +
      markdown_editor_html_escape_attribute(inline.text) +
      "\">" +
      text +
      "</a></sup>"
    HtmlInline => inline.text
  }
}

///|
fn markdown_editor_html_escape_text(text : String) -> String {
  let chars : Array[Char] = []
  for ch in text {
    if ch == '&' {
      chars.append("&amp;".to_array())
    } else if ch == '<' {
      chars.append("&lt;".to_array())
    } else if ch == '>' {
      chars.append("&gt;".to_array())
    } else {
      chars.push(ch)
    }
  }
  String::from_array(chars)
}

///|
fn markdown_editor_html_escape_attribute(text : String) -> String {
  let chars : Array[Char] = []
  for ch in text {
    if ch == '&' {
      chars.append("&amp;".to_array())
    } else if ch == '<' {
      chars.append("&lt;".to_array())
    } else if ch == '>' {
      chars.append("&gt;".to_array())
    } else if ch == '"' {
      chars.append("&quot;".to_array())
    } else if ch == '\'' {
      chars.append("&#39;".to_array())
    } else {
      chars.push(ch)
    }
  }
  String::from_array(chars)
}
