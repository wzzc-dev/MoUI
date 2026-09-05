///|
/// Probe: CJK + Latin mixed paragraph at narrow width must soft-wrap with
/// the same invariants as the ASCII fixture (line starts at the inset, hit
/// lands at the line-start source offset, visual text reconstructs).
test "wrap probe: CJK Latin mixed paragraph line invariants" {
  let base = @core.FontSpec::new()
  let text_system = @core.TextSystem::fallback()
  let source = "MoUI 是一个多平台 MoonBit GUI 框架，用于构建声明式 UI 应用，共享平台无关的应用逻辑。原生宿主核心拥有窗口、事件、服务和生命周期，再通过平台渲染器提供方包（renderer provider packages）接入具体的渲染器。"
  let session = MarkdownDocumentSession::new(source)
  hot_path_metrics_reset()
  let plain = markdown_editor_block_to_rich_text(
    session.source(),
    markdown_editor_block_materialized(
      session.source(),
      source_length=session.source_length,
      source_digest=session.source_digest,
      session.editor_blocks[0],
    ),
    base,
    base_dir=None,
  )
  let width = 320.0
  let wrapped = rich_text_block_soft_wrap(plain, width, base, text_system)
  let visual_line_count = rich_text_block_visual_line_count(wrapped)
  assert_true(visual_line_count > 3)
  let visual = rich_text_document_view_block_visual_text(wrapped)
  let starts = source_line_starts(visual)
  assert_true(starts.length() == visual_line_count)
  let frame = @core.Rect::new(x=0.0, y=0.0, width~, height=10000.0)
  let line_limit = @core.min_int(visual_line_count, starts.length())
  for line in 0..<line_limit {
    let caret = rich_text_block_caret_rect(
      wrapped,
      starts[line],
      frame,
      base,
      text_system,
    )
    let x_ok = caret.origin.x >= 0.0 && caret.origin.x <= 2.0
    assert_true(x_ok)
    let hit = rich_text_block_source_offset_at_point(
      wrapped,
      @core.Point::new(x=caret.origin.x + 0.1, y=caret.origin.y + 1.0),
      frame,
      base,
      text_system,
    )
    let expected_source = starts[line] - line
    assert_true(hit == expected_source)
  }
}

///|
/// Probe: the source paragraph with an inline code run and a link keeps
/// runs intact and line-consistent through soft wrap.
test "wrap probe: CJK paragraph with code and link stays line-aligned" {
  let base = @core.FontSpec::new()
  let text_system = @core.TextSystem::fallback()
  let source = "当前主线为原生 Skia 光栅化 + Web `wasm-gc + window/web + 浏览器 WebGPU host imports` 路径。原生 WGPU 仍作为实验性诊断路径保留，等待 MoonBit WGPU 生态进一步成熟。欢迎贡献 — 请参阅 [CONTRIBUTING.md](CONTRIBUTING.md)。"
  let session = MarkdownDocumentSession::new(source)
  let plain = markdown_editor_block_to_rich_text(
    session.source(),
    markdown_editor_block_materialized(
      session.source(),
      source_length=session.source_length,
      source_digest=session.source_digest,
      session.editor_blocks[0],
    ),
    base,
    base_dir=None,
  )
  let width = 320.0
  let wrapped = rich_text_block_soft_wrap(plain, width, base, text_system)
  let visual = rich_text_document_view_block_visual_text(wrapped)
  let starts = source_line_starts(visual)
  let visual_line_count = rich_text_block_visual_line_count(wrapped)
  assert_true(starts.length() == visual_line_count)
  let frame = @core.Rect::new(x=0.0, y=0.0, width~, height=10000.0)
  for line in 0..<starts.length() {
    let caret = rich_text_block_caret_rect(
      wrapped,
      starts[line],
      frame,
      base,
      text_system,
    )
    assert_true(caret.origin.x <= 2.0)
  }
}
