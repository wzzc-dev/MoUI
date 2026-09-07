///|
test "store edits match whole-string replacement" {
  let store = MarkdownDocumentTextStore::new("hello 世界\nnext line")
  // Insert at a multi-byte boundary: char offsets, not UTF-16 units.
  store.edit({ start: 6, end: 6 }, "漂亮的")
  inspect(store.source(), content="hello 漂亮的世界\nnext line")
  inspect(store.length().to_string(), content="21")
  // Replace across the newline and a multi-byte char.
  store.edit({ start: 4, end: 10 }, "!")
  inspect(store.source(), content="hell!" + "界\nnext line")
  inspect(store.length().to_string(), content="16")
  // Delete to the end and append back.
  store.edit({ start: 5, end: 16 }, "")
  inspect(store.source(), content="hell!")
  store.edit({ start: 5, end: 5 }, "!")
  inspect(store.source(), content="hell!!")
  inspect(store.length().to_string(), content="6")
}

///|
test "store splices multiple segments and shifts tail offsets" {
  let store = MarkdownDocumentTextStore::from_texts([
    "aa\nbb", "\ncc\ndd", "\ndd\n",
  ])
  inspect(store.source(), content="aa\nbb\ncc\ndd\ndd\n")
  inspect(store.length().to_string(), content="15")
  // An edit crossing the first boundary splices segments 0 and 1 into one;
  // the untouched tail segment shifts by the char delta (-3).
  store.edit({ start: 3, end: 7 }, "Z")
  inspect(store.source(), content="aa\nZc\ndd\ndd\n")
  inspect(store.segments.val.length().to_string(), content="2")
  inspect(store.segments.val[1].start.to_string(), content="8")
  inspect(store.segments.val[1].end.to_string(), content="12")
  // Repeated appends keep offsets and materialization in sync.
  store.edit({ start: store.length(), end: store.length() }, "end")
  inspect(store.source(), content="aa\nZc\ndd\ndd\nend")
  inspect(store.length().to_string(), content="15")
  // Whole delete leaves one readable empty document.
  store.edit({ start: 0, end: 15 }, "")
  inspect(store.source(), content="")
  inspect(store.length().to_string(), content="0")
}

///|
test "store revision gates materialization and aliases share the core" {
  let store = MarkdownDocumentTextStore::new("doc")
  let revision_0 = store.revision()
  inspect(store.source(), content="doc")
  inspect(store.source(), content="doc")
  store.edit({ start: 3, end: 3 }, "!")
  // The cached materialization must not return the pre-edit text.
  inspect(store.source(), content="doc!")
  guard! store.revision() > revision_0
  // Copies of the session struct share the same underlying store.
  let other_store = store
  other_store.edit({ start: 0, end: 0 }, "# ")
  inspect(store.source(), content="# doc!")
  guard! store == other_store
  // Same text in a fresh store is not equal: the revision distinguishes a
  // store that has seen edits from one that has not.
  let fresh = MarkdownDocumentTextStore::new("# doc!")
  guard! fresh.source() == store.source()
  guard! !(fresh == store)
}

///|
test "store text_of reads across segment boundaries" {
  let store = MarkdownDocumentTextStore::from_texts(["012345", "6789"])
  store.edit({ start: 2, end: 2 }, "XY")
  // segments: "01XY2345" + "6789"; whole doc "01XY23456789"
  inspect(store.source(), content="01XY23456789")
  store.edit({ start: 8, end: 8 }, "Z")
  // "01XY2345Z6789"
  inspect(store.text_of(0, 13), content=store.source())
  inspect(store.text_of(3, 5), content="Y2")
  inspect(store.text_of(4, 9), content="2345Z")
  inspect(store.text_of(7, 11), content="5Z67")
  inspect(store.text_of(12, 13), content="9")
  inspect(store.text_of(13, 14), content="")
  inspect(store.text_of(5, 5), content="")
}
