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
