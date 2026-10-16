// 调色板是「语义角色 → 终端颜色」的唯一通道,这组测试钉三层:
// 量化函数本身的边界;主题接入后的角色映射;换调色板必然全帧重建
// (增量通路比较的是「上次发出的格子」,换色后每一格都算变了)。

///|
fn color(r : Double, g : Double, b : Double) -> @core.Color {
  { r, g, b, a: 1.0, }
}

///|
test "quantize maps primaries, white, black and greys onto the 256 palette" {
  // 6x6x6 立方角点:red 的经典 256 索引是 196。
  assert_eq(
    @moui_tui_renderer.quantize_color(color(1.0, 0.0, 0.0)),
    @tui.Indexed(196),
  )
  // 灰阶走 232..255:纯黑、纯白、中灰各钉一档。
  assert_eq(
    @moui_tui_renderer.quantize_color(color(0.0, 0.0, 0.0)),
    @tui.Indexed(232),
  )
  assert_eq(
    @moui_tui_renderer.quantize_color(color(1.0, 1.0, 1.0)),
    @tui.Indexed(255),
  )
  assert_eq(
    @moui_tui_renderer.quantize_color(color(0.5, 0.5, 0.5)),
    @tui.Indexed(244),
  )
  // 通道接近但非灰(0.9,0.86,0.86):差 0.04 < 0.06 走灰阶 —— 视觉上是米白,
  // 量化进灰阶比进立方更接近原色。
  let near_grey = @moui_tui_renderer.quantize_color(color(0.9, 0.86, 0.86))
  match near_grey {
    @tui.Indexed(i) => assert_true(i >= 232 && i <= 255)
    _ => fail("expected a grey-ramp index")
  }
}

///|
test "from_theme routes the palette families to the right cell roles" {
  let theme = @core.Theme::neutral().with_palette(@core.ColorPalette::dark())
  let palette = @moui_tui_renderer.TuiPalette::from_theme(theme)
  // 每个槽位的期望值用同一条量化函数算:钉的是「映射」,不是具体 RGB 表。
  let p = theme.palette
  assert_eq(palette.primary, @moui_tui_renderer.quantize_color(p.primary))
  assert_eq(palette.alert, @moui_tui_renderer.quantize_color(p.error))
  assert_eq(palette.content, @moui_tui_renderer.quantize_color(p.on_surface))
  assert_eq(palette.focus, @moui_tui_renderer.quantize_color(p.primary))
  assert_eq(
    palette.neutral,
    @moui_tui_renderer.quantize_color(p.on_surface_variant),
  )
}

///|
test "the default palette is the S2–S7 constants" {
  let d = @moui_tui_renderer.TuiPalette::default()
  assert_eq(d.primary, @tui.Indexed(4))
  assert_eq(d.interactive, @tui.Indexed(5))
  assert_eq(d.content, @tui.Indexed(2))
  assert_eq(d.focus, @tui.Indexed(3))
  assert_eq(d.neutral, @tui.Indexed(6))
  assert_eq(d.heading, @tui.TermColor::Default)
}

///|
/// 换调色板必须让下一帧整屏重建:内容一个字没变,颜色全变了 —— 如果
/// 增量通路不重建,终端会停在旧色。
test "set_palette forces a full rebuild on the next frame" {
  let button = node(
    1UL,
    role=@core.Button,
    frame=rect(8.0, 8.0, 48.0, 16.0),
    label="Go",
  )
  let (sink, out) = capture()
  let renderer = @moui_tui_renderer.TuiRenderer::new(
    metrics=metrics(160.0, 96.0),
    sink~,
  )
  ignore(renderer.render_frame(semantics_frame(nodes=[button], root=button)))
  assert_true(out.text().contains("38;5;4"))
  out.chunks.clear()
  let themed : @moui_tui_renderer.TuiPalette = {
    primary: @tui.Indexed(196),
    interactive: @tui.Indexed(5),
    content: @tui.Indexed(2),
    status: @tui.Indexed(2),
    alert: @tui.Indexed(1),
    heading: @tui.TermColor::Default,
    neutral: @tui.Indexed(7),
    focus: @tui.Indexed(6),
  }
  renderer.set_palette(themed)
  ignore(renderer.render_frame(semantics_frame(nodes=[button], root=button)))
  let bytes = out.text()
  // 全帧重建的标记:清屏序列回来,新的前景色进了字节流。
  assert_true(bytes.contains("\u{1b}[2J"))
  assert_true(bytes.contains("38;5;196"))
}
