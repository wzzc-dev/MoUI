///|
/// Algorithm-level wrap alignment corpus between the two paragraph
/// implementations that must agree: the core fallback algorithm fed
/// real Skia measurements (the shape web/wgpu run) and the Skia native
/// paragraph. Widths are identical on both sides, so any disagreement
/// here is a breaking-rule difference, not a measurement difference.
fn skia_wrap_corpus_ends(
  system : @core.TextSystem,
  text : String,
  font : @core.FontSpec,
  width : Double,
) -> Array[Int] {
  let paragraph = system.layout_paragraph(
    @core.TextLayoutInput::new(text~, font~, max_width=width),
  )
  paragraph.lines.map(line => line.text_range.end)
}

///|
fn skia_wrap_corpus_describe(ends : Array[Int]) -> String {
  let parts : Array[String] = []
  for end in ends {
    parts.push(end.to_string())
  }
  parts.join(",")
}

///|
fn skia_wrap_corpus_probe_native(system : @core.TextSystem) -> Bool {
  let probe = system.layout_paragraph(
    @core.TextLayoutInput::new(
      text="probe",
      font=@core.FontSpec::new(size=16.0, weight=400),
      max_width=40.0,
    ),
  )
  probe.metadata.native_paragraph_ready
}

///|
test "core fallback algorithm and skia native paragraph break alike" {
  guard skia_test_native_text_available() else { return () }
  let skia = skia_text_system(resolution=SkiaFontResolution::SystemFontMgr)
  guard skia_wrap_corpus_probe_native(skia) else { return () }
  let fallback_algorithm = @core.TextSystem::new(
    id="fallback-algorithm-skia-measure",
    measure=input => skia.measure_text(input),
  )
  let font = @core.FontSpec::new(size=16.0, weight=400)
  let width = 120.0
  // Cases the two algorithms must agree on exactly: space-delimited
  // latin word wrapping with hanging trailing spaces, hard newlines,
  // CJK cluster breaks, and mixed runs.
  let aligned_cases : Array[(String, String)] = [
    ("latin", "one two three four five six seven eight nine ten"),
    ("newline", "first\nsecond line of text here now"),
    ("cjk", "你好世界测试文本换行对齐语料覆盖情况"),
    ("mixed", "MoUI 文本换行 corpus alignment 对齐 corpus"),
  ]
  for case in aligned_cases {
    let label = case.0
    let text = case.1
    let native = skia_wrap_corpus_ends(skia, text, font, width)
    let fallback = skia_wrap_corpus_ends(fallback_algorithm, text, font, width)
    if native != fallback {
      let native_repr = skia_wrap_corpus_describe(native)
      let fallback_repr = skia_wrap_corpus_describe(fallback)
      fail(
        "corpus case '\{label}' diverged: native=[\{native_repr}] fallback=[\{fallback_repr}]",
      )
    }
  }
}

///|
/// Mid-word hard breaks legitimately differ by up to one cluster: the
/// native paragraph breaks at the last glyph whose advance fits, while
/// the fallback algorithm compares caret spans. Pinned as a bounded
/// divergence so a *growing* gap still fails.
test "mid-word hard breaks stay within one cluster across implementations" {
  guard skia_test_native_text_available() else { return () }
  let skia = skia_text_system(resolution=SkiaFontResolution::SystemFontMgr)
  guard skia_wrap_corpus_probe_native(skia) else { return () }
  let fallback_algorithm = @core.TextSystem::new(
    id="fallback-algorithm-skia-measure",
    measure=input => skia.measure_text(input),
  )
  let font = @core.FontSpec::new(size=16.0, weight=400)
  let text = "supercalifragilisticexpialidocious end"
  let native = skia_wrap_corpus_ends(skia, text, font, 120.0)
  let fallback = skia_wrap_corpus_ends(fallback_algorithm, text, font, 120.0)
  assert_eq(native.length(), fallback.length())
  for index in 0..<native.length() {
    let delta = native[index] - fallback[index]
    assert_true(delta.abs() <= 1)
  }
}

///|
test "skia native paragraph covers the corpus contiguously" {
  guard skia_test_native_text_available() else { return () }
  let skia = skia_text_system(resolution=SkiaFontResolution::SystemFontMgr)
  let font = @core.FontSpec::new(size=16.0, weight=400)
  for
    text in [
      "plain single line", "one two three four five six seven eight nine ten", "你好世界测试文本换行对齐语料覆盖情况",
      "first\nsecond line of text here now", "trailing newline\n",
    ] {
    let paragraph = skia.layout_paragraph(
      @core.TextLayoutInput::new(text~, font~, max_width=120.0),
    )
    guard paragraph.metadata.native_paragraph_ready else { continue }
    let last = paragraph.lines.length() - 1
    assert_true(last >= 0)
    let chars = text.to_array()
    // Hard line breaks and trailing spaces at a break boundary may be
    // dropped by the native paragraph, so the only illegal gap is one
    // that swallows a non-break character.
    let mut covered = 0
    for line_index in 0..<=last {
      let line = paragraph.lines[line_index]
      if line.text_range.start < covered {
        let ranges : Array[String] = []
        for l in paragraph.lines {
          let start_text = l.text_range.start.to_string()
          let end_text = l.text_range.end.to_string()
          let y_text = l.origin.y.to_string()
          ranges.push("[" + start_text + "," + end_text + ")@" + y_text)
        }
        let joined = ranges.join(" ")
        fail(
          "case length \{text.to_array().length()}: line \{line_index} starts inside previous: \{joined}",
        )
      }
      assert_true(line.text_range.end >= line.text_range.start)
      covered = line.text_range.end
    }
    assert_true(
      covered == chars.length() ||
      (covered == chars.length() - 1 && chars[chars.length() - 1] == '\n'),
    )
  }
}
