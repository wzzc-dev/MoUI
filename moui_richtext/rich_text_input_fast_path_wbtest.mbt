///|
/// Verify a transform's recorded edit range satisfies the fast-path
/// contract:
///
/// 1. the range is well-formed, so the guard in
///    `from_replacement_range` holds and `from_input_transform` builds
///    the transaction directly instead of paying the O(doc)
///    common-prefix/suffix diff in `from_sources`;
/// 2. slicing the previous source at the recorded range and inserting
///    the transaction's replacement reproduces the transform text
///    exactly, i.e. the record describes the true edit;
/// 3. caret/selection/reason agree with the `from_sources` reference,
///    and so do deleted/replacement whenever the diff infers the same
///    range (a record may span more than the minimal edit: backspacing
///    "- hello" at caret 2 records the whole line {0,7}, which still
///    rebuilds "hello" exactly).
fn check_transform(
  previous : String,
  transform : RichTextInputTransform,
) -> MarkdownEditTransaction raise Error {
  let previous_length = markdown_editor_text_length(previous)
  guard transform.edit_range is Some(range) else {
    fail("expected edit_range for \"\{previous}\" -> \"\{transform.text}\"")
  }
  let source_length = markdown_editor_text_length(transform.text)
  let replacement_length = source_length - range.start - (previous_length - range.end)
  // The guard conditions of from_replacement_range: when these hold the
  // fast path engages instead of the O(doc) fallback.
  assert_true(range.start <= range.end)
  assert_true(range.end <= previous_length)
  assert_true(replacement_length >= 0)
  let fast = MarkdownEditTransaction::from_input_transform(previous, transform)
  let fast_range = fast.edit_range
  assert_true(fast_range.start == range.start && fast_range.end == range.end)
  assert_true(
    fast.deleted == markdown_editor_substring(previous, range.start, range.end),
  )
  assert_true(
    transform.text == markdown_editor_substring(previous, 0, range.start) +
    fast.replacement +
    markdown_editor_substring(previous, range.end, previous_length),
  )
  let slow = MarkdownEditTransaction::from_sources(
    previous,
    transform.text,
    caret=transform.caret,
    selection=transform.selection,
    reason=TextInput,
  )
  assert_true(fast.caret == slow.caret)
  assert_true(fast.selection == slow.selection)
  assert_true(fast.reason == slow.reason)
  if slow.edit_range.start == range.start && slow.edit_range.end == range.end {
    assert_true(fast.deleted == slow.deleted)
    assert_true(fast.replacement == slow.replacement)
  }
  fast
}

///|
/// Drive one keystroke through the real transform chain and check it.
fn check_fast_path(
  previous : String,
  caret : Int,
  selection : @core.TextRange?,
  input : String,
  context? : MarkdownEditorInputContext? = None,
) -> MarkdownEditTransaction raise Error {
  guard
    markdown_editor_transform_input(previous, caret, selection, input, context~)
    is Some(transform)
  else {
    fail("expected a transform for input \"\{input}\" in \"\{previous}\"")
  }
  check_transform(previous, transform)
}

///|
fn code_block_context(source : String) -> MarkdownEditorInputContext {
  let session = MarkdownDocumentSession::new(source)
  { blocks: session.editor_blocks, store: session.text_store }
}

///|
test "fast path: plain typing" {
  // Plain typing is not answered by the transform chain: the dispatcher
  // returns None and the session builds the transaction from the control's
  // exact committed range via from_edit. Feed that same shape through
  // from_input_transform to exercise the recorded-range fast path.
  let transform : RichTextInputTransform = {
    text: "aXbc",
    caret: 2,
    selection: None,
    edit_range: Some({ start: 1, end: 1 }),
  }
  let tx = check_transform("abc", transform)
  inspect(tx.source, content="aXbc")
  inspect(tx.caret, content="2")
}

///|
test "fast path: delimiter pairing at a unicode scalar caret" {
  let tx = check_fast_path("前🤣后", 2, None, "(")
  inspect(tx.source, content="前🤣()后")
  inspect(tx.caret, content="3")
}

///|
test "fast path: selection wrap" {
  let selection = @core.TextRange::new(start=0, end=4)
  let tx = check_fast_path("text", 4, Some(selection), "(")
  inspect(tx.source, content="(text)")
  guard tx.selection is Some(range) else {
    fail("expected wrapped selection")
  }
  inspect(range.start, content="1")
  inspect(range.end, content="5")
}

///|
test "fast path: unicode backspace" {
  // Backspacing the "- " marker in front of a unicode run: the whole-line
  // record {0,5} deletes "- 前🤣后" and replaces it with "前🤣后".
  let tx = check_fast_path("- 前🤣后", 2, None, "\b")
  inspect(tx.source, content="前🤣后")
  inspect(tx.caret, content="0")
}

///|
test "fast path: backspacing a bullet marker" {
  let tx = check_fast_path("- hello", 2, None, "\b")
  inspect(tx.source, content="hello")
  // The transform records the whole line {0,7} it rewrites, not just the
  // "- " marker; deleted/replacement still rebuild the source exactly.
  inspect(tx.deleted, content="- hello")
  inspect(tx.replacement, content="hello")
}

///|
test "fast path: backspacing a heading marker" {
  ignore(check_fast_path("# title", 2, None, "\b"))
  let _ = check_fast_path("- [ ] task", 6, None, "\b")
  let _ = check_fast_path("1. item", 3, None, "\b")
  let _ = check_fast_path("> quote", 2, None, "\b")
}

///|
test "fast path: bullet continuation" {
  let tx = check_fast_path("- item", 6, None, "\n")
  inspect(tx.source, content="- item\n- ")
  inspect(tx.caret, content="9")
}

///|
test "fast path: ordered list continuation" {
  let tx = check_fast_path("1. item", 7, None, "\n")
  inspect(tx.source, content="1. item\n2. ")
  inspect(tx.caret, content="11")
}

///|
test "fast path: blockquote continuation" {
  let tx = check_fast_path("> quote", 7, None, "\n")
  inspect(tx.source, content="> quote\n> ")
  inspect(tx.caret, content="10")
}

///|
test "fast path: exiting an empty heading" {
  let tx = check_fast_path("# ", 2, None, "\n")
  inspect(tx.source, content="")
  inspect(tx.deleted, content="# ")
}

///|
test "fast path: thematic rule completion" {
  ignore(check_fast_path("---", 3, None, "\n"))
}

///|
test "fast path: code fence completion" {
  let tx = check_fast_path("```", 3, None, "\n")
  inspect(tx.source, content="```\n\n```")
  inspect(tx.caret, content="4")
}

///|
test "fast path: enter inside a code block" {
  let source = "```\ncode\n```"
  let tx = check_fast_path(
    source,
    8,
    None,
    "\n",
    context=Some(code_block_context(source)),
  )
  inspect(tx.source, content="```\ncode\n\n```")
  inspect(tx.caret, content="9")
}

///|
test "fast path: exiting an empty code block" {
  let source = "```\n\n```"
  ignore(check_fast_path(source, 4, None, "\n", context=Some(code_block_context(source))))
}
