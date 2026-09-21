///|
/// The line lookup behind the caret's out-of-band positioning. It rides the
/// cached line scan, so it must agree with a fresh scan of the same source.

///|
test "line lookup finds the line containing an offset" {
  let source = "alpha\nbeta\ngamma"
  // Prime the line scan cache the way the open path does.
  let _ = MarkdownDocumentSession::new(source)
  debug_inspect(
    markdown_editor_line_at_offset(source, 0),
    content="Some((0, 0))",
  )
  debug_inspect(
    markdown_editor_line_at_offset(source, 4),
    content="Some((0, 0))",
  )
  // The newline itself belongs to the line it ends.
  debug_inspect(
    markdown_editor_line_at_offset(source, 5),
    content="Some((0, 0))",
  )
  debug_inspect(
    markdown_editor_line_at_offset(source, 6),
    content="Some((1, 6))",
  )
  debug_inspect(
    markdown_editor_line_at_offset(source, 11),
    content="Some((2, 11))",
  )
  debug_inspect(
    markdown_editor_line_at_offset(source, 16),
    content="Some((2, 11))",
  )
}

///|
test "line lookup agrees with a manual scan for every offset" {
  let source = "one\ntwo\n\nfour\nfive"
  let _ = MarkdownDocumentSession::new(source)
  let chars = source.to_array()
  for offset in 0..<chars.length() {
    // Manual scan: the last newline strictly before this offset starts the line.
    let manual_start = {
      let mut start = 0
      for index in 0..<offset {
        if chars[index] == '\n' {
          start = index + 1
        }
      }
      start
    }
    match markdown_editor_line_at_offset(source, offset) {
      Some((_, start)) => assert_true(start == manual_start)
      None => fail("expected a cached line scan")
    }
  }
}

///|
test "line lookup reports nothing when the scan is not cached" {
  // A source the cache has never seen: callers must be able to tell, so they
  // can fall back instead of silently reading a stale scan.
  let unseen = "a source the line cache has never scanned\nsecond line"
  debug_inspect(markdown_editor_line_at_offset(unseen, 3), content="None")
}
