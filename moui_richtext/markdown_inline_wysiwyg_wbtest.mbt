///|
/// WYSIWYG inline coverage for list items, quotes, and table cells: the
/// visible text carries the styling and hides the raw markers, while the
/// source text (and source ranges) keep them for editing round-trips.

///|
test "table cell runs parse inline markers and hide them visually" {
  let document = markdown_document(
    "| c1 | c2 |\n| --- | --- |\n| `A` | **AA** |\n",
    base=mv_font(),
  )
  guard document.blocks[0].table is Some(table) else {
    fail("expected a table")
  }
  // The separator row is consumed by the table parser: header + one body row.
  inspect(table.rows.length(), content="2")
  // Header cells parse plain (single-span cells keep the plain path).
  guard table.rows[0][0].runs.is_empty() else { fail("plain cell had runs") }
  // Styled cells: raw text keeps markers, runs hide them.
  let code_cell = table.rows[1][0]
  inspect(code_cell.text, content="`A`")
  guard code_cell.runs.length() == 1 else { fail("code cell run count") }
  inspect(code_cell.runs[0].text, content="`A`")
  guard code_cell.runs[0].visual_text == Some("A") else {
    fail("code cell run should hide its markers")
  }
  guard code_cell.runs[0].source_range is Some(_) else {
    fail("code cell run lost its source range")
  }
  let bold_cell = table.rows[1][1]
  inspect(bold_cell.text, content="**AA**")
  guard bold_cell.runs[0].visual_text == Some("AA") else {
    fail("bold cell run should hide its markers")
  }
  guard bold_cell.runs[0].font.unwrap_or(mv_font()).weight == 700 else {
    fail("bold cell run is not bold")
  }
}

///|
test "table cell plain text keeps the single-run layout path" {
  let document = markdown_document(
    "| a | b |\n| --- | --- |\n| plain | text |\n",
    base=mv_font(),
  )
  guard document.blocks[0].table is Some(table) else {
    fail("expected a table")
  }
  // Single plain span cells keep empty runs: the historical plain path
  // paints them exactly as before.
  guard table.rows[1][0].runs.is_empty() else {
    fail("plain cell should not carry runs")
  }
  inspect(table.rows[1][0].text, content="plain")
}

///|
test "markdown_viewer paints styled table cells without markers" {
  let layers = mv_paint("| h |\n| --- |\n| `A` **B** |\n")
  let runs = mv_layer_text_commands(layers)
  // The styled cell's visible text appears without back/asterisk markers.
  let joined = runs.map(run => run.text).join("|")
  assert_true(joined.contains("A"))
  assert_true(joined.contains("B"))
  assert_false(joined.contains("`A`"))
  assert_false(joined.contains("**B**"))
}

///|
test "list items and quotes parse styled inlines from source" {
  let blocks = parse_markdown(
    "- `A` **AA**\n- [ ] `A` **AA**\n1. `A` **AA**\n\n> `A` **AA**\n",
  )
  let kinds_of = fn(block : MarkdownBlock) -> Array[String] {
    block.inlines.map(inline => {
      match inline.kind {
        Code => "C"
        Bold => "B"
        _ => "P"
      }
    })
  }
  // Unordered / task / ordered items all parse the same styled spans as a
  // paragraph would (code + bold), with the marker prefix stripped from
  // the item text.
  inspect(blocks[0].text, content="`A` **AA**")
  guard kinds_of(blocks[0]).contains("C") && kinds_of(blocks[0]).contains("B") else {
    fail("unordered item lost inline styles")
  }
  inspect(blocks[1].text, content="`A` **AA**")
  guard kinds_of(blocks[1]).contains("C") && kinds_of(blocks[1]).contains("B") else {
    fail("task item lost inline styles")
  }
  inspect(blocks[2].text, content="`A` **AA**")
  guard kinds_of(blocks[2]).contains("C") && kinds_of(blocks[2]).contains("B") else {
    fail("ordered item lost inline styles")
  }
  // The quote keeps its `>` stripped and the markers in text.
  inspect(blocks[3].text, content="`A` **AA**")
  guard kinds_of(blocks[3]).contains("C") && kinds_of(blocks[3]).contains("B") else {
    fail("quote lost inline styles")
  }
}

///|
/// A backtick run only opens a code span when it closes on its own source
/// line. CommonMark lets it close anywhere in the paragraph, and a paragraph
/// here can be an entire document: a single stray backtick in a novel-sized
/// block closed 32k lines later, producing one multi-megabyte code span that
/// the layout then tried to measure in one piece.
test "unclosed backtick on its own line stays literal text" {
  let inlines = parse_markdown_inlines_with_definitions(
    "before `stray\nnext line `closed` here",
    [],
  )
  // The stray backtick is literal, so it does not open a span that swallows
  // the following line; the plain text keeps it verbatim.
  let plain = inlines
    .filter(inline => inline.kind == Plain)
    .map(inline => inline.text)
    .join("")
  assert_true(plain.contains("`stray"))
  assert_true(
    !inlines.any(inline => inline.kind == Code && inline.text.contains("stray")),
  )
  // The well-formed span on the second line still parses as code.
  assert_true(
    inlines.any(inline => inline.kind == Code && inline.text == "closed"),
  )
}

///|
/// A code span that does close on its own line is untouched by the rule.
test "backtick closing on the same line still parses as code" {
  let inlines = parse_markdown_inlines_with_definitions("a `code` b", [])
  assert_true(
    inlines.any(inline => inline.kind == Code && inline.text == "code"),
  )
}

///|
/// The regression this rule exists for: one stray backtick in a paragraph that
/// happens to be the whole document must not turn everything up to the next
/// backtick into a single code span. Before the rule, the span below covered
/// every line between the two backticks.
test "a stray backtick does not swallow the rest of a huge paragraph" {
  let parts : Array[String] = []
  for index in 0..<2000 {
    parts.push(
      "　　第" +
      index.to_string() +
      "段正文，中间夹一个反引号 ` 在行内。",
    )
  }
  let text = parts.join("\n")
  let inlines = parse_markdown_inlines_with_definitions(text, [])
  let longest_code = inlines
    .filter(inline => inline.kind == Code)
    .fold(init=0, (longest, inline) => {
      if inline.text.length() > longest {
        inline.text.length()
      } else {
        longest
      }
    })
  // Every backtick is unclosed on its own line, so all of them stay literal
  // and no code span survives.
  assert_true(longest_code == 0)
}
