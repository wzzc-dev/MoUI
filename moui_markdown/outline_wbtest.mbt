///|
fn outline_test_item(
  level : Int,
  title : String,
  source_start : Int,
) -> @richtext.MarkdownEditorOutlineItem {
  { level, title, source_start, }
}

///|
test "markdown folded outline hides nested children" {
  let outline = [
    outline_test_item(1, "First", 0),
    outline_test_item(2, "Second", 9),
    outline_test_item(3, "Third", 21),
    outline_test_item(2, "Fourth", 34),
  ]
  inspect(markdown_folded_outline(outline, []).length(), content="4")
  // Folding H2 "Second" hides H3 "Third" but not sibling H2 "Fourth".
  let folded = markdown_folded_outline(outline, [9])
  inspect(folded.length(), content="3")
  inspect(folded[0].title, content="First")
  inspect(folded[1].title, content="Second")
  inspect(folded[2].title, content="Fourth")
}

///|
test "markdown folded outline hides until same or higher level" {
  let outline = [
    outline_test_item(1, "First", 0),
    outline_test_item(2, "Second", 9),
    outline_test_item(3, "Third", 21),
    outline_test_item(4, "Fourth", 34),
    outline_test_item(1, "Fifth", 50),
  ]
  let folded = markdown_folded_outline(outline, [0])
  inspect(folded.length(), content="2")
  inspect(folded[1].title, content="Fifth")
}

///|
test "markdown outline labels truncate and pad empty titles" {
  inspect(
    markdown_outline_label(outline_test_item(1, "First", 0)),
    content="H1 First",
  )
  inspect(
    markdown_outline_label(outline_test_item(2, "", 0)),
    content="H2 Untitled",
  )
  let long = "abcdefghijklmnopqrstuvwxyz0123456789"
  inspect(
    markdown_outline_truncate_title(long),
    content="abcdefghijklmnopqrstu...",
  )
  inspect(markdown_outline_truncate_title("short"), content="short")
}

///|
test "markdown outline indent scales below the first level" {
  inspect(markdown_outline_indent_width(1), content="0")
  inspect(markdown_outline_indent_width(2), content="12")
  inspect(markdown_outline_indent_width(3), content="24")
}

///|
test "markdown outline active index tracks the caret heading" {
  let outline = [
    outline_test_item(1, "First", 0),
    outline_test_item(2, "Second", 9),
    outline_test_item(2, "Third", 21),
  ]
  inspect(markdown_active_outline_index(outline, 0), content="0")
  inspect(markdown_active_outline_index(outline, 8), content="0")
  inspect(markdown_active_outline_index(outline, 9), content="1")
  inspect(markdown_active_outline_index(outline, 100), content="2")
  inspect(markdown_active_outline_index([], 5), content="-1")
  inspect(markdown_active_outline_index(outline, -3), content="-1")
}

///|
test "markdown outline active item identity survives folding" {
  let outline = [
    outline_test_item(1, "First", 0),
    outline_test_item(2, "Second", 9),
    outline_test_item(3, "Third", 21),
  ]
  let third = outline[2]
  inspect(markdown_outline_item_is_active(outline, third, 2), content="true")
  inspect(markdown_outline_item_is_active(outline, third, 1), content="false")
  inspect(markdown_outline_item_is_active(outline, third, -1), content="false")
  inspect(markdown_outline_item_is_active(outline, third, 9), content="false")
}

///|
test "markdown reading labels describe session snapshot counts" {
  let session = @richtext.MarkdownDocumentSession::new(
    "# Title\n\nBody text here",
  )
  let snapshot = @richtext.MarkdownEditorSnapshot::parse(
    "# Title\n\nBody text here",
  )
  inspect(
    markdown_session_reading_label(session),
    content=markdown_snapshot_reading_label(snapshot),
  )
  inspect(
    markdown_session_reading_time_short_label(session),
    content=markdown_snapshot_reading_time_short_label(snapshot),
  )
}
