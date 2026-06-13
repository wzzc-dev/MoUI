///|
fn assert_grapheme_boundary_indexes(
  text : String,
  expected : Array[Int],
) -> Unit raise {
  let actual = TextGraphemeBoundaries::new(text~).boundaries()
  if actual.length() != expected.length() {
    fail(
      "expected \{expected.length()} grapheme boundaries, got \{actual.length()}",
    )
  }
  for index in 0..<expected.length() {
    inspect(actual[index], content="\{expected[index]}")
  }
}

///|
fn assert_grapheme_delete_range(
  text : String,
  caret : Int,
  before : Int,
  after : Int,
  expected : TextRange,
) -> Unit raise {
  let actual = TextGraphemeBoundaries::new(text~).delete_range(
    caret, before, after,
  )
  inspect(actual.start, content="\{expected.start}")
  inspect(actual.end, content="\{expected.end}")
}

///|
fn assert_grapheme_utf8_offsets(
  text : String,
  indexes : Array[Int],
  expected : Array[Int],
) -> Unit raise {
  if indexes.length() != expected.length() {
    fail("expected matching index and utf8-offset fixture lengths")
  }
  let boundaries = TextGraphemeBoundaries::new(text~)
  for index in 0..<indexes.length() {
    inspect(
      boundaries.utf8_offset(indexes[index]),
      content="\{expected[index]}",
    )
  }
}

///|
fn assert_grapheme_nearest_utf8_offsets(
  text : String,
  indexes : Array[Int],
  expected : Array[Int],
) -> Unit raise {
  if indexes.length() != expected.length() {
    fail("expected matching index and normalized utf8-offset fixture lengths")
  }
  let boundaries = TextGraphemeBoundaries::new(text~)
  for index in 0..<indexes.length() {
    inspect(
      boundaries.nearest_boundary_utf8_offset(indexes[index]),
      content="\{expected[index]}",
    )
  }
}

///|
test "grapheme boundary scanner covers uax control emoji ri and indic rules" {
  assert_grapheme_boundary_indexes("A\r\nB", [0, 1, 3, 4])
  assert_grapheme_boundary_indexes("A\u{0007}\u{0301}B", [0, 1, 2, 3, 4])
  assert_grapheme_boundary_indexes("\u{0600}A", [0, 2])
  assert_grapheme_boundary_indexes("\u{0D4E}\u{0D15}", [0, 2])
  assert_grapheme_boundary_indexes("A\u{13430}\u{0301}B", [0, 1, 2, 3, 4])
  assert_grapheme_boundary_indexes("A\u{0483}B", [0, 2, 3])
  assert_grapheme_boundary_indexes("A\u{200D}B", [0, 2, 3])
  assert_grapheme_boundary_indexes("A\u{1D165}B", [0, 2, 3])
  assert_grapheme_boundary_indexes("A\u{0915}\u{093E}B", [0, 1, 3, 4])
  assert_grapheme_boundary_indexes("\u{0A95}\u{0A83}A", [0, 2, 3])
  assert_grapheme_boundary_indexes("\u{1100}\u{1161}\u{11A8}", [0, 3])
  assert_grapheme_boundary_indexes("A\u{A960}\u{D7B0}\u{D7CB}B", [0, 1, 4, 5])
  assert_grapheme_boundary_indexes("A\u{AC00}\u{11A8}B", [0, 1, 3, 4])
  assert_grapheme_boundary_indexes("👨🏾‍🚀", [0, 4])
  assert_grapheme_boundary_indexes("👨‍A", [0, 2, 3])
  assert_grapheme_boundary_indexes("\u{1FC00}\u{200D}\u{1FC01}", [0, 3])
  assert_grapheme_boundary_indexes("A1\u{FE0F}\u{20E3}B", [0, 1, 4, 5])
  assert_grapheme_boundary_indexes("A\u{1F3F4}\u{E0067}\u{E0062}\u{E007F}B", [
    0, 1, 5, 6,
  ])
  assert_grapheme_boundary_indexes("\u{1F1FA}\u{1F1F8}\u{1F1E8}", [0, 2, 3])
  assert_grapheme_boundary_indexes("\u{1F1FA}\u{1F1F8}\u{1F1E8}\u{1F1E6}", [
    0, 2, 4,
  ])
  assert_grapheme_boundary_indexes("A\u{1F1FA}\u{1F1F8}\u{1F1E8}B", [
    0, 1, 3, 4, 5,
  ])
  assert_grapheme_boundary_indexes("A\u{0600}\u{0628}\u{0651}B", [0, 1, 4, 5])
  assert_grapheme_boundary_indexes("A\u{0E01}\u{0E34}B", [0, 1, 3, 4])
  assert_grapheme_boundary_indexes("A\u{0E81}\u{0EB4}B", [0, 1, 3, 4])
  assert_grapheme_boundary_indexes("A\u{0D9A}\u{0DCF}B", [0, 1, 3, 4])
  assert_grapheme_boundary_indexes("A\u{0D9A}\u{0DCA}\u{0DBB}B", [0, 1, 3, 4, 5])
  assert_grapheme_boundary_indexes("A\u{1780}\u{17B6}B", [0, 1, 3, 4])
  assert_grapheme_boundary_indexes("A\u{1780}\u{17D2}\u{179A}B", [0, 1, 4, 5])
  assert_grapheme_boundary_indexes("A\u{1000}\u{1039}\u{1001}B", [0, 1, 4, 5])
  assert_grapheme_boundary_indexes("क्‍ष", [0, 4])
  assert_grapheme_boundary_indexes("क्‍A", [0, 3, 4])
  assert_grapheme_boundary_indexes("क़्ष", [0, 4])
  assert_grapheme_boundary_indexes("क़्A", [0, 3, 4])
  assert_grapheme_boundary_indexes("\u{094D}\u{0915}", [0, 1, 2])
  assert_grapheme_boundary_indexes("a\u{094D}\u{0924}", [0, 2, 3])
  assert_grapheme_boundary_indexes("क्A", [0, 2, 3])
  assert_grapheme_boundary_indexes("क् A", [0, 2, 3, 4])
  assert_grapheme_boundary_indexes("क्‌ष", [0, 3, 4])
  assert_grapheme_boundary_indexes("\u{1B32}\u{1B44}\u{1B2F}", [0, 3])
  assert_grapheme_boundary_indexes(
    "\u{179F}\u{17D2}\u{178F}\u{17D2}\u{179A}\u{17B8}",
    [0, 6],
  )
  assert_grapheme_boundary_indexes("A\u{200C}B", [0, 2, 3])
  assert_cluster_caret_movement("A👨🏾‍🚀B", 1, 5)
}

///|
test "grapheme boundary contract covers ranges deletes and utf8 offsets" {
  let text = "A👩‍💻B"
  let boundaries = TextGraphemeBoundaries::new(text~)
  inspect(boundaries.length(), content="5")
  inspect(boundaries.cluster_count(), content="3")
  inspect(boundaries.is_boundary(1), content="true")
  inspect(boundaries.is_boundary(2), content="false")
  inspect(boundaries.previous_boundary(4), content="1")
  inspect(boundaries.next_boundary(1), content="4")
  inspect(boundaries.floor_boundary(3), content="1")
  inspect(boundaries.ceil_boundary(2), content="4")
  inspect(boundaries.nearest_boundary(2), content="1")
  inspect(boundaries.nearest_boundary(3), content="4")
  let expanded = boundaries.normalize_range(TextRange::new(start=2, end=3))
  inspect(expanded.start, content="1")
  inspect(expanded.end, content="4")
  let collapsed = boundaries.normalize_range(TextRange::collapsed(3))
  inspect(collapsed.start, content="4")
  inspect(collapsed.end, content="4")
  let delete = boundaries.delete_range(4, 1, 0)
  inspect(delete.start, content="1")
  inspect(delete.end, content="4")
  inspect(boundaries.utf8_offset(4), content="12")
  inspect(boundaries.utf8_offset(5), content="13")
  inspect(boundaries.nearest_boundary_utf8_offset(2), content="1")
  inspect(boundaries.nearest_boundary_utf8_offset(3), content="12")
  assert_grapheme_delete_range(
    "A👨🏾‍🚀B",
    5,
    1,
    0,
    TextRange::new(start=1, end=5),
  )
  assert_grapheme_delete_range(
    "Aक्‍षB",
    5,
    1,
    0,
    TextRange::new(start=1, end=5),
  )
  assert_grapheme_delete_range(
    "Aक्‍AB",
    4,
    1,
    0,
    TextRange::new(start=1, end=4),
  )
  assert_grapheme_delete_range(
    "Aक़्षB",
    5,
    1,
    0,
    TextRange::new(start=1, end=5),
  )
  assert_grapheme_delete_range(
    "A\u{1D165}B",
    2,
    1,
    0,
    TextRange::new(start=0, end=2),
  )
  assert_grapheme_delete_range(
    "A1\u{FE0F}\u{20E3}B",
    4,
    1,
    0,
    TextRange::new(start=1, end=4),
  )
  assert_grapheme_delete_range(
    "A\u{1F3F4}\u{E0067}\u{E0062}\u{E007F}B",
    5,
    1,
    0,
    TextRange::new(start=1, end=5),
  )
  assert_grapheme_delete_range(
    "A\u{1000}\u{1039}\u{1001}B",
    4,
    1,
    0,
    TextRange::new(start=1, end=4),
  )
  assert_grapheme_utf8_offsets("Aक्‍षB", [0, 1, 5, 6], [0, 1, 13, 14])
  assert_grapheme_utf8_offsets("Aक़्षB", [0, 1, 5, 6], [0, 1, 13, 14])
  assert_grapheme_utf8_offsets("A\u{0600}B", [0, 2, 3], [0, 3, 4])
  assert_grapheme_utf8_offsets("A\u{0D4E}B", [0, 1, 3], [0, 1, 5])
  assert_grapheme_utf8_offsets("A\u{1D165}B", [0, 2, 3], [0, 5, 6])
  assert_grapheme_utf8_offsets("A1\u{FE0F}\u{20E3}B", [0, 1, 4, 5], [0, 1, 8, 9])
  assert_grapheme_nearest_utf8_offsets("A1\u{FE0F}\u{20E3}B", [2, 3], [1, 8])
  assert_grapheme_utf8_offsets(
    "A\u{1F3F4}\u{E0067}\u{E0062}\u{E007F}B",
    [0, 1, 5, 6],
    [0, 1, 17, 18],
  )
  assert_grapheme_nearest_utf8_offsets("Aक्‍षB", [2, 3, 4], [1, 1, 13])
  assert_grapheme_utf8_offsets("A\u{1000}\u{1039}\u{1001}B", [0, 1, 4, 5], [
    0, 1, 10, 11,
  ])
}
