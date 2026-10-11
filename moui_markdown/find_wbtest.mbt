///|
test "markdown find matches preserve unicode ranges" {
  let unicode = markdown_find_matches("a🤣needle needle", "needle")
  inspect(unicode.length(), content="2")
  inspect(unicode[0].start, content="2")
  inspect(unicode[0].end, content="8")
  inspect(unicode[1].start, content="9")
  inspect(unicode[1].end, content="15")

  let overlapping = markdown_find_matches("aaaa", "aa")
  inspect(overlapping.length(), content="2")
  inspect(overlapping[0].start, content="0")
  inspect(overlapping[0].end, content="2")
  inspect(overlapping[1].start, content="2")
  inspect(overlapping[1].end, content="4")
}

///|
test "markdown find whole word uses ascii boundaries" {
  let options = { ..MarkdownFindOptions::default(), whole_word: true, }
  let whole = markdown_find_matches("🤣cat catalog cat_ cat", "cat", options~)
  inspect(whole.length(), content="2")
  inspect(whole[0].start, content="1")
  inspect(whole[0].end, content="4")
  inspect(whole[1].start, content="18")
  inspect(whole[1].end, content="21")
}

///|
test "markdown find is ascii case-insensitive by default" {
  let insensitive = markdown_find_matches("foo Foo bar", "foo")
  inspect(insensitive.length(), content="2")

  let sensitive_options = {
    ..MarkdownFindOptions::default(),
    case_sensitive: true,
  }
  let sensitive = markdown_find_matches(
    "foo Foo bar",
    "Foo",
    options=sensitive_options,
  )
  inspect(sensitive.length(), content="1")
  inspect(sensitive[0].start, content="4")
  inspect(sensitive[0].end, content="7")
}

///|
test "markdown regex find uses pattern semantics and stable ranges" {
  let options = { ..MarkdownFindOptions::default(), regex: true, }
  let matches = markdown_find_matches(
    "a🤣foo-42 foo-7",
    "foo-[[:digit:]]+",
    options~,
  )
  inspect(matches.length(), content="2")
  inspect(matches[0].start, content="2")
  inspect(matches[0].end, content="8")
  inspect(matches[1].start, content="9")
  inspect(matches[1].end, content="14")

  let insensitive = markdown_find_matches("Cat cat", "cat", options~)
  inspect(insensitive.length(), content="2")

  let whole_word = { ..options, case_sensitive: true, whole_word: true, }
  let whole_matches = markdown_find_matches(
    "Cat catalog cat",
    "cat",
    options=whole_word,
  )
  inspect(whole_matches.length(), content="1")
  inspect(whole_matches[0].start, content="12")
  inspect(whole_matches[0].end, content="15")

  // Zero-width matches have no useful selection in the editor flow.
  let zero_width = markdown_find_matches("foo", "^", options~)
  inspect(zero_width.length(), content="0")
}

///|
test "markdown invalid regex reports no matches but compiles nothing" {
  let options = { ..MarkdownFindOptions::default(), regex: true, }
  let matches = markdown_find_matches("task-12", "[", options~)
  inspect(matches.length(), content="0")
  inspect(markdown_find_compile_regex("[", false) is None, content="true")
  inspect(
    markdown_find_compile_regex("[0-9]+", false) is Some(_),
    content="true",
  )
}

///|
test "markdown find query from selection only accepts single-line non-empty" {
  let source = "alpha beta gamma"
  guard markdown_find_query_from_selection(source, {
      caret: 10,
      selection: Some(@core.TextRange::new(start=6, end=10)),
    })
    is Some(selected) else {
    fail("expected selection seed")
  }
  inspect(selected, content="beta")
  assert_true(
    markdown_find_query_from_selection(source, { caret: 3, selection: None, })
    is None,
  )
  let multiline : @richtext.MarkdownEditorSelection = {
    caret: 3,
    selection: Some(@core.TextRange::new(start=0, end=3)),
  }
  assert_true(markdown_find_query_from_selection("a\nb", multiline) is None)
}

///|
test "markdown find seed from caret word handles unicode neighbors" {
  // Caret inside the word.
  let seed = markdown_find_seed_from_caret_word("🤣cat catalog", {
    caret: 2,
    selection: None,
  })
  guard seed is Some(seed) else { fail("expected caret word seed") }
  inspect(seed.query, content="cat")
  inspect(seed.range.start, content="1")
  inspect(seed.range.end, content="4")

  // Caret directly after a word char uses the previous word.
  let after = markdown_find_seed_from_caret_word("🤣cat catalog", {
    caret: 4,
    selection: None,
  })
  guard after is Some(after) else { fail("expected previous word seed") }
  inspect(after.query, content="cat")

  // Caret on whitespace yields no seed.
  assert_true(
    markdown_find_seed_from_caret_word("cat  dog", {
      caret: 4,
      selection: None,
    })
    is None,
  )
}

///|
test "markdown find next and previous wrap around" {
  let source = "cat dog cat"
  let matches = markdown_find_matches(source, "cat")
  inspect(matches.length(), content="2")

  inspect(
    markdown_find_next_index(matches, { caret: 0, selection: None, }),
    content="0",
  )
  inspect(
    markdown_find_next_index(matches, { caret: 1, selection: None, }),
    content="1",
  )
  inspect(
    markdown_find_next_index(matches, { caret: 11, selection: None, }),
    content="0",
  )
  inspect(
    markdown_find_previous_index(matches, { caret: 11, selection: None, }),
    content="1",
  )
  inspect(
    markdown_find_previous_index(matches, { caret: 3, selection: None, }),
    content="0",
  )
  // Before the first match end the previous match wraps to the last one.
  inspect(
    markdown_find_previous_index(matches, { caret: 1, selection: None, }),
    content="1",
  )
}

///|
test "markdown find active and live update indices track selection" {
  let matches = markdown_find_matches("cat dog cat", "cat")
  let selection : @richtext.MarkdownEditorSelection = {
    caret: 11,
    selection: Some(@core.TextRange::new(start=8, end=11)),
  }
  inspect(markdown_find_active_index(matches, selection), content="1")
  inspect(markdown_find_live_update_index(matches, selection), content="1")
  inspect(
    markdown_find_active_index(matches, { caret: 4, selection: None, }),
    content="-1",
  )
  inspect(
    markdown_find_live_update_index(matches, { caret: 4, selection: None, }),
    content="1",
  )
}

///|
test "markdown replace source range preserves unicode around match" {
  let source = "🤣cat dog"
  let replaced = markdown_replace_source_range(
    source,
    @core.TextRange::new(start=1, end=4),
    "fox",
  )
  inspect(replaced, content="🤣fox dog")
}

///|
test "markdown replace all matches preserves unicode scalar ranges" {
  let source = "🤣cat cat"
  let matches = markdown_find_matches(source, "cat")
  inspect(matches.length(), content="2")
  inspect(
    markdown_replace_all_matches(source, matches, "fox"),
    content="🤣fox fox",
  )
}

///|
test "markdown next match after replacement prefers following matches" {
  let matches = markdown_find_matches("cat dog cat", "cat")
  let next = markdown_next_match_after_replacement(matches, 0, 3)
  guard next is Some(next) else { fail("expected a match after replacement") }
  inspect(next.start, content="8")
  inspect(next.end, content="11")

  let wrapped = markdown_next_match_after_replacement(matches, 8, 11)
  guard wrapped is Some(wrapped) else { fail("expected wrap to earlier match") }
  inspect(wrapped.start, content="0")
  inspect(wrapped.end, content="3")
}

///|
test "markdown find status label reports ready invalid no match and count" {
  let source = "cat dog cat"
  let matches = markdown_find_matches(source, "cat")
  inspect(
    markdown_find_status_label("cat", [], { caret: 0, selection: None, }),
    content="No match",
  )
  inspect(
    markdown_find_status_label("", [], { caret: 0, selection: None, }),
    content="Ready",
  )
  inspect(
    markdown_find_status_label("cat", matches, {
      caret: 11,
      selection: Some(@core.TextRange::new(start=8, end=11)),
    }),
    content="2/2",
  )
  inspect(
    markdown_find_status_label("cat", matches, { caret: 4, selection: None, }),
    content="0/2",
  )
  let regex_options = { ..MarkdownFindOptions::default(), regex: true, }
  inspect(
    markdown_find_status_label(
      "[",
      [],
      { caret: 0, selection: None, },
      options=regex_options,
    ),
    content="Invalid regex",
  )
}
