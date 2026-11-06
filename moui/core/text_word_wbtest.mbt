///|
/// 白盒：双击选词的词边界子集。返回范围必须落在 grapheme 边界上，
/// Han/kana/Hangul 逐字成词，`_` 与带音标的拉丁字母并入词内。

///|
fn test_word_span(text : String, index : Int32) -> (Int32, Int32) {
  let range = text_word_range_at(text, index)
  (range.start, range.end)
}

///|
test "double click selects the latin word run" {
  assert_eq(test_word_span("hello world", 2), (0, 5))
  assert_eq(test_word_span("hello world", 6), (6, 11))
  // The blank run is its own selection, so the gap never borrows a letter.
  assert_eq(test_word_span("hello world", 5), (5, 6))
  assert_eq(test_word_span("foo_bar baz", 3), (0, 7))
  assert_eq(test_word_span("let x=1", 4), (4, 5))
  assert_eq(test_word_span("let x=1", 5), (5, 6))
}

///|
test "non-ascii letters keep their word whole" {
  assert_eq(test_word_span("café next", 2), (0, 4))
  assert_eq(test_word_span("Москва река", 9), (7, 11))
}

///|
test "cjk ideographs kana and hangul segment per character" {
  assert_eq(test_word_span("你好吗", 1), (1, 2))
  assert_eq(test_word_span("中文 abc", 1), (1, 2))
  assert_eq(test_word_span("中文 abc", 4), (3, 6))
  assert_eq(test_word_span("カタカナ", 2), (2, 3))
  assert_eq(test_word_span("한글 텍스트", 1), (1, 2))
}

///|
test "punctuation stands alone" {
  assert_eq(test_word_span("a.b", 1), (1, 2))
  assert_eq(test_word_span("end.", 3), (3, 4))
}

///|
test "word ranges never split a grapheme cluster" {
  // A ZWJ family is one cluster: the singleton run expands to cover it whole.
  let family = "\u{1F468}\u200D\u{1F469}"
  assert_eq(test_word_span(family, 0), (0, 3))
  assert_eq(test_word_span(family, 1), (0, 3))
  assert_eq(test_word_span(family, 2), (0, 3))
}

///|
test "word lookup clamps out of range indices" {
  assert_eq(test_word_span("", 0), (0, 0))
  assert_eq(test_word_span("hi", 99), (0, 2))
  assert_eq(test_word_span("hi", -3), (0, 2))
  assert_eq(test_word_span("one two", 7), (4, 7))
}

///|
test "arabic and hebrew words join on double-click" {
  // Arabic: letters and combining marks form one run; the space splits words.
  let arabic = "مرحبا بالعالم"
  let first = text_word_range_at(arabic, 0)
  inspect(first.end - first.start, content="5")
  let second = text_word_range_at(arabic, 6)
  inspect(second.end - second.start, content="7")
  // Hebrew including gershayim and niqqud joins similarly.
  let hebrew = "שָׁלוֹם עוֹלָם"
  let hebrew_first = text_word_range_at(hebrew, 0)
  inspect(hebrew_first.end > hebrew_first.start, content="true")
  // Mixed Latin/Arabic: script change does not split a word run (both JoinWord).
  let mixed = "abcمرحبا"
  let mixed_range = text_word_range_at(mixed, 1)
  inspect(mixed_range.end - mixed_range.start, content="8")
}
